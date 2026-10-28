import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../food_log/food_log_surface.dart';
import '../../food_log/log_confirmation.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/my_roti.dart';
import '../../voice/voice_mic_button.dart';
import '../cook_with_what_i_have.dart';
import '../protein_nudge.dart';
import '../today_surface_controller.dart';
import '../weigh_in_reminder.dart';

/// "Cook with what I have" (TF-2 C, Plus): pick or say ingredients, see
/// saved recipes you can make, then dishes by how much of them you have.
class CookWithWhatIHaveScreen extends ConsumerStatefulWidget {
  const CookWithWhatIHaveScreen({super.key, required this.day});

  /// The day "+ Add" logs to.
  final DateTime day;

  @override
  ConsumerState<CookWithWhatIHaveScreen> createState() =>
      _CookWithWhatIHaveScreenState();
}

class _CookWithWhatIHaveScreenState
    extends ConsumerState<CookWithWhatIHaveScreen> {
  final _text = TextEditingController();
  final Set<String> _have = {};
  List<String> _unknown = const [];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addText(String text) async {
    if (text.trim().isEmpty) return;
    final vocabulary = await ref.read(ingredientVocabularyProvider.future);
    final parsed = vocabulary.parse(text);
    if (!mounted) return;
    setState(() {
      _have.addAll(parsed.words);
      _unknown = parsed.unknown;
      _text.clear();
    });
  }

  Future<void> _add(CookResult result) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = ref.read(weighInClockProvider)();
      final snapshot = await logOneCatalogueServing(
        ref,
        foodId: result.id,
        mealCategory: MealPresentationRegistry.forLocalTime(now).stableId,
        day: widget.day,
        quantity: result.quantity,
      );
      if (!mounted || snapshot == null) return;
      ref.invalidate(canonicalFoodRecordsForDayProvider);
      ref.invalidate(foodDiaryReadModelProvider);
      ref.read(todayNutritionRevisionProvider.notifier).state++;
      ref.read(proteinNudgeRevisionProvider.notifier).state++;
      showLoggedFoodUndo(
        context,
        snapshot,
        amount: result.amountLabel,
        name: result.name,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Cook with what I have add failed', error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = {...CookWithWhatIHave.commonIngredients, ..._have};
    final results = _have.isEmpty
        ? null
        : ref.watch(cookResultsProvider(cookHaveKey(_have)));
    return Scaffold(
      appBar: AppBar(title: const Text('Cook with what I have')),
      body: ListView(
        key: const Key('cook_with_what_i_have'),
        padding: const EdgeInsets.all(B05Layout.space16),
        children: [
          TextField(
            controller: _text,
            textInputAction: TextInputAction.done,
            onSubmitted: _addText,
            decoration: InputDecoration(
              labelText: 'What do you have?',
              hintText: 'paneer, shimla mirch, pyaz…',
              suffixIcon: VoiceMicButton.maybe(ref, onTranscript: _addText),
            ),
          ),
          if (_unknown.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              'Not in the ingredient list: ${_unknown.join(', ')}',
              style: B05Typography.caption(context),
            ),
          ],
          const SizedBox(height: B05Layout.space12),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space4,
            children: [
              for (final word in chips)
                FilterChip(
                  label: Text(word),
                  selected: _have.contains(word),
                  onSelected: (on) =>
                      setState(() => on ? _have.add(word) : _have.remove(word)),
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          if (results == null)
            Text(
              'Pick what you have to see what you can cook.',
              style: B05Typography.caption(context),
            )
          else
            results.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(B05Layout.space16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                "Couldn't load dishes. Try again.",
                style: B05Typography.caption(context),
              ),
              data: (rows) => rows.isEmpty
                  ? Text(
                      'No dish in the food database uses these.',
                      style: B05Typography.caption(context),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row in rows)
                          _ResultRow(
                            result: row,
                            onAdd: row.isRecipe || _busy
                                ? null
                                : () => unawaited(_add(row)),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onAdd});

  final CookResult result;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final kcal = result.kcal;
    final protein = result.proteinGrams;
    final facts = [
      result.amountLabel,
      if (kcal != null) '${ConsumerNumberLabel.rounded(kcal)} kcal',
      if (protein != null) '${ConsumerNumberLabel.grams(protein)} protein',
    ].join(' · ');
    return Padding(
      key: ValueKey('cook_${result.id}'),
      padding: const EdgeInsets.only(top: B05Layout.space8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name, style: B05Typography.body(context)),
                Text(result.detail, style: B05Typography.caption(context)),
                Text(facts, style: B05Typography.caption(context)),
              ],
            ),
          ),
          if (result.isRecipe)
            TextButton(
              onPressed: () => context.push(
                Uri(
                  path: '/food/recipes/edit',
                  queryParameters: {'recipeId': result.id},
                ).toString(),
              ),
              child: const Text('Open recipe'),
            )
          else
            TextButton(
              onPressed: onAdd,
              child: Semantics(
                label: 'Add ${result.name}',
                excludeSemantics: true,
                child: const Text('+ Add'),
              ),
            ),
        ],
      ),
    );
  }
}
