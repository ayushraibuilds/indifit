// Live WS7 AI evaluation. Calls Gemini through Firebase AI Logic with the
// app's own prompts, resolves results against the real catalogue, and
// writes tool/ai_eval/results/<date>-<model>.md. Fails when the launch bar
// isn't met. See tool/ai_eval/README.md.
//
//   INDIFIT_APPCHECK_DEBUG_TOKEN=<iOS debug token> \
//     flutter test tool/ai_eval/run_eval_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/gemini_requests.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';
import 'package:indifit/firebase_options.dart';

import 'ai_eval_scoring.dart';
import 'firebase_rest_gateway.dart';

const _dir = 'tool/ai_eval';

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding answers every HTTP request with a fake 400; this
  // harness needs the real network.
  HttpOverrides.global = null;

  final env = Platform.environment;
  final token = env['INDIFIT_APPCHECK_DEBUG_TOKEN']?.trim() ?? '';
  final model = env['INDIFIT_AI_MODEL']?.trim().isNotEmpty == true
      ? env['INDIFIT_AI_MODEL']!.trim()
      : GeminiRequests.defaultModel;
  final limit = int.tryParse(env['INDIFIT_AI_EVAL_LIMIT'] ?? '');
  final tags = env['INDIFIT_AI_EVAL_TAGS']?.split(',').toSet();

  test(
    'AI eval against the launch bar',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final catalog = NutritionFoodCatalogRepository(
        db: db,
        registry: NutrientRegistry.fromAssetFileSync(
          'assets/data/nutrient_registry.json',
        ),
      );
      final gateway = FirebaseRestGateway(
        options: DefaultFirebaseOptions.ios,
        debugToken: token,
        model: model,
      );
      final service = NaturalLanguageMealService(
        gateway: gateway,
        catalog: catalog,
        policy: () => const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          connectedAiEnabled: true,
        ),
      );

      // --- Meal text -----------------------------------------------------
      var meals = MealCase.load('$_dir/meals.jsonl');
      if (tags != null) {
        meals = meals.where((m) => m.tags.any(tags.contains)).toList();
      }
      if (limit != null) meals = meals.take(limit).toList();

      final scores = <MealScore>[];
      final failures = <String, String>{};
      final raw = <Map<String, Object?>>[];
      for (final meal in meals) {
        try {
          final result = await service.decomposeMeal(text: meal.text);
          scores.add(
            await scoreMeal(meal, result.items, (name, amount) {
              return _catalogKcal(catalog, name, amount);
            }),
          );
          raw.add({'id': meal.id, 'response': gateway.responses.last});
        } on Object catch (error) {
          failures[meal.id] = '$error';
          scores.add(
            await scoreMeal(
              meal,
              const [],
              (name, amount) => _catalogKcal(catalog, name, amount),
            ),
          );
        }
      }
      final summary = EvalSummary(scores);

      // --- Nutrition labels and meal photos (optional data) --------------
      final labelReport = await _runLabels(gateway);
      final photoReport = await _runPhotos(service);

      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final base = '$_dir/results/$stamp-$model';
      File('$base.md').writeAsStringSync(
        _report(
          model: model,
          summary: summary,
          scores: scores,
          failures: failures,
          labelReport: labelReport,
          photoReport: photoReport,
          subset: tags != null || limit != null,
        ),
      );
      File(
        '$base.raw.jsonl',
      ).writeAsStringSync('${raw.map(jsonEncode).join('\n')}\n');
      // ignore: avoid_print
      print('Wrote $base.md');

      final bar = [
        ...summary.barFailures,
        if (labelReport.accuracy case final accuracy?
            when accuracy < LaunchBar.labelFieldAccuracy)
          'label fields ${pct(accuracy)} < '
              '${pct(LaunchBar.labelFieldAccuracy)}',
      ];
      expect(bar, isEmpty, reason: 'Launch bar not met; see $base.md');
    },
    skip: token.isEmpty
        ? 'Set INDIFIT_APPCHECK_DEBUG_TOKEN to run the live AI eval.'
        : false,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<double?> _catalogKcal(
  NutritionFoodCatalogRepository catalog,
  String name,
  double amount,
) async {
  final options = await catalog.search(query: name);
  for (final option in options) {
    if (option.displayName != name) continue;
    final energy = option.facts['energy'];
    if (energy == null || energy.point == null) continue;
    final base = option.baseQuantity;
    final quantity = Quantity.fromNum(
      amount: amount,
      unit: base.unit,
      context: base.context,
    );
    return energy.scaleBy(quantity).point?.value.asDouble;
  }
  return null;
}

