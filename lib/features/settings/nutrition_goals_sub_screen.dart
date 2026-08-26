import 'package:flutter/material.dart';

import 'nutrition_targets_hub_screen.dart';

/// Compatibility name for callers that still reference the former B04 route.
///
/// Goal, date-scoped targets, and optional coaching now have one Settings
/// destination. The canonical authorities remain owned by the hub's existing
/// repositories; this wrapper creates no second editor or state store.
@Deprecated('Use NutritionTargetsHubScreen.')
class NutritionGoalsSubScreen extends StatelessWidget {
  const NutritionGoalsSubScreen({super.key});

  @override
  Widget build(BuildContext context) => const NutritionTargetsHubScreen();
}
