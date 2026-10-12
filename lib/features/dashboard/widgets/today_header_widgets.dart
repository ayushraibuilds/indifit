import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/presentation/daypart_greeting.dart';
import '../../../core/presentation/today_onboarding_handoff.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import '../today_week_controller.dart';
import 'appearance_bottom_sheet.dart';
import 'today_helpers.dart';

/// Today's top block (T1): greeting and a quiet date on the left; the streak,
/// the theme toggle and settings in one row on the right. Every piece keeps
/// its size while data loads, so the page never moves when the streak lands.
class TodayHeader extends StatefulWidget {
  const TodayHeader({
    super.key,
    required this.userName,
    required this.streakCount,
    required this.selectedDate,
    required this.referenceNow,
    required this.onOpenSettings,
    this.streakLoaded = true,
    this.onDateChanged,
    this.onOpenAppearance,
  });

  final String userName;
  final int streakCount;
  final bool streakLoaded;
  final DateTime selectedDate;
  final DateTime? referenceNow;
  final VoidCallback onOpenSettings;

  /// The date line opens a date picker for days outside the week strip.
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onOpenAppearance;

  @override
  State<TodayHeader> createState() => TodayHeaderState();
}

class TodayHeaderState extends State<TodayHeader> with WidgetsBindingObserver {
  late DateTime _localNow;

  @override
  void initState() {
    super.initState();
    _localNow = widget.referenceNow ?? DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TodayHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceNow != oldWidget.referenceNow) {
      _localNow = widget.referenceNow ?? DateTime.now();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.referenceNow == null &&
        mounted) {
      setState(() => _localNow = DateTime.now());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userName.trim();
    final greeting = daypartGreeting(_localNow);
    final title = name.isEmpty || name == 'there'
        ? greeting
        : '$greeting, $name';
    final dateContext = todayDateContextLabel(widget.selectedDate, _localNow);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  label: title,
                  value: dateContext,
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: B05Typography.pageTitle(
                        context,
                      ).copyWith(fontSize: 22, letterSpacing: -0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                _TodayDateLine(
                  label: dateContext,
                  selectedDate: widget.selectedDate,
                  today: _localNow,
                  onDateChanged: widget.onDateChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: B05Layout.space4),
          TodayStreakChip(
            count: widget.streakCount,
            loaded: widget.streakLoaded,
          ),
          TodayHeaderIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            hint: 'Toggle between light and dark mode.',
            onPressed:
                widget.onOpenAppearance ??
                () => AppearanceBottomSheet.show(context),
            focusOrder: 1,
          ),
          TodayHeaderIconButton(
            icon: Icons.settings_outlined,
            label: 'Open settings',
            onPressed: widget.onOpenSettings,
            focusOrder: 2,
          ),
        ],
      ),
    );
  }
}

/// "Monday, 12 October" under the greeting. Tapping it opens a date picker
/// for days the week strip doesn't show; off today it offers a way back.
class _TodayDateLine extends StatelessWidget {
  const _TodayDateLine({
    required this.label,
    required this.selectedDate,
    required this.today,
    required this.onDateChanged,
  });

