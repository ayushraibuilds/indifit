import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../settings/unit_preference.dart';
import '../workout_player/widgets/workout_share_card.dart';
import 'training_bests.dart';
import 'weekly_check_in.dart';
import 'widgets/progress_formatters.dart';
import 'widgets/progress_stat.dart';

/// The Sunday check-in (UF-15): the week's workouts, best set, food days,
/// protein, weight trend and next week's training days. The weekly progress
/// reminder opens it.
class WeeklyCheckInScreen extends ConsumerStatefulWidget {
  const WeeklyCheckInScreen({super.key});

  @override
  ConsumerState<WeeklyCheckInScreen> createState() =>
      _WeeklyCheckInScreenState();
}

class _WeeklyCheckInScreenState extends ConsumerState<WeeklyCheckInScreen> {
  final _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(WeeklyCheckIn checkIn, String units) async {
    setState(() => _sharing = true);
    final text = weeklyCheckInShareText(checkIn, units);
    try {
      final bytes = await renderWorkoutStoryPng(_shareKey);
      if (bytes == null) {
        await Share.share(text);
        return;
      }
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: const ['indifit-week.png'],
      );
    } catch (error) {
      AppLogger.warning('Check-in share failed: $error', 'WeeklyCheckIn');
      await Share.share(text);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var units = 'kg';
    try {
      units = ref.watch(unitPreferenceProvider);
    } on StateError {
      units = 'kg';
    }
    final state = ref.watch(weeklyCheckInProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your week')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space24),
            child: Text(
              "Couldn't load your week. Try again.",
              style: B05Typography.body(context),
            ),
          ),
        ),
        data: (checkIn) => checkIn.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(B05Layout.space16),
                child: ProductEmptyState(
                  key: const Key('weekly_check_in_empty'),
                  icon: Icons.event_note_rounded,
                  title: 'Nothing for this week yet',
                  message:
                      'Your workouts, protein and weigh-ins from Mon–Sun will show here.',
                  action: () => goToTrainingTab(context),
                  actionLabel: 'Start a workout',
                  actionIcon: Icons.fitness_center_rounded,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  WeeklyCheckInView(checkIn: checkIn, units: units),
                  const SizedBox(height: B05Layout.space24),
                  // The share image, previewed as the workout share card is.
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: b05Radius(B05SurfaceRadius.large),
                          child: AspectRatio(
                            aspectRatio: WorkoutStoryCard.size.aspectRatio,
                            child: FittedBox(
                              child: RepaintBoundary(
                                key: _shareKey,
                                child: WeeklyCheckInStoryCard(
                                  checkIn: checkIn,
                                  units: units,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  FilledButton.icon(
                    key: const Key('weekly_check_in_share'),
                    onPressed: _sharing
                        ? null
                        : () => unawaited(_share(checkIn, units)),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share my week'),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Text(
                    'The image has no name or photo, only these numbers.',
                    textAlign: TextAlign.center,
                    style: B05Typography.caption(context),
                  ),
                ],
              ),
      ),
    );
  }
}

String _day(String localDate, String pattern) =>
    DateFormat(pattern).format(DateTime.parse(localDate));

/// "13–19 Oct".
String weeklyCheckInRange(WeeklyCheckIn checkIn) =>
    '${_day(checkIn.weekStart, 'd')}–${_day(checkIn.weekEnd, 'd MMM')}';

String _bestLine(TrainingBest best, String units) =>
    '${best.exerciseName}: ${formatWeight(best.set.loadKg, units)} × '
    '${best.set.reps}';

/// The check-in's facts as lines, shared by the screen, the image and the
/// text fallback. A fact without data says so instead of a number.
class WeeklyCheckInFacts {
  WeeklyCheckInFacts(this.checkIn, this.units);

  final WeeklyCheckIn checkIn;
  final String units;

  String get workouts => '${checkIn.workoutsDone}/${checkIn.goal} workouts';

  String get best => checkIn.bestSet == null
      ? 'No new bests this week'
      : _bestLine(checkIn.bestSet!, units);

  String get daysLogged => '${checkIn.daysLogged}/7 days logged';

  String? get protein => checkIn.averageProteinG == null
      ? null
      : '${checkIn.averageProteinG!.round()} g protein a day';

