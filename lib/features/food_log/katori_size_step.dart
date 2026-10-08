import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/catalog/katori_size.dart';

/// The person's katori in millilitres, or null until they've chosen.
final myKatoriMillilitresProvider = FutureProvider.autoDispose<double?>(
  (ref) => readMyKatoriMillilitres(ref.watch(databaseProvider)),
);

/// Remembers "Not now" on the katori question.
const String kKatoriPromptDismissedKey = 'katori_size_prompt_dismissed_v1';

/// Saves [millilitres] as the person's katori: a "My katori" personal
/// vessel (created once) with a new calibration, so it's backed up with
/// their other measures and every catalogue katori follows it.
Future<void> saveMyKatori(WidgetRef ref, double millilitres) async {
  final repository = ref.read(nutritionHouseholdMeasureRepositoryProvider);
  const userId = kLocalNutritionUserScopeId;
  final vessels = await repository.listVessels(userId: userId);
  final existing = vessels
      .where((vessel) => vessel.vesselType == kMyKatoriVesselType)
      .lastOrNull;
  final vessel =
      existing ??
      await repository.createVessel(
        userId: userId,
        displayName: 'My katori',
        vesselType: kMyKatoriVesselType,
      );
  await repository.addCalibration(
    userId: userId,
    vesselId: vessel.id,
    volume: Quantity.fromNum(
      amount: millilitres,
      unit: QuantityUnit.millilitre,
    ),
    method: 'size_choice',
    // Picked from three sizes, not measured.
    confidence: 0.5,
    notes: 'Chosen from Small, Standard or Large',
  );
  ref.invalidate(myKatoriMillilitresProvider);
}

/// Small · Standard · Large, with the current choice selected.
class KatoriSizeChoice extends ConsumerWidget {
  const KatoriSizeChoice({super.key, this.onChosen});

  /// After a size is saved, e.g. to recalculate an open thali.
  final ValueChanged<double>? onChosen;

  static String label(double millilitres) => switch (millilitres) {
    100 => 'Small',
    150 => 'Standard',
    200 => 'Large',
    _ => '${millilitres.round()} ml',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(myKatoriMillilitresProvider).valueOrNull;
    final selected = current ?? kStandardKatoriMillilitres;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final size in kKatoriSizeChoicesMillilitres)
          ChoiceChip(
            key: Key('katori_size_${size.round()}'),
            avatar: Icon(Icons.rice_bowl_outlined, size: 12 + size / 25),
            label: Text('${label(size)} · about ${size.round()} ml'),
            selected: current != null && selected == size,
            onSelected: (_) async {
              await saveMyKatori(ref, size);
              onChosen?.call(size);
            },
          ),
      ],
    );
  }
}

/// "How big is your katori?", once: a line in the thali builder until the
/// person picks a size or taps "Not now". Changeable later in Settings →
/// Household measures.
class KatoriSizePromptCard extends ConsumerStatefulWidget {
  const KatoriSizePromptCard({super.key, this.onChosen});

  final ValueChanged<double>? onChosen;

  @override
  ConsumerState<KatoriSizePromptCard> createState() =>
      _KatoriSizePromptCardState();
}

class _KatoriSizePromptCardState extends ConsumerState<KatoriSizePromptCard> {
  bool _dismissed = false;

  Future<SharedPreferences> _prefs() async =>
      sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
      await SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _prefs()
        .then((prefs) {
          if (mounted && prefs.getBool(kKatoriPromptDismissedKey) == true) {
            setState(() => _dismissed = true);
          }
        })
        .catchError((Object _) {
          // Safe: without stored preferences the question simply shows.
        });
  }

  Future<void> _notNow() async {
    setState(() => _dismissed = true);
    try {
      await (await _prefs()).setBool(kKatoriPromptDismissedKey, true);
    } catch (_) {
      // Safe: it's hidden for now and may ask again next time.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myKatoriMillilitresProvider);
    if (_dismissed || !mine.hasValue || mine.value != null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('katori_size_prompt'),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          const Icon(Icons.rice_bowl_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'How big is your katori?',
              style: B05Typography.caption(context),
            ),
          ),
          TextButton(
            key: const Key('katori_size_open'),
            onPressed: _openChoice,
            child: const Text('Set size'),
          ),
          IconButton(
            key: const Key('katori_size_not_now'),
            tooltip: 'Not now',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _notNow,
          ),
        ],
      ),
    );
  }

  Future<void> _openChoice() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // Large text or a small phone still reaches every size.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which katori looks like yours?',
                  style: B05Typography.title(sheetContext),
                ),
                const SizedBox(height: 4),
                Text(
                  'IndiFit counts a katori as about 150 ml. Pick yours and '
                  '"1 katori" will mean your katori. Sizes are approximate; '
                  'change it any time in Settings → Household measures.',
                  style: B05Typography.body(sheetContext),
                ),
                const SizedBox(height: 12),
                KatoriSizeChoice(
                  onChosen: (size) {
                    Navigator.of(sheetContext).pop();
                    widget.onChosen?.call(size);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
