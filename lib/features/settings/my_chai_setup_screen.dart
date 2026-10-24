import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../food_log/my_chai.dart';
import '../food_log/my_roti.dart';

/// "My chai" (UF-2): milk, how much of the cup is milk, sugar and cup size,
/// set once. The recipe is shown as it will be logged, and a cup's facts
/// come from the catalogue milk and sugar.
class MyChaiSetupScreen extends ConsumerStatefulWidget {
  const MyChaiSetupScreen({super.key});

  @override
  ConsumerState<MyChaiSetupScreen> createState() => _MyChaiSetupScreenState();
}

class _MyChaiSetupScreenState extends ConsumerState<MyChaiSetupScreen> {
  late MyChaiSettings _chai;
  bool _saving = false;

  /// A cup as last saved: "78 kcal · 2.4 g protein · 13 g carbs".
  String? _cupFacts;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(myChaiSettingsProvider);
    _chai = saved ?? MyChaiSettings.defaults;
    if (saved != null) unawaited(_loadFacts(saved));
  }

  Future<void> _loadFacts(MyChaiSettings chai) async {
    try {
      final recipe = await ref.read(myChaiRecipeProvider.future);
      final preview = await recipe.preview(kLocalNutritionUserScopeId, chai);
      if (!mounted) return;
      setState(() => _cupFacts = myChaiFactsLine(preview.calculation.facts));
    } on Object catch (error, stackTrace) {
      AppLogger.error('My chai facts failed', error, stackTrace);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final recipe = await ref.read(myChaiRecipeProvider.future);
      await recipe.save(kLocalNutritionUserScopeId, _chai);
      await _chai.write(
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
            await SharedPreferences.getInstance(),
      );
      ref.invalidate(myChaiSettingsProvider);
      await _loadFacts(_chai);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Saved. "+ Chai" adds this cup.'),
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Saving My chai failed', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text("Couldn't save your chai. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _choices<T>(
    String title,
    List<T> values,
    T selected,
    String Function(T) label,
    ValueChanged<T> onSelected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(title, style: B05Typography.sectionLabel(context)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            ChoiceChip(
              label: Text(label(value)),
              selected: value == selected,
              onSelected: (_) => setState(() {
                onSelected(value);
                _cupFacts = null;
              }),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    String tsp(double value) => value == 0
        ? 'None'
        : '${value == value.roundToDouble() ? value.round() : value} tsp';
    return Scaffold(
      appBar: AppBar(title: const Text('My chai')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Set your chai once. "+ Chai" on Today and in search then logs '
            'one cup, sugar included.',
            style: B05Typography.body(context),
          ),
          _choices(
            'Milk',
            MyChaiMilk.values,
            _chai.milk,
            (milk) => milk.label,
            (milk) => _chai = _chai.copyWith(milk: milk),
          ),
          if (_chai.milk.isDairy)
            _choices(
              'How much of the cup is milk',
              MyChaiMilkShare.values,
              _chai.milkShare,
              (share) => share.label,
              (share) => _chai = _chai.copyWith(milkShare: share),
            ),
          _choices(
            'Sugar',
            kMyChaiSugarChoices,
            _chai.sugarTeaspoons,
            tsp,
            (value) => _chai = _chai.copyWith(sugarTeaspoons: value),
          ),
          _choices(
            'Cup size',
            kMyChaiCupChoicesMillilitres,
            _chai.cupMillilitres,
            (ml) => '$ml ml',
            (ml) => _chai = _chai.copyWith(cupMillilitres: ml),
          ),
          const SizedBox(height: 24),
          Text('Your recipe', style: B05Typography.sectionLabel(context)),
          const SizedBox(height: 8),
          Text(
            _chai.recipeLine,
            key: const Key('my_chai_recipe_line'),
            style: B05Typography.body(context),
          ),
          if (_cupFacts != null) ...[
            const SizedBox(height: 4),
            Text(
              'One cup: $_cupFacts',
              key: const Key('my_chai_cup_facts'),
              style: B05Typography.label(context),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _chai.milk.isDairy
                ? 'Milk and sugar values are USDA FoodData Central. Tea '
                      'water adds nothing.'
                : 'Black tea and sugar values are USDA FoodData Central.',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('my_chai_save'),
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(_saving ? 'Saving…' : 'Save my chai'),
          ),
        ],
      ),
    );
  }
}

/// "78 kcal · 2.4 g protein · 13 g carbs" from a cup's facts; missing facts
/// are left out.
String myChaiFactsLine(Map<String, NutrientFact> facts) {
  String? part(String id, String suffix, {int decimals = 0}) {
    final value = facts[id]?.point?.value.asDouble;
    if (value == null) return null;
    final text = decimals == 0
        ? value.round().toString()
        : value.toStringAsFixed(decimals);
    return '$text$suffix';
  }

  return [
    part('energy', ' kcal'),
    part('protein', ' g protein', decimals: 1),
    part('carbohydrate', ' g carbs'),
  ].whereType<String>().join(' · ');
}

/// The "Your chai" row in Household measures: the saved recipe, or a
/// prompt to set it up.
class MyChaiEntry extends ConsumerWidget {
  const MyChaiEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chai = ref.watch(myChaiSettingsProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.local_cafe_outlined),
      title: Text(chai == null ? 'Set up My chai' : 'My chai'),
      subtitle: Text(
        chai?.recipeLine ??
            'Milk, sugar and cup size once; then "+ Chai" logs a cup.',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MyChaiSetupScreen()),
        ),
      ),
    );
  }
}

/// Phulka, tawa or tandoori (UF-3), each shown with the catalogue roti it
/// logs.
class MyRotiChoice extends ConsumerWidget {
  const MyRotiChoice({super.key});

  static const _foodNames = {
    MyRoti.phulka: 'Whole Wheat Roti / Chapati (Mini)',
    MyRoti.tawa: 'Whole Wheat Roti / Chapati',
    MyRoti.tandoori: 'Tandoori Roti (Wheat)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(myRotiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final roti in MyRoti.values)
              ChoiceChip(
                key: Key('my_roti_${roti.stableId}'),
                label: Text(roti.label),
                selected: roti == selected,
                onSelected: (_) async {
                  final prefs =
                      sharedPreferencesOrNull(
                        () => ref.read(sharedPreferencesProvider),
                      ) ??
                      await SharedPreferences.getInstance();
                  await roti.write(prefs);
                  ref.invalidate(myRotiProvider);
                },
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 4),
          Text(
            'Logs as ${_foodNames[selected]}',
            style: B05Typography.caption(context),
          ),
        ],
      ],
    );
  }
}
