import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import 'thali_presets.dart';

class ThaliPresetsBar extends StatelessWidget {
  final ValueChanged<ThaliPresetDefinition> onSelectPreset;

  const ThaliPresetsBar({super.key, required this.onSelectPreset});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'QUICK MEAL ARCHETYPES',
            style: TextStyle(
              color: colors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ThaliPresets.all.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = ThaliPresets.all[index];
              return ActionChip(
                key: Key('thali_preset_${preset.id}'),
                avatar: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: colors.action,
                ),
                label: Text(
                  preset.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () => onSelectPreset(preset),
              );
            },
          ),
        ),
      ],
    );
  }
}
