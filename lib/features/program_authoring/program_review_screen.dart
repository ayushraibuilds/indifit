import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_repository.dart';

/// Screen for reviewing program graph, selecting start local date and timezone, and publishing/activating.
class ProgramReviewScreen extends ConsumerStatefulWidget {
  final String programVersionId;

  const ProgramReviewScreen({super.key, required this.programVersionId});

  @override
  ConsumerState<ProgramReviewScreen> createState() =>
      _ProgramReviewScreenState();
}

class _ProgramReviewScreenState extends ConsumerState<ProgramReviewScreen> {
  final LocalScheduleDateService _dateService = LocalScheduleDateService();
  late String _selectedDate;
  late String _selectedTimezone;

  bool _isLoading = true;
  ProgramVersionDetail? _versionDetail;
  String? _programName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateService.todayLocalDate();
    _selectedTimezone = _dateService.deviceTimezoneId();
    _loadVersionDetail();
  }

  Future<void> _loadVersionDetail() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(programRepositoryProvider);
      final detail = await repo.getProgramVersionDetail(
        widget.programVersionId,
      );
      if (detail == null) {
        setState(() => _errorMessage = 'Program version not found.');
        return;
      }

      final prog = await repo.getProgram(detail.programId);
      setState(() {
        _versionDetail = detail;
        _programName = prog?.name ?? 'Training Program';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _activateProgram() async {
    final detail = _versionDetail;
    if (detail == null) return;

    setState(() => _isLoading = true);
    try {
      final coordinator = ref.read(programActivationCoordinatorProvider);
      final commandId = 'cmd-act-${DateTime.now().millisecondsSinceEpoch}';

      final result = await coordinator.activate(
        ActivateProgramVersionCommand(
          programVersionId: detail.id,
          commandId: commandId,
          activationLocalDate: _selectedDate,
          timezoneId: _selectedTimezone,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Program activated successfully! (${result.occurrences.length} scheduled workouts created)',
            ),
          ),
        );
        context.go('/calendar');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = _dateService.formatLocalDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _versionDetail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review & Activate',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : detail == null
          ? const SizedBox()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _programName ?? 'Training Program',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: GoogleFonts.outfit().fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version ${detail.versionNumber} • ${detail.blocks.length} Blocks • ${detail.weeks.length} Weeks',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Activation Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: const Text('Start Local Date'),
                    subtitle: Text(_selectedDate),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    tileColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: const Text('Home Timezone'),
                    subtitle: Text(_selectedTimezone),
                    trailing: const Icon(Icons.public_rounded),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Program Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...detail.blocks.map((b) {
                    return ExpansionTile(
                      title: Text(
                        b.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: detail.weeks
                          .where((w) => w.programBlockId == b.id)
                          .map((w) {
                            return ListTile(
                              title: Text(
                                'Week ${w.programWeekOrdinal + 1}${w.isDeload ? " (Deload)" : ""}',
                              ),
                              subtitle: Text(
                                '${detail.sessionTemplates.where((st) => st.programWeekId == w.id).length} Workouts Scheduled',
                              ),
                            );
                          })
                          .toList(),
                    );
                  }),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _activateProgram,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Publish & Activate Program'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        textStyle: TextStyle(
                          fontFamily: GoogleFonts.outfit().fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
