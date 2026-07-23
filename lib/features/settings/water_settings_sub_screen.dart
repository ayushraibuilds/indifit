import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'widgets/water_settings_section.dart';

class WaterSettingsSubScreen extends StatelessWidget {
  const WaterSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration & Water Goal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: WaterSettingsSection(),
      ),
    );
  }
}
