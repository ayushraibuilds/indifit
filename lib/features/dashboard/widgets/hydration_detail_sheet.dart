import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../data/models/hydration_models.dart';
import '../../../data/repositories/hydration_repository.dart';
import '../../settings/settings_controller.dart';
import '../today_surface_controller.dart';
import 'hydration_fluid_fill.dart';
import 'today_helpers.dart';

final hydrationDailyProvider = FutureProvider.autoDispose
    .family<HydrationDailyReadModel, String>((ref, localDate) async {
      ref.watch(todayHydrationRevisionProvider);
      final repo = ref.watch(hydrationRepositoryProvider);
      return repo.getDailyHydration(localDate);
    });

class HydrationDetailSheet extends ConsumerStatefulWidget {
  const HydrationDetailSheet({
    super.key,
    required this.selectedDate,
    this.initialData,
  });

  final DateTime selectedDate;
  final HydrationDailyReadModel? initialData;

  static Future<void> show(
    BuildContext context,
    DateTime selectedDate, {
    HydrationDailyReadModel? initialData,
  }) {
    return showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Hydration details',
      builder: (context) => HydrationDetailSheet(
        selectedDate: selectedDate,
        initialData: initialData,
      ),
    );
  }

  @override
  ConsumerState<HydrationDetailSheet> createState() =>
      _HydrationDetailSheetState();
}