  final String label;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime>? onDateChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final todayDay = DateTime(today.year, today.month, today.day);
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final style = B05Typography.caption(
      context,
    ).copyWith(fontSize: 13, color: colors.textSecondary);
    final onChanged = onDateChanged;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (onChanged == null) return ExcludeSemantics(child: text);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: B05Layout.space4,
      children: [
        Semantics(
          button: true,
          label: 'Choose a date',
          value: DateFormat('EEEE, d MMMM y').format(selected),
          onTap: () => unawaited(_pick(context, selected, todayDay)),
          child: ExcludeSemantics(
            child: InkWell(
              key: const ValueKey('today-header-date'),
              borderRadius: B05Radii.chipRadius,
              onTap: () => unawaited(_pick(context, selected, todayDay)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: text),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (selected != todayDay)
          Semantics(
            button: true,
            label: 'Go to today',
            onTap: () => onChanged(todayDay),
            child: ExcludeSemantics(
              child: InkWell(
                key: const ValueKey('today-header-go-today'),
                borderRadius: B05Radii.chipRadius,
                onTap: () => onChanged(todayDay),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: B05Layout.space4,
                    vertical: 2,
                  ),
                  child: Text(
                    'Back to today',
                    style: style.copyWith(
                      color: colors.action,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    DateTime selected,
    DateTime todayDay,
  ) async {
    final firstDate = DateTime(2020);
    final lastDate = DateTime(todayDay.year + 1, todayDay.month, todayDay.day);
    final initialDate = selected.isBefore(firstDate)
        ? firstDate
        : selected.isAfter(lastDate)
        ? lastDate
        : selected;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      onDateChanged?.call(DateTime(picked.year, picked.month, picked.day));
    }
  }
}

/// A neutral 36 pt chip button inside a 48 pt touch target. Header icons stay
/// grey so green is left for actions and progress.
class TodayHeaderIconButton extends StatelessWidget {
  const TodayHeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.hint,
    this.focusOrder,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final double? focusOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final button = Semantics(
      container: true,
      button: true,
      label: label,
      hint: hint,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkResponse(
            onTap: onPressed,
            radius: B05Layout.minTouchTarget / 2,
            child: SizedBox.square(
              dimension: B05Layout.minTouchTarget,
              child: Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.surfaceSubtle,
                    shape: B05Radii.shape(B05Radii.chipRadius),
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      icon,
                      size: B05Layout.iconSmall,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return focusOrder == null
        ? button
        : FocusTraversalOrder(
            order: NumericFocusOrder(focusOrder!),
            child: button,
          );
  }
}

/// Days in a row with food or a workout logged, as a 3D flame and a number.
/// The chip keeps one width for 1–2 digits and is laid out (invisible) before
/// the streak read lands, so nothing next to it moves.
class TodayStreakChip extends StatelessWidget {
  const TodayStreakChip({super.key, required this.count, this.loaded = true});

  static const String fireAsset = 'assets/badges/streak_7.png';

  final int count;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final active = count > 0;
    final label = active
        ? '$count ${count == 1 ? 'day' : 'days'} logged in a row'
        : 'No days logged in a row yet';
    Widget flame = Image.asset(
      fireAsset,
      width: 22,
      height: 22,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(
        Icons.local_fire_department_rounded,
        size: 20,
        color: colors.warning.indicator,
      ),
    );
    if (!active) {
      flame = Opacity(
        opacity: 0.45,
        child: ColorFiltered(colorFilter: _greyscale, child: flame),
      );
    }
    final numberStyle = B05Typography.number(context, size: 14);
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surfaceSubtle,
          shape: B05Radii.shape(B05Radii.chipRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              flame,
              const SizedBox(width: B05Layout.space4),
              // A two-digit slot, so 5 → 12 doesn't change the chip's width.
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Opacity(opacity: 0, child: Text('00', style: numberStyle)),
                  Text(
                    '$count',
                    maxLines: 1,
                    style: numberStyle.copyWith(
                      color: active ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Visibility(
      visible: loaded,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        key: const ValueKey('today-streak-chip'),
        container: true,
        label: label,
        child: ExcludeSemantics(child: chip),
      ),
    );
  }

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// The last seven days with a mini calorie ring each, in place of the old
/// chevron date bar. Tap a day to show it.
class TodayWeekStrip extends ConsumerWidget {
  const TodayWeekStrip({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final end = todayWeekEnd(selected: selectedDate, today: today);
    final days = ref.watch(todayWeekDaysProvider(end)).valueOrNull;
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final todayDay = DateTime(today.year, today.month, today.day);
    return Semantics(
      container: true,
      label: 'Last seven days',
      child: Row(
        key: const ValueKey('today-week-strip'),
        children: [
          for (final date in todayWeekDates(end))
            Expanded(
              child: _TodayWeekDayCell(
                date: date,
                day: days?[_key(date)],
                selected: date == selected,
                isToday: date == todayDay,
                onTap: () => onDateChanged(date),
              ),
            ),
        ],
      ),
    );
  }

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _TodayWeekDayCell extends StatelessWidget {
  const _TodayWeekDayCell({
    required this.date,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final TodayWeekDay? day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final weekday = DateFormat('EEEEE').format(date);
    final spoken = isToday
        ? 'Today, ${DateFormat('EEEE d MMMM').format(date)}'
        : DateFormat('EEEE d MMMM').format(date);
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      value: _spokenValue(day),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: InkWell(
            key: ValueKey('today-week-day-${date.day}'),
            onTap: onTap,
            customBorder: B05Radii.shape(B05Radii.rowRadius),
            child: AnimatedContainer(
              duration: B05MotionPolicy.fastDuration,
              curve: B05MotionPolicy.standardCurve,
              constraints: const BoxConstraints(
                minHeight: B05Layout.minTouchTarget,
              ),
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 7),
              decoration: ShapeDecoration(
                color: selected ? colors.section : colors.section.withAlpha(0),
                shape: B05Radii.shape(
                  B05Radii.rowRadius,
                  side: BorderSide(
                    color: selected
                        ? colors.borderSubtle
                        : colors.borderSubtle.withAlpha(0),
                  ),
                ),
                shadows: selected && colors.sectionShadow.a > 0
                    ? [
                        BoxShadow(
                          color: colors.sectionShadow,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekday,
                    maxLines: 1,
                    style: B05Typography.caption(context).copyWith(
                      fontSize: 11,
                      height: 1.2,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox.square(
                    dimension: 24,
                    child: CustomPaint(
                      painter: TodayMiniRingPainter(
                        progress: day?.progress,
                        logged: day?.logged ?? false,
                        trackColor: colors.borderSubtle,
                        color: colors.success.indicator,
                        endColor: colors.protein.indicator,
                        loggedColor: colors.textSecondary.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}',
                    maxLines: 1,
                    style: B05Typography.number(context, size: 13).copyWith(
                      height: 1.2,
                      fontWeight: isToday || selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isToday ? colors.action : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _spokenValue(TodayWeekDay? day) {
    if (day == null) return '';
    if (!day.logged) return 'Nothing logged';
    final kcal = day.kcal;
    if (kcal == null) return 'Food logged';
    final logged = ConsumerNumberLabel.rounded(kcal);
    if (!day.hasTarget) return '$logged kcal logged';
    return '$logged of ${ConsumerNumberLabel.rounded(day.targetKcal!)} kcal';
  }
}

/// A 24 pt calorie ring for one day of the week strip. With no target, a day
/// with food logged shows a full quiet ring; an empty day shows the track.
class TodayMiniRingPainter extends CustomPainter {
  const TodayMiniRingPainter({
    required this.progress,
    required this.logged,
    required this.trackColor,
    required this.color,
    required this.endColor,
    required this.loggedColor,
  });

  static const double stroke = 3;

  final double? progress;
  final bool logged;
  final Color trackColor;
  final Color color;
  final Color endColor;
  final Color loggedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );
    final value = progress;
    if (value == null) {
      if (!logged) return;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = loggedColor,
      );
      return;
    }
    if (value <= 0) return;
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * value;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [color, endColor],
          transform: const GradientRotation(start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant TodayMiniRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.logged != logged ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.color != color ||
      oldDelegate.endColor != endColor ||
      oldDelegate.loggedColor != loggedColor;
}

/// A one-line notice on Today: a tinted icon, one sentence, one action and a
/// close button. Replaces the old setup and targets cards (207–243 pt).
class TodayBanner extends StatelessWidget {
  const TodayBanner({
    super.key,
    required this.icon,
    required this.tone,
    required this.message,
    required this.semanticLabel,
    required this.actionLabel,
    required this.actionHint,
    required this.onAction,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final IconData icon;
  final B05ColorRole tone;
  final String message;
  final String semanticLabel;
  final String actionLabel;
  final String actionHint;
  final VoidCallback onAction;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: B05Surface(
        tone: B05SurfaceTone.section,
        showBorder: true,
        radius: B05SurfaceRadius.large,
        padding: const EdgeInsets.fromLTRB(B05Layout.space12, 0, 0, 0),
        child: Row(
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: tone.container,
                shape: B05Radii.shape(B05Radii.chipRadius),
              ),
              child: SizedBox.square(
                dimension: 28,
                child: Icon(icon, size: 16, color: tone.indicator),
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  message,
                  maxLines: large ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: B05Typography.label(context).copyWith(fontSize: 14),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: actionLabel,
              hint: actionHint,
              onTap: onAction,
              child: ExcludeSemantics(
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.action,
                    minimumSize: const Size(B05Layout.minTouchTarget, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: B05Layout.space8,
                    ),
                    textStyle: B05Typography.label(
                      context,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  child: Text(actionLabel),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: dismissLabel,
              onTap: onDismiss,
              child: ExcludeSemantics(
                child: InkResponse(
                  onTap: onDismiss,
                  radius: 20,
                  child: SizedBox(
                    width: 40,
                    height: 48,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
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

/// After a skipped setup: one line that leads back into setup. Closing it
/// hides it; setup stays in Goal & targets and Personal details.
class TodayFinishSetupBanner extends ConsumerWidget {
  const TodayFinishSetupBanner({super.key, required this.onFinishSetup});

  final VoidCallback onFinishSetup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(todayFinishSetupPromptProvider);
    if (show.valueOrNull != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: B05Layout.space8),
      child: TodayBanner(
        key: const ValueKey('today_finish_setup'),
        icon: Icons.flag_outlined,
        tone: context.b05Colors.info,
        message: 'Finish setup for daily targets',
        semanticLabel:
            'Finish setting up. Get daily calorie and protein targets in about two minutes.',
        actionLabel: 'Finish',
        actionHint: 'Continue setup where you left off.',
        onAction: onFinishSetup,
        dismissLabel: 'Not now. Setup stays in Settings, Goal & targets.',
        onDismiss: () => unawaited(dismissTodayFinishSetup(ref)),
      ),
    );
  }
}

/// Right after setup: the new targets in one line, with a way to review them.
class TodayTargetsReadyBanner extends ConsumerWidget {
  const TodayTargetsReadyBanner({
    super.key,
    required this.presentation,
    required this.onReviewTargets,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onReviewTargets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(todayOnboardingHandoffPendingProvider);
    if (pending.valueOrNull != true) return const SizedBox.shrink();

    final calories = presentation.calories?.targetValue;
    final protein = presentation.macros
        .where((metric) => metric.nutrientId == 'protein')
        .firstOrNull
        ?.targetValue;
    final kcal = calories == null
        ? null
        : '${ConsumerNumberLabel.rounded(calories)} kcal';
    final spoken = [
      ?kcal,
      if (protein != null) '${ConsumerNumberLabel.rounded(protein)} g protein',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: B05Layout.space8),
      child: TodayBanner(
        key: const ValueKey('today_targets_ready'),
        icon: Icons.track_changes_rounded,
        tone: context.b05Colors.success,
        message: kcal == null
            ? 'Your targets are ready'
            : 'Targets ready · $kcal',
        semanticLabel: spoken.isEmpty
            ? 'Your starting targets are ready.'
            : 'Your starting targets are ready. $spoken.',
        actionLabel: 'Review',
        actionHint: 'Open your saved daily nutrition targets.',
        onAction: () => unawaited(_acknowledgeAndRun(ref, context)),
        dismissLabel: 'Dismiss this starting-target message.',
        onDismiss: () => unawaited(acknowledgeTodayOnboardingHandoff(ref)),
      ),
    );
  }

  Future<void> _acknowledgeAndRun(WidgetRef ref, BuildContext context) async {
    try {
      await acknowledgeTodayOnboardingHandoff(ref);
    } finally {
      if (context.mounted) onReviewTargets();
    }
  }
}

/// One quiet row at the bottom of Today when no workout is planned: either
/// there is no training plan yet, or the plan has nothing on today.
class TodayTrainingRow extends StatelessWidget {
  const TodayTrainingRow({
    super.key,
    required this.hasPlan,
    required this.onTap,
  });

  final bool hasPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final title = hasPlan ? 'Rest day' : 'Choose a plan';
    final detail = hasPlan ? 'Nothing planned today' : 'No training plan yet';
    return Semantics(
      container: true,
      button: true,
      label: '$title. $detail',
      hint: hasPlan ? 'Opens your workout plan.' : 'Opens the plan library.',
      onTap: onTap,
      child: ExcludeSemantics(
        child: B05Surface(
          key: const ValueKey('today-training-row'),
          tone: B05SurfaceTone.section,
          padding: EdgeInsets.zero,
          radius: B05SurfaceRadius.large,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: B05Radii.shape(B05Radii.rowRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: B05Layout.space12,
                  vertical: B05Layout.space12,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.surfaceSubtle,
                        shape: B05Radii.shape(B05Radii.chipRadius),
                      ),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Icon(
                          hasPlan
                              ? Icons.self_improvement_rounded
                              : Icons.fitness_center_rounded,
                          size: B05Layout.iconSmall,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: B05Typography.label(
                              context,
                            ).copyWith(fontSize: 15),
                          ),
                          Text(detail, style: B05Typography.caption(context)),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
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

/// Whether Today shows [TodayTrainingRow]: on today's date, once the plan
/// read has landed, when nothing else on the page speaks for training.
bool todayShowsTrainingRow({
  required TodayDateRelation relation,
  required TodayWorkoutPresentation workout,
  required bool nextUpVisible,
  required bool workoutModuleVisible,
}) =>
    relation == TodayDateRelation.today &&
    workout.state == TodayPresentationState.empty &&
    !nextUpVisible &&
    !workoutModuleVisible;
