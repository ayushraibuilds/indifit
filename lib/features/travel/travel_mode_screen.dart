import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import 'travel_controller.dart';
import 'travel_preview_sheet.dart';

/// A curated subset of IANA timezones for the travel destination picker.
/// The full tz database is large, so the picker starts with common travel
/// zones and also offers an explicit IANA-zone text field for other locations.
const _kCommonTimezones = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'America/Toronto',
  'America/Vancouver',
  'America/Mexico_City',
  'America/Sao_Paulo',
  'America/Argentina/Buenos_Aires',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Rome',
  'Europe/Madrid',
  'Europe/Amsterdam',
  'Europe/Zurich',
  'Europe/Stockholm',
  'Europe/Athens',
  'Europe/Moscow',
  'Europe/Istanbul',
  'Asia/Dubai',
  'Asia/Kolkata',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Australia/Sydney',
  'Australia/Melbourne',
  'Pacific/Auckland',
];

/// Travel Mode MVP screen — B01-PD02 compliant.
///
/// Two display states:
///  1. **Idle** — shows the setup form (date range, timezone, equipment profile).
///  2. **Active travel** — shows the active context summary with end/cancel actions.
///
/// All mutations are delegated to [TravelController]. No template rewrite,
/// date shift, volume transform, or hidden week consumption occurs here.
class TravelModeScreen extends ConsumerStatefulWidget {
  const TravelModeScreen({super.key});

  @override
  ConsumerState<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends ConsumerState<TravelModeScreen> {
  DateTimeRange? _selectedRange;
  String _selectedTimezone = _kCommonTimezones[0];
  String? _selectedProfileId;
  List<EquipmentProfile> _profiles = [];
  bool _loadingProfiles = true;
  final _otherTimezoneController = TextEditingController();

  String get _effectiveTimezone {
    final custom = _otherTimezoneController.text.trim();
    return custom.isEmpty ? _selectedTimezone : custom;
  }

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _otherTimezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loadingProfiles = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final profiles = await repo.getActiveProfiles();
      final defaultProfileId = await repo.getDefaultProfileId();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        if (profiles.isNotEmpty && _selectedProfileId == null) {
          _selectedProfileId =
              profiles.any((profile) => profile.id == defaultProfileId)
              ? defaultProfileId
              : profiles.first.id;
        }
        _loadingProfiles = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProfiles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment profiles could not be loaded. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      helpText: 'Select travel dates',
      saveText: 'CONFIRM',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedRange = picked);
    }
  }

  Future<void> _previewTravel() async {
    if (_selectedRange == null || _selectedProfileId == null) return;

    final startDate = _formatDate(_selectedRange!.start);
    final endDate = _formatDate(_selectedRange!.end);

    await ref
        .read(travelControllerProvider.notifier)
        .previewTravel(
          startLocalDate: startDate,
          endLocalDate: endDate,
          timezoneId: _effectiveTimezone,
          equipmentProfileId: _selectedProfileId!,
        );

    if (!mounted) return;

    final state = ref.read(travelControllerProvider);
    if (state.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      return;
    }

    if (state.previewResult != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TravelPreviewSheet(
          preview: state.previewResult!,
          profileName:
              _profiles
                  .where((p) => p.id == _selectedProfileId)
                  .map((p) => p.name)
                  .firstOrNull ??
              'Unknown',
        ),
      );
    }
  }

  Future<void> _endTravel(TravelUiState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'End Travel Mode?',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        content: const Text(
          'Your normal equipment profile will become active again. '
          'Original program structure is unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('End Travel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final active = state.activeTravelContext;
      if (active != null) {
        try {
          await ref.read(travelControllerProvider.notifier).endActiveTravel();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to end travel mode. Try again.'),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _cancelTravel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Cancel Travel Mode?',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        content: const Text(
          'This will cancel the active travel context and restore your '
          'normal equipment profile. The original plan is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Travel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(travelControllerProvider.notifier).cancelActiveTravel();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to cancel travel mode. Try again.'),
            ),
          );
        }
      }
    }
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  // ─── Build methods ──────────────────────────────────────────────────

  Widget _buildSetupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.infoBlue.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.infoBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: AppColors.infoBlue,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Your Travel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: GoogleFonts.outfit().fontFamily,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Temporarily use a different equipment profile '
                        'during your trip. Dates, order, ordinals, and '
                        'deload weeks remain unchanged.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Date range
          _buildSectionLabel('Travel Dates'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedRange != null
                          ? ConsumerDateLabel.range(
                              _formatDate(_selectedRange!.start),
                              _formatDate(_selectedRange!.end),
                            )
                          : 'Select date range',
                      style: TextStyle(
                        color: _selectedRange != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Timezone
          _buildSectionLabel('Destination Timezone'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTimezone,
              decoration: const InputDecoration(
                border: InputBorder.none,
                icon: Icon(
                  Icons.public_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              isExpanded: true,
              items: _kCommonTimezones
                  .map(
                    (tz) => DropdownMenuItem(
                      value: tz,
                      child: Text(
                        tz.replaceAll('_', ' '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedTimezone = value);
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherTimezoneController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Other IANA timezone (optional)',
              hintText: 'For example, Africa/Nairobi',
              helperText:
                  'Overrides the list above and is checked before preview.',
            ),
          ),
          const SizedBox(height: 24),

          // Equipment profile
          _buildSectionLabel('Equipment Profile'),
          const SizedBox(height: 8),
          if (_loadingProfiles)
            const Center(child: CircularProgressIndicator())
          else if (_profiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No active equipment profiles. Create one in '
                      'Equipment Profiles first.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedProfileId,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                isExpanded: true,
                items: _profiles
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedProfileId = value);
                  }
                },
              ),
            ),

          const SizedBox(height: 36),

          // Preview button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _selectedRange != null && _selectedProfileId != null
                  ? _previewTravel
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.preview_rounded),
              label: Text(
                'Preview Affected Workouts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: GoogleFonts.outfit().fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTravelSummary(TravelUiState state) {
    final travel = state.activeTravelContext!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.success.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TRAVEL ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                              letterSpacing: 1.2,
                              fontFamily: GoogleFonts.outfit().fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.flight_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.date_range_rounded,
                  'Dates',
                  ConsumerDateLabel.range(
                    travel.startLocalDate,
                    travel.endLocalDate,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.public_rounded,
                  'Timezone',
                  travel.timezoneId.replaceAll('_', ' '),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.fitness_center_rounded,
                  'Equipment',
                  _profiles
                          .where((p) => p.id == travel.equipmentProfileId)
                          .map((p) => p.name)
                          .firstOrNull ??
                      travel.equipmentProfileId,
                ),
                if (travel.note != null && travel.note!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.notes_rounded, 'Note', travel.note!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invariant reminder
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.infoBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.infoBlue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your program dates, order, ordinals, and deload weeks '
                    'remain unchanged. When travel ends, your normal '
                    'equipment profile becomes active again.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // End travel button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _endTravel(state),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.home_rounded),
              label: Text(
                'End Travel — Restore Normal Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: GoogleFonts.outfit().fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cancel travel button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _cancelTravel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                'Cancel Travel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: GoogleFonts.outfit().fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
        fontFamily: GoogleFonts.outfit().fontFamily,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(travelControllerProvider);
    final hasActiveTravel = state.activeTravelContext != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          hasActiveTravel ? 'Travel Mode' : 'Plan Travel',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (hasActiveTravel)
            Semantics(
              label: 'Travel mode active',
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasActiveTravel
          ? _buildActiveTravelSummary(state)
          : _buildSetupForm(),
    );
  }
}
