import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
import 'player_setup_presentation.dart';

/// Compact, collapsible player quick panel displaying frozen personal setup values and cues during execution.
class PlayerSetupCuesPanel extends ConsumerWidget {
  final String exerciseName;
  final String? stableId;
  final Map<String, dynamic>? frozenContext;

  const PlayerSetupCuesPanel({
    super.key,
    required this.exerciseName,
    this.stableId,
    this.frozenContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, dynamic> contextData = frozenContext ?? {};
    final presentation = PlayerSetupPresentation.fromContext(contextData);
    final hasContent = presentation.hasContent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cardBackground,
      child: ExpansionTile(
        initiallyExpanded: hasContent,
        leading: const Icon(
          Icons.settings_suggest_rounded,
          color: AppColors.primary,
        ),
        title: Text(
          'Your Setup & Cues',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 15,
          ),
        ),
        trailing: TextButton.icon(
          onPressed: () {
            final uri = Uri(
              path: '/exercise-preference-editor',
              queryParameters: {
                if (stableId != null) 'stableId': stableId,
                'rawName': exerciseName,
              },
            );
            context.push(uri.toString());
          },
          icon: const Icon(Icons.edit_note_rounded, size: 16),
          label: const Text('Edit'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasContent)
                  const Text(
                    'No setup values or cues saved for this exercise.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                if (presentation.note != null) ...[
                  Text(
                    presentation.note!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (presentation.setupValues.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: presentation.setupValues.map((value) {
                      return Chip(
                        labelStyle: const TextStyle(fontSize: 12),
                        label: Text('${value.label}: ${value.value}'),
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                if (presentation.cues.isNotEmpty) ...[
                  ...presentation.cues.map((cueText) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cueText,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                ],
                const Divider(),
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Edits apply to your next workout.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
