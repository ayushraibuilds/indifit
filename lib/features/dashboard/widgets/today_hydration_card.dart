import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/hydration_models.dart';
import '../../../data/repositories/hydration_repository.dart';
import '../today_surface_controller.dart';
import 'today_helpers.dart';
import 'today_module_widgets.dart';

class TodayHydrationCard extends ConsumerWidget {
  const TodayHydrationCard({
    super.key,
    required this.hydrationRead,
    required this.selectedDate,
    this.onTapDetail,
    this.onRetry,
  });

  final TodayDomainRead<HydrationDailyReadModel> hydrationRead;
  final DateTime selectedDate;
  final VoidCallback? onTapDetail;
  final VoidCallback? onRetry;

  Future<void> _quickAdd(
    BuildContext context,
    WidgetRef ref,
    int amountMl,
    String containerType,
  ) async {
    final localDate = HydrationRepository.formatLocalDate(selectedDate);
    final repo = ref.read(hydrationRepositoryProvider);
    await repo.logIntake(
      localDate: localDate,
      amountMl: amountMl,
      source: 'quickAdd',
      containerType: containerType,
    );
    ref.read(todayHydrationRevisionProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $amountMl ml water'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hydrationRead.isAvailable) {
      return TodayUnavailableModule(
        title: 'Hydration unavailable',
        detail: 'Could not load hydration data right now.',
        onRetry: onRetry ?? () {},
      );
    }

    final model =
        hydrationRead.value ??
        HydrationDailyReadModel(
          localDate: HydrationRepository.formatLocalDate(selectedDate),
          totalMl: 0,
          goalMl: HydrationRepository.defaultDailyGoalMl,
        );

    final colors = context.b05Colors;
    final totalFormatted = model.totalMl.toString();
    final goalFormatted = model.goalMl.toString();
    final percent = model.progressPercent;
    final ratio = model.clampedProgressRatio;

    final progressText =
        model.isGoalMet
            ? 'Goal met! ($percent%)'
            : '${model.remainingMl} ml remaining ($percent%)';

    return Semantics(
      container: true,
      label:
          'Hydration, $totalFormatted of $goalFormatted ml logged, $progressText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: B05Radii.largeRadius,
          onTap: onTapDetail,
          child: B05Surface(
            tone: B05SurfaceTone.inset,
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      color: colors.info.indicator,
                      size: 24,
                    ),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HYDRATION', style: todayEyebrow(context)),
                          const SizedBox(height: B05Layout.space4),
                          Text(
                            '$totalFormatted / $goalFormatted ml',
                            style: B05Typography.title(context),
                          ),
                          const SizedBox(height: B05Layout.space4),
                          Text(
                            progressText,
                            style: B05Typography.caption(context).copyWith(
                              color:
                                  model.isGoalMet
                                      ? colors.success.indicator
                                      : colors.textSecondary,
                              fontWeight:
                                  model.isGoalMet
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onTapDetail != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: B05Layout.space12),
                ClipRRect(
                  borderRadius: B05Radii.smallRadius,
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: colors.info.container.withAlpha(80),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      model.isGoalMet
                          ? colors.success.indicator
                          : colors.info.indicator,
                    ),
                  ),
                ),
                const SizedBox(height: B05Layout.space12),
                Wrap(
                  spacing: B05Layout.space8,
                  runSpacing: B05Layout.space8,
                  children: [
                    B05ActionButton(
                      label: '+250 ml',
                      icon: Icons.local_cafe_outlined,
                      hint: 'Log 250 millilitres of water',
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: () => _quickAdd(context, ref, 250, 'glass'),
                    ),
                    B05ActionButton(
                      label: '+500 ml',
                      icon: Icons.water_drop_outlined,
                      hint: 'Log 500 millilitres of water',
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: () => _quickAdd(context, ref, 500, 'bottle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
