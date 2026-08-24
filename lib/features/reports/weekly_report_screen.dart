import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/progress_statistics_repository.dart';
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
  WeeklyActionOption(
    type: 'log_breakfast',
    text: 'Log breakfast 5 out of 7 days',
    targetDays: 5,
  ),
  WeeklyActionOption(
    type: 'protein_target',
    text: 'Hit protein target 4 days next week',
    targetDays: 4,
  ),
  WeeklyActionOption(
    type: 'workouts_count',
    text: 'Complete 3 workout sessions next week',
    targetDays: 3,
  ),
];

class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  WeeklyMetrics? _metrics;
  WeeklyReportResult? _report;
  int _selectedActionIndex = 0;
  bool _isActionSaved = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString('weekly_action_type');
      if (savedType != null) {
        final idx = kWeeklyActionOptions.indexWhere(
          (opt) => opt.type == savedType,
        );
        if (idx != -1) {
          _selectedActionIndex = idx;
          _isActionSaved = true;
        }
      }

      final statsRepo = ref.read(progressStatisticsRepositoryProvider);
      final metrics = await statsRepo.getWeeklyMetrics();
      final service = ref.read(weeklyReportServiceProvider);
      final report = await service.generateReportFromMetrics(metrics);

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Your weekly report could not be loaded. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSelectedAction() async {
    final prefs = await SharedPreferences.getInstance();
    final opt = kWeeklyActionOptions[_selectedActionIndex];
    await prefs.setString('weekly_action_type', opt.type);
    await prefs.setString('weekly_action_text', opt.text);
    await prefs.setInt('weekly_action_target', opt.targetDays);
    await prefs.setString(
      'weekly_action_created_at',
      DateTime.now().toIso8601String(),
    );

    if (mounted) {
      setState(() {
        _isActionSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Committed action: "${opt.text}"! Progress will show on Dashboard.',
          ),
        ),
      );
      await ref.read(dashboardControllerProvider.notifier).loadStateData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly AI Report'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Analyzing your weekly progress...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load weekly report',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    final metrics = _metrics;

    if (report.isInsufficientData) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                report.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                report.summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Start Logging Now'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range Header
          if (metrics != null) ...[
            Text(
              'WEEK OF ${_formatDate(metrics.startDate).toUpperCase()} – ${_formatDate(metrics.endDate).toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Offline fallback banner badge
          if (report.isFallback) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local Report: ${report.fallbackReason ?? "Generated from local data"}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Adherence & Metrics Breakdown Card
          if (metrics != null) ...[
            _buildAdherenceBreakdownCard(metrics),
            const SizedBox(height: 16),
          ],

          // AI Narrative Card
          Card(
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.headline,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Coaching Tip Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: AppColors.achievementGold,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI COACHING TIP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.achievementGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.coachingTip,
                    style: const TextStyle(height: 1.4, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Habit Focus Selection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'PICK 1 ACTION FOR NEXT WEEK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a focus habit for the upcoming week to boost consistency:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(kWeeklyActionOptions.length, (index) {
                    final option = kWeeklyActionOptions[index];
                    return RadioListTile<int>(
                      value: index,
                      // ignore: deprecated_member_use
                      groupValue: _selectedActionIndex,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.text,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // ignore: deprecated_member_use
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
                    icon: Icon(
                      _isActionSaved
                          ? Icons.check_circle_rounded
                          : Icons.task_alt_rounded,
                    ),
                    label: Text(
                      _isActionSaved ? 'Action Saved!' : 'Commit to Action',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isActionSaved
                          ? Colors.green
                          : AppColors.primary,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceBreakdownCard(WeeklyMetrics m) {
    final b = m.adherenceBreakdown;
    final overallPct = (b.overallScore * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'WEEKLY ADHERENCE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '$overallPct%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getAdherenceColor(b.overallScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricProgressRow(
              label: 'Calorie Target',
              valueText:
                  '${m.totalCaloriesLogged} / ${m.totalCaloriesGoal} kcal (${m.nutritionDaysLogged}/7 days)',
              score: b.calorieScore,
            ),
            const SizedBox(height: 8),
            _buildMetricProgressRow(
              label: 'Protein Target',
              valueText:
                  '${m.totalProteinG.toStringAsFixed(0)} / ${m.totalProteinGoal.toStringAsFixed(0)} g',
              score: b.proteinScore,
            ),
            const SizedBox(height: 8),
            _buildMetricProgressRow(
              label: 'Workouts',
              valueText:
                  '${m.completedWorkoutsCount} / ${m.plannedWorkoutsCount > 0 ? m.plannedWorkoutsCount : "–"} completed (${m.totalVolumeKg.toStringAsFixed(0)} kg, ${m.prsCount} PRs)',
              score: b.workoutScore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricProgressRow({
    required String label,
    required String valueText,
    required double? score,
  }) {
    final pct = score != null ? (score * 100).round() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              pct != null ? '$pct%' : 'No Data',
              style: TextStyle(
                fontSize: 11,
                color: score != null
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          valueText,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score ?? 0.0,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              score != null ? _getAdherenceColor(score) : AppColors.border,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Color _getAdherenceColor(double score) {
    if (score >= 0.8) return AppColors.success;
    if (score >= 0.5) return Colors.amber;
    return Colors.redAccent;
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }
}
