import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
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
    final colors = context.b05Colors;
    final Map<String, dynamic> contextData = frozenContext ?? {};
    final presentation = PlayerSetupPresentation.fromContext(contextData);
    final hasContent = presentation.hasContent;
    final compactAction = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    void editSetup() {
      final uri = Uri(
        path: '/exercise-preference-editor',
        queryParameters: {
          if (stableId != null) 'stableId': stableId,
          'rawName': exerciseName,
        },
      );
      context.push(uri.toString());
    }

    return B05Surface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space16,
          vertical: B05Layout.space4,
        ),
        childrenPadding: const EdgeInsets.only(
          left: B05Layout.space16,
          right: B05Layout.space16,
          bottom: B05Layout.space12,
        ),
        collapsedIconColor: colors.textSecondary,
        iconColor: colors.action,
        initiallyExpanded: hasContent,
        leading: Icon(Icons.settings_suggest_rounded, color: colors.action),
        title: Text('Your Setup & Cues', style: B05Typography.label(context)),
        trailing: compactAction
            ? B05IconAction(
                icon: Icons.edit_note_rounded,
                label: 'Edit setup and cues',
                onPressed: editSetup,
              )
            : TextButton.icon(
                onPressed: editSetup,
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: B05Layout.iconSmall,
                ),
                label: const Text('Edit'),
              ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasContent)
                Text(
                  'No setup values or cues saved for this exercise.',
                  style: B05Typography.caption(context),
                ),
              if (presentation.note != null) ...[
                Text(
                  presentation.note!,
                  style: B05Typography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: B05Layout.space8),
              ],
              if (presentation.setupValues.isNotEmpty) ...[
                Wrap(
                  spacing: B05Layout.space8,
                  runSpacing: B05Layout.space8,
                  children: presentation.setupValues.map((value) {
                    return Chip(
                      labelStyle: B05Typography.caption(context),
                      label: Text('${value.label}: ${value.value}'),
                      backgroundColor: colors.selected,
                    );
                  }).toList(),
                ),
                const SizedBox(height: B05Layout.space8),
              ],
              if (presentation.cues.isNotEmpty) ...[
                ...presentation.cues.map((cueText) {
                  return Padding(
                    padding: const EdgeInsets.only(top: B05Layout.space4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: B05Layout.iconSmall,
                          color: colors.action,
                        ),
                        const SizedBox(width: B05Layout.space8),
                        Expanded(
                          child: Text(
                            cueText,
                            style: B05Typography.caption(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: B05Layout.space8),
              ],
              Divider(color: colors.border),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: B05Layout.iconSmall,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: B05Layout.space4),
                  Expanded(
                    child: Text(
                      'Edits apply to your next workout.',
                      style: B05Typography.caption(
                        context,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