typedef _SectionReport = ({double? accuracy, String markdown});

Future<_SectionReport> _runLabels(FirebaseRestGateway gateway) async {
  final file = File('$_dir/labels/cases.json');
  final cases = file.existsSync()
      ? [
          for (final c in jsonDecode(file.readAsStringSync()) as List)
            LabelCase.fromJson(c as Map<String, dynamic>),
        ]
      : <LabelCase>[];
  if (cases.isEmpty) {
    return (
      accuracy: null,
      markdown: 'Not evaluated: add label photos to `labels/` (see README).',
    );
  }
  var correct = 0;
  var total = 0;
  final rows = StringBuffer('| Label | Fields | Misses |\n|---|---|---|\n');
  for (final c in cases) {
    try {
      final response = await gateway.readNutritionLabel(
        File('$_dir/labels/${c.image}').readAsBytesSync(),
      );
      final score = scoreLabel(c, response);
      correct += score.correct;
      total += score.total;
      rows.writeln(
        '| ${c.image} | ${score.correct}/${score.total} | '
        '${score.misses.join('; ')} |',
      );
    } on Object catch (error) {
      total += c.fields.length + 1;
      rows.writeln('| ${c.image} | 0 | request failed: $error |');
    }
  }
  final accuracy = total == 0 ? 0.0 : correct / total;
  return (
    accuracy: accuracy,
    markdown:
        'Field accuracy **${pct(accuracy)}** (bar '
        '${pct(LaunchBar.labelFieldAccuracy)}) over ${cases.length} labels.'
        '\n\n$rows',
  );
}

