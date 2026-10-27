import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../data/models/progress_period_comparison_models.dart';
import '../../../data/repositories/progress_period_comparison_repository.dart';
import '../../training/muscles_this_week.dart';

/// TP-9 (Plus): two periods side by side. The weekly comparison that ships
/// free is separate and unchanged.
enum RangeComparisonMode { month, custom }

/// Inclusive civil dates.
@immutable
class CivilRange {
  const CivilRange(this.startLocalDate, this.endLocalDate);

  final String startLocalDate;
  final String endLocalDate;

  @override
  bool operator ==(Object other) =>
      other is CivilRange &&
      other.startLocalDate == startLocalDate &&
      other.endLocalDate == endLocalDate;

  @override
  int get hashCode => Object.hash(startLocalDate, endLocalDate);
}

@immutable
class RangeComparisonRequest {
  const RangeComparisonRequest({required this.first, required this.second});

  /// Last month, by default: shown on the left.
  final CivilRange first;

  /// This month so far, by default: shown on the right.
  final CivilRange second;

  /// Last month, whole, against this month up to [today].
  static RangeComparisonRequest months(
    String today, {
    required String timezoneId,
    required LocalScheduleDateService dates,
  }) {
    final thisMonthStart = '${today.substring(0, 8)}01';
    final lastMonthEnd = dates.addCalendarDays(thisMonthStart, timezoneId, -1);
    return RangeComparisonRequest(
      first: CivilRange('${lastMonthEnd.substring(0, 8)}01', lastMonthEnd),
      second: CivilRange(thisMonthStart, today),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RangeComparisonRequest &&
      other.first == first &&
      other.second == second;

  @override
  int get hashCode => Object.hash(first, second);
}

/// What one period shows. Null means "not enough data to say", never a
/// stand-in zero; counts of saved things (workouts, sets) are real zeros.
@immutable
class PeriodRangeFacts {
  const PeriodRangeFacts({required this.summary, required this.muscles});

  final PeriodRangeSummary summary;
  final MuscleSetCounts muscles;

  int get workouts => summary.training.sessionCount;
  int get workingSets => summary.training.workingSetsCount;

  double? get volumeKg {
    final training = summary.training;
    return training.volumeIsTrustworthy && training.totalVolumeKg > 0
        ? training.totalVolumeKg
        : null;
  }

  /// Days with food logged; null when nutrition could not be read.
  int? get daysLogged => summary.nutrition?.loggedDaysCount;

  /// Average over logged days only; null with none logged.
  double? get averageProteinG {
    final nutrition = summary.nutrition;
    if (nutrition == null || !nutrition.hasLoggedDays) return null;
    return nutrition.averageProteinG;
  }

  /// First to last weigh-in inside the period; needs at least 2.
  double? get weightChangeKg {
    final weight = summary.weight;
    return weight.hasMeaningfulDelta ? weight.deltaKg : null;
  }

  int get weighIns => summary.weight.observationCount;
}

@immutable
class RangeComparison {
  const RangeComparison({required this.first, required this.second});

  final PeriodRangeFacts first;
  final PeriodRangeFacts second;
}

final rangeComparisonModeProvider = StateProvider<RangeComparisonMode>(
  (ref) => RangeComparisonMode.month,
);

/// The two periods the user picked; null until they pick, which shows the
/// month periods.
final customRangeComparisonProvider = StateProvider<RangeComparisonRequest?>(
  (ref) => null,
);

final monthRangeComparisonRequestProvider =
    FutureProvider.autoDispose<RangeComparisonRequest>((ref) async {
      ref.watch(civilDateRevisionProvider);
      final dates = ref.watch(localScheduleDateServiceProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      return RangeComparisonRequest.months(
        dates.todayIn(timezoneId),
        timezoneId: timezoneId,
        dates: dates,
      );
    });

final rangeComparisonProvider = FutureProvider.autoDispose
    .family<RangeComparison, RangeComparisonRequest>((ref, request) async {
      final dates = ref.watch(localScheduleDateServiceProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final repository = ProgressPeriodComparisonRepository(
        database: ref.watch(databaseProvider),
        dates: dates,
        nutrition: await ref.watch(nutritionReadModelRepositoryProvider.future),
        nutritionTargets: ref.watch(nutritionTargetAuthorityProvider),
      );
      final nowUtc = DateTime.now().toUtc();
      Future<PeriodRangeFacts> facts(CivilRange range) async {
        final summary = await repository.summarizeRange(
          startLocalDate: range.startLocalDate,
          endLocalDate: range.endLocalDate,
          nowUtc: nowUtc,
          timezoneId: timezoneId,
        );
        final muscles = await ref.watch(
          muscleSetsProvider(
            MuscleSetRange(
              startLocalDate: range.startLocalDate,
              endLocalDate: range.endLocalDate,
              timezoneId: timezoneId,
            ),
          ).future,
        );
        return PeriodRangeFacts(summary: summary, muscles: muscles);
      }

      return RangeComparison(
        first: await facts(request.first),
        second: await facts(request.second),
      );
    });

/// The comparison for the selected mode.
final activeRangeComparisonProvider =
    FutureProvider.autoDispose<RangeComparison>((ref) async {
      final mode = ref.watch(rangeComparisonModeProvider);
      final custom = ref.watch(customRangeComparisonProvider);
      final request = mode == RangeComparisonMode.custom && custom != null
          ? custom
          : await ref.watch(monthRangeComparisonRequestProvider.future);
      return ref.watch(rangeComparisonProvider(request).future);
    });
