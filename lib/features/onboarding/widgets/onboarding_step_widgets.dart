import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class OnboardingPageContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const OnboardingPageContainer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space16,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: B05Typography.pageTitle(context)),
            const SizedBox(height: B05Layout.space8),
            Text(subtitle, style: B05Typography.body(context)),
            const SizedBox(height: B05Layout.space20),
            child,
          ],
        ),
      ),
    );
  }
}

class OnboardingSelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const OnboardingSelectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: title,
      hint: 'Select $title.',
      onTap: onTap,
      child: B05TouchTarget(
        child: B05FocusRing(
          radius: B05SurfaceRadius.large,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              borderRadius: B05Radii.largeRadius,
              child: AnimatedContainer(
                duration: B05MotionPolicy.transitionDuration(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: B05Layout.space16,
                  vertical: B05Layout.space12,
                ),
                decoration: BoxDecoration(
                  color: selected ? colors.selected : colors.interactive,
                  borderRadius: B05Radii.largeRadius,
                  border: selected
                      ? Border.all(color: colors.action, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(B05Layout.space8),
                      decoration: BoxDecoration(
                        color: selected ? colors.selected : colors.inset,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: selected ? colors.action : colors.textSecondary,
                        size: B05Layout.iconMedium,
                      ),
                    ),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: B05Typography.label(context)),
                          if (subtitle != null) ...[
                            const SizedBox(height: B05Layout.space4),
                            Text(subtitle!, style: B05Typography.body(context)),
                          ],
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.action,
                        size: B05Layout.iconLarge,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingNumberInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  const OnboardingNumberInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final hasError = errorText != null;
    final isValid = !hasError && controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: B05MotionPolicy.transitionDuration(context),
          padding: const EdgeInsets.symmetric(
            horizontal: B05Layout.space16,
            vertical: B05Layout.space8,
          ),
          decoration: BoxDecoration(
            color: colors.inset,
            borderRadius: B05Radii.largeRadius,
            border: Border.all(
              color: hasError
                  ? colors.danger.indicator
                  : (isValid ? colors.success.indicator : colors.border),
              width: hasError || isValid ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: hasError
                    ? colors.danger.indicator
                    : colors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onEditingComplete: onEditingComplete,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: B05Typography.body(context),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isValid)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success.indicator,
                  size: 18,
                )
              else if (hasError)
                Icon(
                  Icons.error_outline_rounded,
                  color: colors.danger.indicator,
                  size: 18,
                )
              else
                Text(suffix, style: B05Typography.label(context)),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: B05Layout.space4),
          Padding(
            padding: const EdgeInsets.only(left: B05Layout.space12),
            child: Text(
              errorText!,
              style: B05Typography.caption(
                context,
              ).copyWith(color: colors.danger.foreground),
            ),
          ),
        ],
      ],
    );
  }
}
