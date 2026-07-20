import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/repositories/weekly_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Features Unit Tests', () {
    test('WeeklyReportService fallback generator returns expected report fields', () async {
      final service = WeeklyReportService();

      final report = await service.generateReport(
        totalCaloriesLogged: 14000,
        calorieGoal: 14000,
        workoutSessionsCount: 4,
        totalVolumeKg: 12000.0,
        prsCount: 3,
        adherenceScore: 90.0,
      );

      expect(report.headline.isNotEmpty, true);
      expect(report.adherenceScore, 90.0);
      expect(report.summary.contains('4 workouts'), true);
      expect(report.coachingTip.isNotEmpty, true);
      expect(report.topPrs.isNotEmpty, true);
      expect(report.isFallback, true);
    });
  });
}
