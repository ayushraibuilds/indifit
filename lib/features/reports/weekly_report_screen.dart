import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/weekly_report_service.dart';

class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  bool _isLoading = true;
  WeeklyReportResult? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final service = ref.read(weeklyReportServiceProvider);
    final report = await service.generateReport(
      totalCaloriesLogged: 14200,
      calorieGoal: 14000,
      workoutSessionsCount: 4,
      totalVolumeKg: 13500.0,
      prsCount: 3,
      adherenceScore: 92.0,
    );

    if (mounted) {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly AI Summary'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: AppColors.primary, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _report?.headline ?? 'Weekly Summary',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _report?.summary ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
                              SizedBox(width: 8),
                              Text('AI COACHING TIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _report?.coachingTip ?? '',
                            style: const TextStyle(height: 1.4, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
