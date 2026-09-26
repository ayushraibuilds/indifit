import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class OnboardingPageContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final ScrollController? scrollController;
  final double? actionClearance;
  final ScrollPhysics? physics;

  static const double bottomActionClearance = 100.0;

  const OnboardingPageContainer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.scrollController,
    this.actionClearance,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space16,
        B05Layout.space20,
        B05Layout.space32,
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: physics ?? const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: B05Typography.pageTitle(context)),
            const SizedBox(height: B05Layout.space8),
            Text(subtitle, style: B05Typography.body(context)),
            const SizedBox(height: B05Layout.space20),
            child,
            SizedBox(height: actionClearance ?? bottomActionClearance),
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

class OnboardingGenderOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const OnboardingGenderOptionCard({
    super.key,
    required this.label,
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
      label: label,
      hint: 'Select $label.',
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
                  horizontal: B05Layout.space8,
                  vertical: B05Layout.space12,
                ),
                decoration: BoxDecoration(
                  color: selected ? colors.selected : colors.interactive,
                  borderRadius: B05Radii.largeRadius,
                  border: Border.all(
                    color: selected ? colors.action : colors.border,
                    width: selected ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      label,
                      style: B05Typography.label(context).copyWith(
                        color: selected ? colors.action : colors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
  final FocusNode? focusNode;
  final String label;
  final String suffix;
  final IconData icon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputAction textInputAction;
  final VoidCallback? onStepDown;
  final VoidCallback? onStepUp;
  final Widget? trailing;
  final Widget? subtitle;

  const OnboardingNumberInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    required this.suffix,
    required this.icon,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
    this.textInputAction = TextInputAction.done,
    this.onStepDown,
    this.onStepUp,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final hasError = errorText != null;
    final isValid = !hasError && controller.text.isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isLargeText = textScale > 1.3;
    final isCompact = screenWidth < 360;
    final stackControls = isLargeText || isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (focusNode != null && !focusNode!.hasFocus) {
              focusNode!.requestFocus();
            }
          },
          child: AnimatedContainer(
            duration: B05MotionPolicy.transitionDuration(context),
            padding: EdgeInsets.symmetric(
              horizontal: stackControls ? 10 : B05Layout.space16,
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
                  size: stackControls ? 20 : 24,
                  color: hasError
                      ? colors.danger.indicator
                      : colors.textSecondary,
                ),
                SizedBox(width: stackControls ? 8 : 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onEditingComplete: onEditingComplete,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: textInputAction,
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
                Text(suffix, style: B05Typography.label(context)),
                if (!stackControls && (onStepDown != null || onStepUp != null)) ...[
                  const SizedBox(width: B05Layout.space8),
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    label: 'Decrease $label',
                    onPressed: onStepDown,
                  ),
                  const SizedBox(width: B05Layout.space4),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    label: 'Increase $label',
                    onPressed: onStepUp,
                  ),
                ],
                if (!stackControls && trailing != null) ...[
                  const SizedBox(width: B05Layout.space8),
                  trailing!,
                ],
                if (isValid) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.success.indicator,
                    size: 18,
                  ),
                ] else if (hasError) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.danger.indicator,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (stackControls &&
            (onStepDown != null || onStepUp != null || trailing != null)) ...[
          const SizedBox(height: B05Layout.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onStepDown != null || onStepUp != null) ...[
                _StepperButton(
                  icon: Icons.remove_rounded,
                  label: 'Decrease $label',
                  onPressed: onStepDown,
                ),
                const SizedBox(width: B05Layout.space4),
                _StepperButton(
                  icon: Icons.add_rounded,
                  label: 'Increase $label',
                  onPressed: onStepUp,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: B05Layout.space8),
                trailing!,
              ],
            ],
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: B05Layout.space4),
          Padding(
            padding: const EdgeInsets.only(left: B05Layout.space12),
            child: subtitle!,
          ),
        ],
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.surfaceSubtle,
        borderRadius: B05Radii.smallRadius,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: B05Radii.smallRadius,
          onTap: onPressed,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: onPressed != null
                  ? colors.textPrimary
                  : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class HeightConverter {
  static (int feet, int inches) cmToFeetInches(double cm) {
    if (cm <= 0) return (0, 0);
    final totalInches = cm / 2.54;
    var feet = totalInches ~/ 12;
    var inches = (totalInches % 12).round();
    if (inches >= 12) {
      feet += 1;
      inches = 0;
    }
    return (feet, inches);
  }

  static double feetInchesToCm(int feet, int inches) {
    final totalInches = (feet * 12) + inches;
    return totalInches * 2.54;
  }

  static String formatFeetInches(double cm) {
    final (ft, inch) = cmToFeetInches(cm);
    return "$ft' $inch\"";
  }
}

class OnboardingHeightInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  const OnboardingHeightInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<OnboardingHeightInputField> createState() =>
      _OnboardingHeightInputFieldState();
}

enum _HeightUnit { cm, ftIn }

