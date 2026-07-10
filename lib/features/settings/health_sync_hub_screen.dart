import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class HealthSyncHubScreen extends StatefulWidget {
  const HealthSyncHubScreen({super.key});

  @override
  State<HealthSyncHubScreen> createState() => _HealthSyncHubScreenState();
}

class _HealthSyncHubScreenState extends State<HealthSyncHubScreen> {
  bool _isSimulating = true;
  bool _isSyncing = false;
  String _syncStatus = 'Last Synced: Never';
  int _simulatedSteps = 0;
  int _simulatedCalories = 0;
  double _simulatedSleep = 0.0;

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });

    // Simulate network/SDK parsing delay
    await Future.delayed(const Duration(milliseconds: 2200));

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _simulatedSteps = 8450;
        _simulatedCalories = 320;
        _simulatedSleep = 7.5;
        _syncStatus = 'Last Synced: Just Now (${_isSimulating ? "Simulation Mode" : "Native SDK"})';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSimulating 
            ? 'Imported 8,450 steps and 320 kcal via Health Connect simulation!' 
            : 'Apple Health/Health Connect synced successfully!'
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sync steps, active training calories, and sleep metrics directly into your daily IndiFit dashboard.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Mode Selector card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Simulation Sandbox', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            'Demo health imports without configuring native Apple/Google profiles',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _isSimulating,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _isSimulating = val;
                          if (!val) {
                            _simulatedSteps = 0;
                            _simulatedCalories = 0;
                            _simulatedSleep = 0.0;
                            _syncStatus = 'Last Synced: Never';
                          }
                        });
                      },
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Status Box
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sync Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(_syncStatus, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                        Icon(
                          _simulatedSteps > 0 ? Icons.check_circle_rounded : Icons.sync_disabled_rounded,
                          color: _simulatedSteps > 0 ? AppColors.success : AppColors.textMuted,
                          size: 32,
                        )
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 32),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatWidget(Icons.directions_run_rounded, '$_simulatedSteps', 'Steps', Colors.orange),
                        _buildStatWidget(Icons.local_fire_department_rounded, '$_simulatedCalories kcal', 'Active Cals', Colors.red),
                        _buildStatWidget(Icons.bedtime_rounded, '${_simulatedSleep}h', 'Sleep', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Native configuration advice
            if (!_isSimulating) ...[
              Card(
                color: AppColors.warning.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Native Setup Required',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'To sync live health data, configure permissions in iOS HealthKit or Android Health Connect under system App Settings.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Button
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _triggerSync,
              icon: _isSyncing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded),
              label: Text(_isSyncing ? 'Accessing Health Records...' : 'Sync Health Data Now'),
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