Future<_SectionReport> _runPhotos(NaturalLanguageMealService service) async {
  final file = File('$_dir/photos/cases.json');
  final cases = file.existsSync()
      ? (jsonDecode(file.readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
      : const <Map<String, dynamic>>[];
  if (cases.isEmpty) {
    return (
      accuracy: null,
      markdown: 'Not evaluated: add meal photos to `photos/` (see README).',
    );
  }
  final errors = <double>[];
  final rows = StringBuffer(
    '| Photo | Expected kcal | Shown kcal |\n|---|---|---|\n',
  );
  for (final c in cases) {
    final expected = (c['kcal'] as num).toDouble();
    try {
      final result = await service.decomposePhotoMeal(
        imagePath: '$_dir/photos/${c['image']}',
        deviceUuid: 'ai-eval',
      );
      final shown = result.items.fold<int>(
        0,
        (sum, item) => sum + item.estimatedCalories,
      );
      errors.add((shown - expected).abs() / expected);
      rows.writeln('| ${c['image']} | ${expected.round()} | $shown |');
    } on Object catch (error) {
      errors.add(1);
      rows.writeln('| ${c['image']} | ${expected.round()} | failed: $error |');
    }
  }
  final mape = errors.reduce((a, b) => a + b) / errors.length;
  return (
    accuracy: null,
    markdown:
        'Calorie MAPE **${pct(mape)}** over ${cases.length} photos (Beta: '
        'no bar yet).\n\n$rows',
  );
}

String _report({
  required String model,
  required EvalSummary summary,
  required List<MealScore> scores,
  required Map<String, String> failures,
  required _SectionReport labelReport,
  required _SectionReport photoReport,
  required bool subset,
}) {
  String mark(bool ok) => ok ? '✅' : '❌';
  final out = StringBuffer()
    ..writeln('# AI eval: $model')
    ..writeln()
    ..writeln(
      '${DateTime.now().toIso8601String().substring(0, 16)} · prompts '
      '`${GeminiRequests.promptVersion}` · ${summary.meals} meals'
      '${subset ? ' (subset; not a release gate)' : ''}',
    )
    ..writeln()
    ..writeln('## Meal text')
    ..writeln()
    ..writeln('| Metric | Result | Bar |')
    ..writeln('|---|---|---|')
    ..writeln(
      '| Item recall | ${pct(summary.itemRecall)} | '
      '${mark(summary.itemRecall >= LaunchBar.itemRecall)} '
      '≥ ${pct(LaunchBar.itemRecall)} |',
    )
    ..writeln('| Item precision | ${pct(summary.itemPrecision)} | |')
    ..writeln(
      '| Catalogue match (auto or offered) | ${pct(summary.catalogMatch)} | '
      '${mark(summary.catalogMatch >= LaunchBar.catalogMatch)} '
      '≥ ${pct(LaunchBar.catalogMatch)} |',
    )
    ..writeln('| Auto-matched correctly | ${pct(summary.autoMatch)} | |')
    ..writeln(
      '| Wrong auto-match (silent error) | ${pct(summary.wrongAutoMatch)} | '
      '${mark(summary.wrongAutoMatch <= LaunchBar.maxWrongAutoMatch)} '
      '≤ ${pct(LaunchBar.maxWrongAutoMatch)} |',
    )
    ..writeln(
      '| Amount right (of auto-matched) | ${pct(summary.amountAccuracy)} | |',
    )
    ..writeln(
      '| Meal kcal error, mean / median | ${pct(summary.kcalMape)} / '
      '${pct(summary.kcalMedianApe)} | |',
    )
    ..writeln()
    ..writeln(
      summary.barFailures.isEmpty
          ? '**Launch bar met** for meal text.'
          : '**Launch bar not met:** ${summary.barFailures.join('; ')}.',
    )
    ..writeln()
    ..writeln('### Items that weren\'t auto-matched correctly')
    ..writeln()
    ..writeln('| Meal | Text | Expected | Outcome | AI said |')
    ..writeln('|---|---|---|---|---|');
  for (final score in scores) {
    for (final item in score.items) {
      if (item.outcome == ItemOutcome.correct && item.amountCorrect) continue;
      final p = item.predicted;
      final said = p == null
          ? '—'
          : '${p.foodName} → ${p.matchedCatalogOption?.displayName ?? (p.catalogChoices.isEmpty ? 'estimate' : 'choose: ${p.catalogChoices.map((c) => c.displayName).join(' / ')}')}'
                ' · ${_amount(p.quantityAmount)} ${p.quantityUnit}'
                '${p.portionNote == null ? '' : ' (amount reset)'}';
      final outcome = item.outcome == ItemOutcome.correct
          ? 'amount off'
          : item.outcome.name;
      out.writeln(
        '| ${score.meal.id} | ${score.meal.text} | ${item.expected.foods.first} '
        '× ${_amount(item.expected.amount)} | $outcome | $said |',
      );
    }
  }
  final extras = [
    for (final s in scores)
      for (final p in s.extraPredictions) '${s.meal.id}: ${p.foodName}',
  ];
  if (extras.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Extra items the AI added: ${extras.join(', ')}.');
  }
  if (failures.isNotEmpty) {
    out
      ..writeln()
      ..writeln('### Request failures')
      ..writeln();
    failures.forEach((id, error) => out.writeln('- $id: $error'));
  }
  out
    ..writeln()
    ..writeln('## Nutrition labels')
    ..writeln()
    ..writeln(labelReport.markdown)
    ..writeln()
    ..writeln('## Meal photos')
    ..writeln()
    ..writeln(photoReport.markdown);
  return out.toString();
}

String _amount(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
