import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'widgets/notification_settings_section.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Reminders'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: NotificationSettingsSection(),
      ),
    );
  }
}
