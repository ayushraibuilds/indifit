import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class HealthSyncHubScreen extends StatelessWidget {
  const HealthSyncHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Sync Hub'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Intro
            const Text(
              'HEALTH CONNECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect Apple Health or Google Health Connect to import your steps, active calories, and sleep metrics directly into IndiFit.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Connection Status Box
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Not Connected',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.sync_disabled_rounded,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 32),

                    // Zero Stats Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatWidget(Icons.directions_run_rounded, '0', 'Steps', AppColors.textMuted),
                        _buildStatWidget(Icons.local_fire_department_rounded, '0 kcal', 'Active Cals', AppColors.textMuted),
                        _buildStatWidget(Icons.bedtime_rounded, '0.0h', 'Sleep', AppColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Benefits
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.success, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Privacy & Security',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'When health syncing is enabled, all biometric metrics are processed entirely on-device and stored securely. Your sensitive health details never leave this phone.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Coming Soon Notice
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_clock, color: AppColors.warning, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Native Health Integration (Coming Soon)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orangeAccent),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Direct background syncing with Apple Health and Google Health Connect is currently under development for an upcoming release.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Connect Action Button (Disabled until native SDK integration)
            ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.sync_disabled_rounded),
              label: const Text('Connect Health Service (Coming Soon)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatWidget(IconData icon, String value, String label, Color iconCol) {
    return Column(
      children: [
        Icon(icon, color: iconCol, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