class _OnboardingHeightInputFieldState
    extends State<OnboardingHeightInputField> {
  _HeightUnit _unit = _HeightUnit.cm;
  late TextEditingController _ftController;
  late TextEditingController _inController;
  late FocusNode _ftFocusNode;
  late FocusNode _inFocusNode;

  @override
  void initState() {
    super.initState();
    _ftFocusNode = FocusNode();
    _inFocusNode = FocusNode();
    final cm = double.tryParse(widget.controller.text) ?? 170.0;
    final (ft, inch) = HeightConverter.cmToFeetInches(cm);
    _ftController = TextEditingController(text: ft > 0 ? '$ft' : '5');
    _inController = TextEditingController(text: inch >= 0 ? '$inch' : '7');
  }

  @override
  void dispose() {
    _ftController.dispose();
    _inController.dispose();
    _ftFocusNode.dispose();
    _inFocusNode.dispose();
    super.dispose();
  }

  void _syncFtInFromCm(double cm) {
    final (ft, inch) = HeightConverter.cmToFeetInches(cm);
    _ftController.text = '$ft';
    _inController.text = '$inch';
  }

  void _syncCmFromFtIn() {
    final ft = int.tryParse(_ftController.text) ?? 0;
    final inVal = int.tryParse(_inController.text) ?? 0;
    final cm = HeightConverter.feetInchesToCm(ft, inVal);
    final rounded = cm.round();
    widget.controller.text = '$rounded';
    widget.onChanged?.call('$rounded');
  }

  void _stepCm(int delta) {
    final current = double.tryParse(widget.controller.text) ?? 170.0;
    final next = (current + delta).clamp(80.0, 250.0).round();
    widget.controller.text = '$next';
    _syncFtInFromCm(next.toDouble());
    widget.onChanged?.call('$next');
    setState(() {});
  }

  void _stepInches(int delta) {
    final ft = int.tryParse(_ftController.text) ?? 5;
    var inVal = (int.tryParse(_inController.text) ?? 7) + delta;
    var newFt = ft;
    if (inVal >= 12) {
      newFt += inVal ~/ 12;
      inVal = inVal % 12;
    } else if (inVal < 0) {
      newFt -= 1;
      inVal = 11;
    }
    if (newFt < 2) newFt = 2;
    if (newFt > 8) newFt = 8;
    _ftController.text = '$newFt';
    _inController.text = '$inVal';
    _syncCmFromFtIn();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final cm = double.tryParse(widget.controller.text) ?? 170.0;

    final unitToggle = Material(
      color: colors.surfaceSubtle,
      borderRadius: B05Radii.smallRadius,
      child: InkWell(
        canRequestFocus: false,
        borderRadius: B05Radii.smallRadius,
        onTap: () {
          setState(() {
            if (_unit == _HeightUnit.cm) {
              _syncFtInFromCm(cm);
              _unit = _HeightUnit.ftIn;
            } else {
              _unit = _HeightUnit.cm;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            _unit == _HeightUnit.cm ? 'ft/in' : 'cm',
            style: B05Typography.caption(context).copyWith(
              color: colors.action,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    if (_unit == _HeightUnit.cm) {
      return OnboardingNumberInputField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        label: 'Height',
        suffix: 'cm',
        icon: Icons.height,
        errorText: widget.errorText,
        textInputAction: widget.textInputAction,
        subtitle: Text(
          '≈ ${HeightConverter.formatFeetInches(cm)}',
          style: B05Typography.caption(context).copyWith(
            color: colors.textSecondary,
          ),
        ),
        trailing: unitToggle,
        onStepDown: () => _stepCm(-1),
        onStepUp: () => _stepCm(1),
        onChanged: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null) _syncFtInFromCm(parsed);
          widget.onChanged?.call(val);
          setState(() {});
        },
      );
    }

    final hasError = widget.errorText != null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isLargeText = textScale > 1.3;
    final isCompact = screenWidth < 360;
    final stackControls = isLargeText || isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_ftFocusNode.hasFocus && !_inFocusNode.hasFocus) {
              _ftFocusNode.requestFocus();
            }
          },
          child: AnimatedContainer(
            duration: B05MotionPolicy.transitionDuration(context),
            padding: EdgeInsets.symmetric(
              horizontal: stackControls ? 10 : B05Layout.space16,
              vertical: B05Layout.space8,
            ),
            decoration: BoxDecoration(
              color: colors.inset,
              borderRadius: B05Radii.largeRadius,
              border: Border.all(
                color: hasError ? colors.danger.indicator : colors.border,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.height,
                  size: stackControls ? 20 : 24,
                  color: hasError
                      ? colors.danger.indicator
                      : colors.textSecondary,
                ),
                SizedBox(width: stackControls ? 8 : 16),
                SizedBox(
                  width: 36,
                  child: TextField(
                    controller: _ftController,
                    focusNode: _ftFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => _syncCmFromFtIn(),
                  ),
                ),
                Text('ft', style: B05Typography.label(context)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 36,
                  child: TextField(
                    controller: _inController,
                    focusNode: _inFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: widget.textInputAction,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => _syncCmFromFtIn(),
                  ),
                ),
                Text('in', style: B05Typography.label(context)),
                const Spacer(),
                if (!stackControls) ...[
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    label: 'Decrease height',
                    onPressed: () => _stepInches(-1),
                  ),
                  const SizedBox(width: B05Layout.space4),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    label: 'Increase height',
                    onPressed: () => _stepInches(1),
                  ),
                  const SizedBox(width: B05Layout.space8),
                ],
                unitToggle,
              ],
            ),
          ),
        ),
        if (stackControls) ...[
          const SizedBox(height: B05Layout.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                label: 'Decrease height',
                onPressed: () => _stepInches(-1),
              ),
              const SizedBox(width: B05Layout.space4),
              _StepperButton(
                icon: Icons.add_rounded,
                label: 'Increase height',
                onPressed: () => _stepInches(1),
              ),
            ],
          ),
        ],
        const SizedBox(height: B05Layout.space4),
        Padding(
          padding: const EdgeInsets.only(left: B05Layout.space12),
          child: Text(
            '≈ ${widget.controller.text} cm',
            style: B05Typography.caption(context).copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: B05Layout.space4),
          Padding(
            padding: const EdgeInsets.only(left: B05Layout.space12),
            child: Text(
              widget.errorText!,
              style: B05Typography.caption(context).copyWith(
                color: colors.danger.foreground,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
