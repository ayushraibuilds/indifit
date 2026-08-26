import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/user_profile_provider.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../settings_controller.dart';

class WaterSettingsSection extends ConsumerStatefulWidget {
  const WaterSettingsSection({super.key});

  @override
  ConsumerState<WaterSettingsSection> createState() =>
      _WaterSettingsSectionState();
}

class _WaterSettingsSectionState extends ConsumerState<WaterSettingsSection> {
  late TextEditingController _waterGoalController;
  late TextEditingController _glassSizeController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(settingsControllerProvider);
    _waterGoalController = TextEditingController(
      text: state.waterGoal.toString(),
    );
    _glassSizeController = TextEditingController(
      text: state.glassSize.toString(),
    );
  }

  @override
  void dispose() {
    _waterGoalController.dispose();
    _glassSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(B05Layout.space8),
              decoration: BoxDecoration(
                color: colors.interactive,
                borderRadius: b05Radius(B05SurfaceRadius.small),
              ),
              child: Icon(
                Icons.local_drink_rounded,
                color: colors.info.indicator,
                size: B05Layout.iconMedium,
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hydration Settings',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customize daily water targets and serving volume',
                    style: B05Typography.caption(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space16),
        B05Surface(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Water Goal',
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Number of glasses per day (1 - 40 glasses)',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: B05Layout.space16),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _waterGoalController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0 && parsed <= 40) {
                      controller.updateWaterGoal(parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space12),
        B05Surface(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serving (Glass) Size',
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Custom volume size per glass of water logged (ml)',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: B05Layout.space16),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _glassSizeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 50 && parsed <= 1000) {
                      controller.updateGlassSize(parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space12),
        B05Surface(
          tone: B05SurfaceTone.inset,
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: colors.info.indicator,
                size: B05Layout.iconMedium,
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final userProfile = ref.watch(userProfileProvider);
                    final double weight = userProfile.currentWeight;
                    final int recMl = (weight * 35).round();
                    final int glassMl =
                        int.tryParse(_glassSizeController.text) ?? 250;
                    final int recGlasses =
                        (recMl / (glassMl > 0 ? glassMl : 250)).round();
                    return Text(
                      'Recommended: ~$recMl ml (~$recGlasses glasses) based on ${weight.toStringAsFixed(1)} kg bodyweight (35ml/kg).',
                      style: B05Typography.caption(context),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
