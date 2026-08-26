import 'package:flutter/material.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';
import 'widgets/water_settings_section.dart';

class WaterSettingsSubScreen extends StatelessWidget {
  const WaterSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration & Water Goal'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(B05Layout.space16),
        child: WaterSettingsSection(),
      ),
    );
  }
}