class _HydrationDetailSheetState extends ConsumerState<HydrationDetailSheet> {
  late final TextEditingController _amountController;
  String _selectedContainer = 'glass';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '250');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String get _localDate =>
      HydrationRepository.formatLocalDate(widget.selectedDate);

  Future<void> _quickAdd(int amountMl, String containerType) async {
    try {
      final repo = ref.read(hydrationRepositoryProvider);
      await repo.logIntake(
        localDate: _localDate,
        amountMl: amountMl,
        source: 'quickAdd',
        containerType: containerType,
      );
      ref.read(todayHydrationRevisionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $amountMl ml water'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log hydration. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _logCustom() async {
    final text = _amountController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount <= 0) return;

    try {
      final repo = ref.read(hydrationRepositoryProvider);
      await repo.logIntake(
        localDate: _localDate,
        amountMl: amount,
        source: 'manual',
        containerType: _selectedContainer,
      );
      ref.read(todayHydrationRevisionProvider.notifier).state++;
      _amountController.text = '250';
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $amount ml water'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log hydration. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(HydrationIntakeEntry entry) async {
    try {
      final repo = ref.read(hydrationRepositoryProvider);
      await repo.deleteIntake(
        localDate: _localDate,
        entryId: entry.id,
      );
      ref.read(todayHydrationRevisionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${entry.amountMl} ml entry'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove entry. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _adjustGoal(int currentGoal, int delta) async {
    try {
      final newGoal = (currentGoal + delta).clamp(500, 10000);
      await ref
          .read(settingsControllerProvider.notifier)
          .setHydrationDailyGoalMl(newGoal);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update hydration goal.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final dailyAsync = ref.watch(hydrationDailyProvider(_localDate));
    final settings = ref.watch(settingsControllerProvider);
    final daily = dailyAsync.valueOrNull ??
        widget.initialData ??
        HydrationDailyReadModel(
          localDate: _localDate,
          totalMl: 0,
          goalMl: HydrationRepository.defaultDailyGoalMl,
        );

    final totalFormatted = daily.totalMl.toString();
    final goalFormatted = daily.goalMl.toString();
    final percent = daily.progressPercent;
    final ratio = daily.clampedProgressRatio;

    final progressText = daily.isGoalMet
        ? 'Goal met! ($percent%)'
        : '${daily.remainingMl} ml remaining ($percent%)';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space16,
        vertical: B05Layout.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop_rounded,
                color: colors.info.indicator,
                size: 28,
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HYDRATION', style: todayEyebrow(context)),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      DateFormat('EEEE, MMM d').format(widget.selectedDate),
                      style: B05Typography.title(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close hydration details',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),

          // Daily Progress Card
          B05Surface(
                    tone: B05SurfaceTone.inset,
                    padding: const EdgeInsets.all(B05Layout.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$totalFormatted / $goalFormatted ml',
                                style: B05Typography.title(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: B05Layout.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: B05Layout.space8,
                                vertical: B05Layout.space4,
                              ),
                              decoration: BoxDecoration(
                                color: daily.isGoalMet
                                    ? colors.success.container
                                    : colors.info.container,
                                borderRadius: B05Radii.smallRadius,
                              ),
                              child: Text(
                                '$percent%',
                                style: B05Typography.caption(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: daily.isGoalMet
                                      ? colors.success.indicator
                                      : colors.info.indicator,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: B05Layout.space4),
                        Text(
                          progressText,
                          style: B05Typography.caption(context).copyWith(
                            color: daily.isGoalMet
                                ? colors.success.indicator
                                : colors.textSecondary,
                            fontWeight: daily.isGoalMet
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: B05Layout.space12),
                        B05MotionContent(
                          animatedChild: HydrationFluidFillIndicator(
                            progress: daily.rawProgressRatio,
                            isGoalMet: daily.isGoalMet,
                            height: 36,
                            borderRadius: B05Radii.smallRadius,
                          ),
                          reducedMotionChild: ClipRRect(
                            borderRadius: B05Radii.smallRadius,
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 10,
                              backgroundColor:
                                  colors.info.container.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                daily.isGoalMet
                                    ? colors.success.indicator
                                    : colors.info.indicator,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: B05Layout.space16),

                  // Quick Add Buttons
                  Text('QUICK ADD', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  Wrap(
                    spacing: B05Layout.space8,
                    runSpacing: B05Layout.space8,
                    children: [
                      B05ActionButton(
                        label: '+250 ml',
                        icon: Icons.local_cafe_outlined,
                        hint: 'Quick log 250 millilitres of water',
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: () => _quickAdd(250, 'glass'),
                      ),
                      B05ActionButton(
                        label: '+500 ml',
                        icon: Icons.water_drop_outlined,
                        hint: 'Quick log 500 millilitres of water',
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: () => _quickAdd(500, 'bottle'),
                      ),
                      B05ActionButton(
                        label: '+750 ml',
                        icon: Icons.water_drop_rounded,
                        hint: 'Quick log 750 millilitres of water',
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: () => _quickAdd(750, 'bottle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: B05Layout.space16),

                  // Custom Intake Form
                  Text('CUSTOM INTAKE', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  B05Surface(
                    tone: B05SurfaceTone.inset,
                    padding: const EdgeInsets.all(B05Layout.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: B05Layout.space8,
                          runSpacing: B05Layout.space8,
                          children: [
                            ChoiceChip(
                              label: const Text('Glass'),
                              selected: _selectedContainer == 'glass',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedContainer = 'glass');
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Bottle'),
                              selected: _selectedContainer == 'bottle',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedContainer = 'bottle');
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Custom'),
                              selected: _selectedContainer == 'custom',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedContainer = 'custom');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: B05Layout.space8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 280;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount (ml)',
                                      suffixText: 'ml',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: B05Layout.space8),
                                  B05ActionButton(
                                    label: 'Log Water',
                                    icon: Icons.add,
                                    hint: 'Log custom water amount',
                                    emphasis: B05ActionEmphasis.primary,
                                    onPressed: _logCustom,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount (ml)',
                                      suffixText: 'ml',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: B05Layout.space12),
                                B05ActionButton(
                                  label: 'Log Water',
                                  icon: Icons.add,
                                  hint: 'Log custom water amount',
                                  emphasis: B05ActionEmphasis.primary,
                                  onPressed: _logCustom,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: B05Layout.space16),

                  // Intake Timeline
                  Text('LOGGED INTAKES', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  if (daily.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: B05Layout.space12,
                      ),
                      child: Text(
                        'No water logged for this day yet.',
                        style: B05Typography.caption(context),
                      ),
                    )
                  else
                    Column(
                      children: daily.entries.map((entry) {
                        final timeFormatted = entry.isSummary
                            ? 'Daily summary'
                            : DateFormat.jm()
                                .format(entry.loggedAtUtc.toLocal());
                        final icon = switch (entry.containerType) {
                          'glass' => Icons.local_cafe_outlined,
                          'bottle' => Icons.water_drop_outlined,
                          _ => Icons.opacity_rounded,
                        };

                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: B05Layout.space8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: B05Radii.mediumRadius,
                            border: Border.all(color: colors.border),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(icon, color: colors.info.indicator),
                            title: Text(
                              '${entry.amountMl} ml',
                              style: B05Typography.body(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$timeFormatted · ${entry.source}',
                              style: B05Typography.caption(context),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              tooltip: 'Delete entry',
                              color: colors.danger.indicator,
                              onPressed: () => _deleteEntry(entry),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: B05Layout.space16),

                  // Daily Goal Adjustment
                  Text('DAILY GOAL', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  B05Surface(
                    tone: B05SurfaceTone.inset,
                    padding: const EdgeInsets.symmetric(
                      horizontal: B05Layout.space16,
                      vertical: B05Layout.space12,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 260;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${daily.goalMl} ml',
                                style: B05Typography.title(context),
                              ),
                              const SizedBox(height: B05Layout.space8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    tooltip: 'Decrease goal by 250 ml',
                                    onPressed: () => _adjustGoal(daily.goalMl, -250),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    tooltip: 'Increase goal by 250 ml',
                                    onPressed: () => _adjustGoal(daily.goalMl, 250),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${daily.goalMl} ml',
                                style: B05Typography.title(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: 'Decrease goal by 250 ml',
                                  onPressed: () => _adjustGoal(daily.goalMl, -250),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Increase goal by 250 ml',
                                  onPressed: () => _adjustGoal(daily.goalMl, 250),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: B05Layout.space16),

                  // Water Reminder Settings
                  Text('REMINDERS', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  B05Surface(
                    tone: B05SurfaceTone.inset,
                    padding: const EdgeInsets.symmetric(
                      horizontal: B05Layout.space12,
                      vertical: B05Layout.space8,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Water reminder',
                            style: B05Typography.body(context),
                          ),
                          subtitle: Text(
                            'Daily reminder to stay hydrated',
                            style: B05Typography.caption(context),
                          ),
                          value: settings.remindWater,
                          onChanged: (val) async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .toggleReminder(
                                  NotificationService.prefRemindWater,
                                  val,
                                );
                          },
                        ),
                        if (settings.remindWater) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Reminder time',
                              style: B05Typography.body(context),
                            ),
                            subtitle: Text(
                              TimeOfDay(
                                hour: settings.waterReminderHour,
                                minute: settings.waterReminderMinute,
                              ).format(context),
                              style: B05Typography.caption(context),
                            ),
                            trailing: TextButton(
                              child: const Text('Change'),
                              onPressed: () async {
                                final initial = TimeOfDay(
                                  hour: settings.waterReminderHour,
                                  minute: settings.waterReminderMinute,
                                );
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: initial,
                                );
                                if (picked != null) {
                                  await ref
                                      .read(settingsControllerProvider.notifier)
                                      .updateWaterReminderSchedule(
                                        hour: picked.hour,
                                        minute: picked.minute,
                                      );
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: B05Layout.space24),
        ],
      ),
    );
  }
}
