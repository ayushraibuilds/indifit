import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/theme_provider.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';

/// Interactive bottom sheet for switching between System, Light, and Dark themes.
class AppearanceBottomSheet extends ConsumerWidget {
  const AppearanceBottomSheet({super.key});

  /// Presents the appearance bottom sheet using the standard [showIndiFitBottomSheet].
  static Future<void> show(BuildContext context) {
    return showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Appearance options',
      builder: (_) => const AppearanceBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final colors = context.b05Colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space8,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(B05Layout.space8),
                decoration: BoxDecoration(
                  color: colors.action.withValues(alpha: 0.12),
                  borderRadius: B05Radii.mediumRadius,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: colors.action,
                  size: B05Layout.iconMedium,
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: B05Typography.title(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how IndiFit looks on your device',
                      style: B05Typography.caption(context).copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close appearance sheet',
                hint: 'Closes the appearance options.',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          _ThemeOptionCard(
            mode: ThemeMode.system,
            title: 'System default',
            subtitle: 'Automatically matches your device settings',
            icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == ThemeMode.system,
            onSelect: () => _selectMode(ref, ThemeMode.system),
            preview: const _SystemThemePreview(),
          ),
          const SizedBox(height: B05Layout.space8),
          _ThemeOptionCard(
            mode: ThemeMode.light,
            title: 'Light mode',
            subtitle: 'Clean contrast for daytime and bright spaces',
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
            onSelect: () => _selectMode(ref, ThemeMode.light),
            preview: const _LightModePreview(),
          ),
          const SizedBox(height: B05Layout.space8),
          _ThemeOptionCard(
            mode: ThemeMode.dark,
            title: 'Dark mode',
            subtitle: 'Low-glare palette for dimly lit spaces',
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
            onSelect: () => _selectMode(ref, ThemeMode.dark),
            preview: const _DarkModePreview(),
          ),
        ],
      ),
    );
  }

  void _selectMode(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onSelect,
    required this.preview,
  });

  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelect;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Semantics(
      selected: isSelected,
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: B05Radii.largeRadius,
          child: AnimatedContainer(
            duration: B05MotionPolicy.transitionDuration(context),
            padding: const EdgeInsets.all(B05Layout.space12),
            decoration: BoxDecoration(
              color: isSelected ? colors.selected : colors.surfaceSubtle,
              borderRadius: B05Radii.largeRadius,
              border: Border.all(
                color: isSelected ? colors.action : colors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                preview,
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected ? colors.action : colors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: B05Typography.label(context).copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? colors.action : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: B05Typography.caption(context).copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: B05Layout.space8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? colors.action : colors.textDisabled,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini mock preview showing split system theme (light on left, dark on right).
class _SystemThemePreview extends StatelessWidget {
  const _SystemThemePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: B05Radii.mediumRadius,
        border: Border.all(color: const Color(0xFF94A3B8), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(2),
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
}

/// Mini mock preview showing light theme palette.
class _LightModePreview extends StatelessWidget {
  const _LightModePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: B05Radii.mediumRadius,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.centerLeft,
            child: Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini mock preview showing dark theme palette.
class _DarkModePreview extends StatelessWidget {
  const _DarkModePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: B05Radii.mediumRadius,
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.centerLeft,
            child: Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
