import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';

final weeklyReportServiceProvider = Provider<WeeklyReportService>((ref) {
  final dio = ref.watch(dioProvider);
  return WeeklyReportService(dio);
});

class WeeklyReportResult {
  final String headline;
  final double adherenceScore;
  final String summary;
  final String coachingTip;
  final List<String> topPrs;
  final bool isFallback;
  final String? fallbackReason;

  WeeklyReportResult({
    required this.headline,
    required this.adherenceScore,
    required this.summary,
    required this.coachingTip,
    required this.topPrs,
    this.isFallback = false,
    this.fallbackReason,
  });
}

class WeeklyReportService {
  final Dio _dio;

  WeeklyReportService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ));

  Future<WeeklyReportResult> generateReport({
    required int totalCaloriesLogged,
    required int calorieGoal,
    required int workoutSessionsCount,
    required double totalVolumeKg,
    required int prsCount,
    required double adherenceScore,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.backendUrl}/api/ai/weekly-report',
        data: {
          'total_calories_logged': totalCaloriesLogged,
          'calorie_goal': calorieGoal,
          'workout_sessions_count': workoutSessionsCount,
          'total_volume_kg': totalVolumeKg,
          'prs_count': prsCount,
          'adherence_score': adherenceScore,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        return WeeklyReportResult(
          headline: d['headline'] ?? 'Great Week!',
          adherenceScore: (d['adherence_score'] as num?)?.toDouble() ?? adherenceScore,
          summary: d['summary'] ?? 'Consistent nutrition and workout effort across the week.',
          coachingTip: d['coaching_tip'] ?? 'Keep staying hydrated and aim for progressive overload.',
          topPrs: (d['top_prs'] as List?)?.map((e) => e.toString()).toList() ?? [],
          isFallback: d['is_fallback'] ?? false,
          fallbackReason: d['fallback_reason'],
        );
      }
    } catch (_) {}

    return WeeklyReportResult(
      headline: 'Outstanding Consistency This Week!',
      adherenceScore: adherenceScore,
      summary: 'You completed $workoutSessionsCount workouts and logged $totalCaloriesLogged kcal total across the week.',
      coachingTip: 'Prioritize adequate sleep and keep hitting your daily protein target.',
      topPrs: ['Consistent Log Streak', 'Workout Target Completed'],
      isFallback: true,
      fallbackReason: 'Offline Local Generator',
    );
  }
}
