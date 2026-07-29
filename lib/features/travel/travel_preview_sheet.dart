import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/travel_repository.dart';
import 'travel_controller.dart';

/// Bottom sheet displayed after a travel preview completes. The user sees
/// exactly which occurrences will use the travel equipment profile and which
/// exercises are incompatible, then confirms or dismisses.
///
/// Per B01-PD02: "Before applying travel mode, the user must preview affected
/// occurrences and any unavailable exercises or proposed substitutions."
class TravelPreviewSheet extends ConsumerStatefulWidget {
  final TravelPreviewResult preview;
  final String profileName;

  const TravelPreviewSheet({
    required this.preview,
    required this.profileName,
    super.key,
  });

  @override
  ConsumerState<TravelPreviewSheet> createState() => _TravelPreviewSheetState();
}

class _TravelPreviewSheetState extends ConsumerState<TravelPreviewSheet> {
  final _noteController = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref
          .read(travelControllerProvider.notifier)
          .applyTravel(
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static String _displayDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final totalOccurrences = preview.affectedOccurrences.length;
    final incompatibleCount = preview.occurrenceIncompatibleExercises.values
        .where((list) => list.isNotEmpty)
        .length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.preview_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Travel Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.outfit().fontFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Summary chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      Icons.date_range_rounded,
                      '${_displayDate(preview.startLocalDate)} — ${_displayDate(preview.endLocalDate)}',
                    ),
                    _buildChip(
                      Icons.public_rounded,
                      preview.timezoneId.replaceAll('_', ' '),
                    ),
                    _buildChip(
                      Icons.fitness_center_rounded,
                      widget.profileName,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    _buildStatBadge(
                      '$totalOccurrences',
                      'workout${totalOccurrences == 1 ? '' : 's'} affected',
                      AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    if (incompatibleCount > 0)
                      _buildStatBadge(
                        '$incompatibleCount',
                        'with incompatible exercises',
                        AppColors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                const Divider(color: AppColors.border),
              ],
            ),
          ),

          // Occurrence list
          Flexible(
            child: totalOccurrences == 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 24,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'No scheduled workouts in this date range.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: totalOccurrences,
                    itemBuilder: (context, index) {
                      final occurrence = preview.affectedOccurrences[index];
                      final incompatible =
                          preview.occurrenceIncompatibleExercises[occurrence
                              .id] ??
                          [];
                      return _buildOccurrenceItem(occurrence, incompatible);
                    },
                  ),
          ),

          // Invariant text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.infoBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.infoBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dates, order, ordinals, and deload weeks remain unchanged.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Note field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.notes_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _applying ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _applying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _applying ? 'Applying Travel Mode…' : 'Apply Travel Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccurrenceItem(
    ScheduledSessionOccurrence occurrence,
    List<String> incompatible,
  ) {
    final hasIncompatible = incompatible.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasIncompatible
            ? AppColors.warning.withValues(alpha: 0.06)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasIncompatible
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasIncompatible
                    ? Icons.warning_amber_rounded
                    : Icons.fitness_center_rounded,
                size: 18,
                color: hasIncompatible ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayDate(occurrence.effectiveLocalDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Semantics(
                label: 'Status ${occurrence.status}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    occurrence.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasIncompatible) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 26),
                Expanded(
                  child: Text(
                    'Incompatible: ${incompatible.join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