  String get weight {
    final change = checkIn.weightChangeKg;
    if (change == null) {
      return checkIn.weighInDays == 1
          ? '1 weigh-in: log another for a trend'
          : 'No weigh-ins this week';
    }
    final sign = change > 0 ? '+' : (change < 0 ? '−' : '');
    return '$sign${formatWeight(change.abs(), units)} '
        '(${formatWeight(checkIn.firstWeightKg!, units)} → '
        '${formatWeight(checkIn.lastWeightKg!, units)})';
  }

  String get nextWeek => checkIn.nextWeekTrainingDates.isEmpty
      ? 'No training days scheduled'
      : checkIn.nextWeekTrainingDates.map((d) => _day(d, 'EEE')).join(' · ');
}

String weeklyCheckInShareText(WeeklyCheckIn checkIn, String units) {
  final facts = WeeklyCheckInFacts(checkIn, units);
  return [
    'My week on IndiFit (${weeklyCheckInRange(checkIn)})',
    facts.workouts,
    'Best set: ${facts.best}',
    facts.daysLogged,
    ?facts.protein,
    'Weight: ${facts.weight}',
  ].join('\n');
}

class WeeklyCheckInView extends StatelessWidget {
  const WeeklyCheckInView({
    super.key,
    required this.checkIn,
    required this.units,
  });

  final WeeklyCheckIn checkIn;
  final String units;

  @override
  Widget build(BuildContext context) {
    final facts = WeeklyCheckInFacts(checkIn, units);
    final change = checkIn.weightChangeKg;
    Widget card(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: B05Layout.space12),
      child: B05Surface(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: B05Typography.sectionLabel(context)),
            const SizedBox(height: B05Layout.space8),
            child,
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          weeklyCheckInRange(checkIn),
          style: B05Typography.pageTitle(context),
        ),
        card(
          'Training',
          ProgressStat(
            key: const Key('check_in_workouts'),
            value: '${checkIn.workoutsDone}/${checkIn.goal}',
            unit: 'workouts',
            detail: facts.best,
            delta: checkIn.workoutsDone >= checkIn.goal && checkIn.goal > 0
                ? const ProgressStatDelta(
                    text: 'Goal met',
                    trend: ProgressTrend.up,
                  )
                : null,
          ),
        ),
        card(
          'Food',
          ProgressStat(
            key: const Key('check_in_food'),
            value: '${checkIn.daysLogged}/7',
            unit: 'days logged',
            detail: facts.protein == null
                ? 'No protein logged this week'
                : 'Protein: ${facts.protein} on '
                      '${checkIn.proteinDays} logged '
                      '${checkIn.proteinDays == 1 ? 'day' : 'days'}',
          ),
        ),
        card(
          'Weight',
          change == null
              ? Text(
                  facts.weight,
                  key: const Key('check_in_weight'),
                  style: B05Typography.body(context),
                )
              : ProgressStat.split(
                  formatWeight(checkIn.lastWeightKg!, units),
                  key: const Key('check_in_weight'),
                  detail:
                      'First ${formatWeight(checkIn.firstWeightKg!, units)}, '
                      '${checkIn.weighInDays} weigh-in days',
                  delta: ProgressStatDelta(
                    text: facts.weight.split(' (').first,
                    trend: change > 0
                        ? ProgressTrend.up
                        : change < 0
                        ? ProgressTrend.down
                        : ProgressTrend.flat,
                    neutral: true,
                  ),
                ),
        ),
        card(
          'Next week',
          Text(
            facts.nextWeek,
            key: const Key('check_in_next_week'),
            style: B05Typography.body(context),
          ),
        ),
      ],
    );
  }
}

/// The share image: the same facts on the V6 story canvas (360 × 640,
/// rendered at 3×), with no name or photo.
class WeeklyCheckInStoryCard extends StatelessWidget {
  const WeeklyCheckInStoryCard({
    super.key,
    required this.checkIn,
    required this.units,
  });

  final WeeklyCheckIn checkIn;
  final String units;

  @override
  Widget build(BuildContext context) {
    final facts = WeeklyCheckInFacts(checkIn, units);
    const ink = Color(0xFFF1F5F9);
    const muted = Color(0xFF94A3B8);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: WorkoutStoryCard.size,
        child: ColoredBox(
          color: const Color(0xFF0B1220),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My week · ${weeklyCheckInRange(checkIn)}',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                line('Training', facts.workouts),
                line('Best set', facts.best),
                line('Food', facts.daysLogged),
                if (facts.protein != null) line('Protein', facts.protein!),
                line('Weight', facts.weight),
                const Spacer(),
                const Text(
                  'IndiFit',
                  style: TextStyle(color: muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
