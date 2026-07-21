import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/weekly_report_service.dart';
import '../dashboard/dashboard_controller.dart';

class WeeklyActionOption {
  final String type;
  final String text;
  final int targetDays;

  const WeeklyActionOption({
    required this.type,
    required this.text,
    required this.targetDays,
  });
}

const List<WeeklyActionOption> kWeeklyActionOptions = [
  WeeklyActionOption(type: 'log_breakfast', text: 'Log breakfast 5 out of 7 days', targetDays: 5),
  WeeklyActionOption(type: 'protein_target', text: 'Hit protein target 4 days next week', targetDays: 4),
  WeeklyActionOption(type: 'workouts_count', text: 'Complete 3 workout sessions next week', targetDays: 3),
  WeeklyActionOption(type: 'water_intake', text: 'Log daily water intake 6 days next week', targetDays: 6),
];

class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  bool _isLoading = true;
  WeeklyReportResult? _report;
  int _selectedActionIndex = 0;
  bool _isActionSaved = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString('weekly_action_type');
    if (savedType != null) {
      final idx = kWeeklyActionOptions.indexWhere((opt) => opt.type == savedType);
      if (idx != -1) {
        _selectedActionIndex = idx;
        _isActionSaved = true;
      }
    }

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

  Future<void> _saveSelectedAction() async {
    final prefs = await SharedPreferences.getInstance();
    final opt = kWeeklyActionOptions[_selectedActionIndex];
    await prefs.setString('weekly_action_type', opt.type);
    await prefs.setString('weekly_action_text', opt.text);
    await prefs.setInt('weekly_action_target', opt.targetDays);
    await prefs.setString('weekly_action_created_at', DateTime.now().toIso8601String());

    if (mounted) {
      setState(() {
        _isActionSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Committed action: "${opt.text}"! Progress will show on Dashboard.')),
      );
      ref.read(dashboardControllerProvider.notifier).loadStateData();
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
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag_rounded, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'PICK 1 ACTION FOR NEXT WEEK',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select a focus habit for the upcoming week to boost consistency:',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(kWeeklyActionOptions.length, (index) {
                            final option = kWeeklyActionOptions[index];
                            return RadioListTile<int>(
                              value: index,
                              groupValue: _selectedActionIndex,
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(option.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedActionIndex = val;
                                    _isActionSaved = false;
                                  });
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _saveSelectedAction,
                            icon: Icon(_isActionSaved ? Icons.check_circle_rounded : Icons.task_alt_rounded),
                            label: Text(_isActionSaved ? 'Action Saved!' : 'Commit to Action'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isActionSaved ? Colors.green : AppColors.primary,
                              minimumSize: const Size.fromHeight(44),
                            ),
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

