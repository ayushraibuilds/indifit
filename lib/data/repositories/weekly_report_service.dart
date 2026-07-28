import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import 'progress_statistics_repository.dart';

final weeklyReportServiceProvider = Provider<WeeklyReportService>((ref) {
  final dio = ref.watch(dioProvider);
  final policy = ref.watch(privacyPolicyProvider);
  return WeeklyReportService(dio, policy);
});

class WeeklyReportResult {
  final String headline;
  final double adherenceScore;
  final String summary;
  final String coachingTip;
  final List<String> topPrs;
  final bool isFallback;
  final bool isInsufficientData;
  final String? fallbackReason;

  WeeklyReportResult({
    required this.headline,
    required this.adherenceScore,
    required this.summary,
    required this.coachingTip,
    required this.topPrs,
    this.isFallback = false,
    this.isInsufficientData = false,
    this.fallbackReason,
  });
}

class WeeklyReportService {
  final Dio _dio;
  final PrivacyPolicy? _policy;

  WeeklyReportService([Dio? dio, PrivacyPolicy? policy])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ),
          ),
      _policy = policy;

  Future<WeeklyReportResult> generateReportFromMetrics(
    WeeklyMetrics metrics,
  ) async {
    return generateReport(
      totalCaloriesLogged: metrics.totalCaloriesLogged,
      calorieGoal: metrics.totalCaloriesGoal,
      workoutSessionsCount: metrics.completedWorkoutsCount,
      totalVolumeKg: metrics.totalVolumeKg,
      prsCount: metrics.prsCount,
      adherenceScore: metrics.overallAdherenceScore * 100,
      metrics: metrics,
    );
  }

  Future<WeeklyReportResult> generateReport({
    required int totalCaloriesLogged,
    required int calorieGoal,
    required int workoutSessionsCount,
    required double totalVolumeKg,
    required int prsCount,
    required double adherenceScore,
    WeeklyMetrics? metrics,
  }) async {
    final nutritionDays = metrics?.nutritionDaysLogged ?? (totalCaloriesLogged > 0 ? 1 : 0);
    final completedWorkouts = metrics?.completedWorkoutsCount ?? workoutSessionsCount;
    final plannedWorkouts = metrics?.plannedWorkoutsCount ?? 0;
    final hydrationDays = metrics?.hydrationDaysAtGoal ?? 0;
    final dateRangeStr = metrics != null
        ? "${metrics.startDate.year}-${metrics.startDate.month.toString().padLeft(2, '0')}-${metrics.startDate.day.toString().padLeft(2, '0')} to ${metrics.endDate.year}-${metrics.endDate.month.toString().padLeft(2, '0')}-${metrics.endDate.day.toString().padLeft(2, '0')}"
        : null;

    // Honest insufficient data state check
    if (nutritionDays < 2 && completedWorkouts == 0) {
      return WeeklyReportResult(
        headline: 'Log a few more days to unlock your report',
        adherenceScore: 0.0,
        summary:
            'Log at least 2 days of nutrition or 1 workout session during the week to unlock your personalized AI weekly report.',
        coachingTip:
            'Focus on logging your daily meals and water intake to build baseline habits!',
        topPrs: const [],
        isFallback: true,
        isInsufficientData: true,
        fallbackReason: 'Insufficient Weekly Data',
      );
    }

    if (_policy != null && !_policy.isAiAllowed) {
      return _generateOfflineFallback(
        totalCaloriesLogged: totalCaloriesLogged,
        workoutSessionsCount: completedWorkouts,
        plannedWorkoutsCount: plannedWorkouts,
        totalVolumeKg: totalVolumeKg,
        prsCount: prsCount,
        nutritionDaysLogged: nutritionDays,
        adherenceScore: adherenceScore,
        dateRange: dateRangeStr,
        reason: 'Strict Offline Privacy Mode',
      );
    }

    try {
      final payload = <String, dynamic>{
        'total_calories_logged': totalCaloriesLogged,
        'calorie_goal': calorieGoal,
        'workout_sessions_count': completedWorkouts,
        'total_volume_kg': totalVolumeKg,
        'prs_count': prsCount,
        'adherence_score': adherenceScore,
        'date_range': dateRangeStr,
        'nutrition_days_logged': nutritionDays,
        'calorie_adherence_pct': (metrics?.calorieAdherenceScore ?? 0.0) * 100,
        'protein_adherence_pct': (metrics?.proteinAdherenceScore ?? 0.0) * 100,
        'hydration_days_at_goal': hydrationDays,
        'completed_workouts': completedWorkouts,
        'planned_workouts': plannedWorkouts,
      };

      final response = await _dio.post(
        '${AppConfig.backendUrl}/api/ai/weekly-report',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        return WeeklyReportResult(
          headline: d['headline'] ?? 'Weekly Summary',
          adherenceScore:
              (d['adherence_score'] as num?)?.toDouble() ?? adherenceScore,
          summary:
              d['summary'] ??
              'Consistent nutrition and workout effort across the week.',
          coachingTip:
              d['coaching_tip'] ??
              'Keep staying hydrated and aim for progressive overload.',
          topPrs:
              (d['top_prs'] as List?)?.map((e) => e.toString()).toList() ?? [],
          isFallback: d['is_fallback'] ?? false,
          fallbackReason: d['fallback_reason'],
        );
      }
    } catch (e, st) {
      AppLogger.warning('Weekly report AI parsing failed, using fallback: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'WeeklyReportService AI response parse failure',
      );
    }

    return _generateOfflineFallback(
      totalCaloriesLogged: totalCaloriesLogged,
      workoutSessionsCount: completedWorkouts,
      plannedWorkoutsCount: plannedWorkouts,
      totalVolumeKg: totalVolumeKg,
      prsCount: prsCount,
      nutritionDaysLogged: nutritionDays,
      adherenceScore: adherenceScore,
      dateRange: dateRangeStr,
    );
  }

  WeeklyReportResult _generateOfflineFallback({
    required int totalCaloriesLogged,
    required int workoutSessionsCount,
    required int plannedWorkoutsCount,
    required double totalVolumeKg,
    required int prsCount,
    required int nutritionDaysLogged,
    required double adherenceScore,
    String? dateRange,
    String reason = 'Offline Local Generator',
  }) {
    final rangeText = dateRange != null ? 'For $dateRange: ' : '';
    final workoutText = plannedWorkoutsCount > 0
        ? '$workoutSessionsCount of $plannedWorkoutsCount planned workouts'
        : '$workoutSessionsCount workouts';

    final prText = prsCount > 0
        ? '$prsCount Personal Records Hit'
        : 'Consistent Logging Effort';

    return WeeklyReportResult(
      headline: 'Weekly Progress Summary',
      adherenceScore: adherenceScore,
      summary:
          '${rangeText}You logged nutrition on $nutritionDaysLogged days ($totalCaloriesLogged total kcal), completed $workoutText (${totalVolumeKg.toStringAsFixed(0)} kg total volume), and achieved $prsCount PRs.',
      coachingTip:
          'Maintain your progressive overload, stay hydrated, and target consistent protein intake.',
      topPrs: [prText],
      isFallback: true,
      fallbackReason: reason,
    );
  }
}
