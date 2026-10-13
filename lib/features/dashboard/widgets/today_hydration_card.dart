import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/motion/indifit_motion.dart';
import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/presentation/ui_art.dart';
import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/art_chip.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models/hydration_models.dart';
import '../../../data/repositories/hydration_repository.dart';
import '../today_surface_controller.dart';
import 'hydration_detail_sheet.dart';
import 'hydration_glass.dart';
import 'today_helpers.dart';
import 'today_module_widgets.dart';

const Duration _fillDuration = Duration(milliseconds: 500);

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
    final currentTotal = hydrationRead.value?.totalMl ?? 0;
    if (currentTotal + amountMl > HydrationRepository.maxDailyHydrationMl) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily hydration safety limit (10L) reached.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      final localDate = HydrationRepository.formatLocalDate(selectedDate);
      final repo = ref.read(hydrationRepositoryProvider);
      await repo.logIntake(
        localDate: localDate,
        amountMl: amountMl,
        source: 'quickAdd',
        containerType: containerType,
      );
      ref.read(todayHydrationRevisionProvider.notifier).state++;
      // No snackbar (T3): the ml counts up and the fill settles. A tick for
      // the log, and a success when this glass meets the goal.
      final goal =
          hydrationRead.value?.goalMl ?? HydrationRepository.defaultDailyGoalMl;
      if (currentTotal < goal && currentTotal + amountMl >= goal) {
        unawaited(IndiFitHaptics.success());
      } else {
        unawaited(IndiFitHaptics.selection());
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not log hydration right now.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hydrationRead.isLoading) {
      return const SkeletonCard(height: 120.0);
    }

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
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final totalFormatted = ConsumerNumberLabel.rounded(
      model.totalMl.toDouble(),
    );
    final goalFormatted = ConsumerNumberLabel.rounded(model.goalMl.toDouble());

    // Remaining or met, not remaining plus a percentage.
    final progressText = model.isGoalMet
        ? 'Goal met!'
        : '${ConsumerNumberLabel.rounded(model.remainingMl.toDouble())} ml '
              'remaining';

    return Semantics(
      container: true,
      label:
          'Hydration, $totalFormatted of $goalFormatted ml logged, $progressText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: B05Radii.largeRadius,
          onTap:
              onTapDetail ??
              () => HydrationDetailSheet.show(
                context,
                selectedDate,
                initialData: model,
              ),
          // Section tone: inset is lighter than a section in dark, which made
          // water look more raised than Meals. Inset is for wells in a card.
          child: B05Surface(
            lift: true,
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    HydrationGlass(
                      progress: model.rawProgressRatio,
                      isGoalMet: model.isGoalMet,
                      fillDuration: _fillDuration,
                      // A narrower glass leaves the figures room at large text.
                      width: largeText ? 36 : 52,
                      height: largeText ? 60 : 76,
                    ),
                    SizedBox(
                      width: largeText ? B05Layout.space12 : B05Layout.space16,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ArtChip(
                                color: colors.info,
                                art: UiArt.water,
                                fallbackIcon: Icons.water_drop_rounded,
                                size: 28,
                              ),
                              const SizedBox(width: B05Layout.space8),
                              Flexible(
                                child: Text(
                                  'Hydration',
                                  style: todayEyebrow(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: B05Layout.space8),
                          IndiFitCountUp(
                            value: model.totalMl.toDouble(),
                            duration: _fillDuration,
                            builder: (context, ml) => Text(
                              '${ConsumerNumberLabel.rounded(ml)} / '
                              '$goalFormatted ml',
                              style: B05Typography.title(context).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: B05Layout.space4),
                          Text(
                            progressText,
                            style: B05Typography.caption(context).copyWith(
                              color: model.isGoalMet
                                  ? colors.success.indicator
                                  : colors.textSecondary,
                              fontWeight: model.isGoalMet
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ],
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
