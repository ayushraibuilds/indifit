import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/health_service.dart';

class HealthSyncHubScreen extends ConsumerStatefulWidget {
  const HealthSyncHubScreen({super.key});

  @override
  ConsumerState<HealthSyncHubScreen> createState() => _HealthSyncHubScreenState();
}

class _HealthSyncHubScreenState extends ConsumerState<HealthSyncHubScreen> {
  bool _loading = false;
  HealthDataSummary _data = const HealthDataSummary();
  String? _lastSyncTimeStr;
  bool _autoSyncOnOpen = true;
  List<Map<String, dynamic>> _outdoorActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final service = ref.read(healthServiceProvider);
    final summary = await service.fetchTodayHealthData();
    final lastSyncIso = await service.getLastSyncTime();
    final activities = await service.importOutdoorActivities();
    final prefs = await SharedPreferences.getInstance();
    final autoSync = prefs.getBool('auto_sync_health_on_open') ?? true;

    String? formattedSync;
    if (lastSyncIso != null) {
      try {
        final dt = DateTime.parse(lastSyncIso);
        formattedSync = 'Synced ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _data = summary;
        _lastSyncTimeStr = formattedSync;
        _autoSyncOnOpen = autoSync;
        _outdoorActivities = activities;
        _loading = false;
      });
    }
  }

  Future<void> _toggleAutoSync(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_health_on_open', val);
    setState(() {
      _autoSyncOnOpen = val;
    });
  }

  Future<void> _handleConnect() async {
    setState(() => _loading = true);
    final granted = await ref.read(healthServiceProvider).requestPermissions();
    if (granted) {
      await _fetchData();
    } else {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health permissions were denied or unavailable on this device.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Sync Hub'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _fetchData,
          ),
        ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connection Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _data.isConnected ? 'Connected' : 'Not Connected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _data.isConnected ? AppColors.success : AppColors.textSecondary,
                                  ),
                                ),
                                if (_lastSyncTimeStr != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${_lastSyncTimeStr!}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        Icon(
                          _data.isConnected ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                          color: _data.isConnected ? AppColors.success : AppColors.textMuted,
                          size: 32,
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 32),

                    // Stats Display
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatWidget(
                            Icons.directions_run_rounded,
                            '${_data.steps}',
                            'Steps',
                            _data.isConnected ? AppColors.primary : AppColors.textMuted,
                          ),
                          _buildStatWidget(
                            Icons.local_fire_department_rounded,
                            '${_data.activeCalories.toInt()} kcal',
                            'Active Cals',
                            _data.isConnected ? Colors.orangeAccent : AppColors.textMuted,
                          ),
                          _buildStatWidget(
                            Icons.bedtime_rounded,
                            '${_data.sleepHours.toStringAsFixed(1)}h',
                            'Sleep',
                            _data.isConnected ? Colors.purpleAccent : AppColors.textMuted,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Auto Sync Toggle
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.sync_lock_rounded, color: AppColors.primary),
                title: const Text('Auto-sync on app open', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Automatically fetch step and active cals data whenever IndiFit is launched', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: _autoSyncOnOpen,
                activeColor: AppColors.primary,
                onChanged: _toggleAutoSync,
              ),
            ),

            if (_outdoorActivities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.nordic_walking_rounded, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Imported Outdoor Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._outdoorActivities.map((act) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.border,
                          child: Icon(Icons.directions_run_rounded, size: 16, color: AppColors.primary),
                        ),
                        title: Text(act['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${act['durationMinutes']} mins • ${act['calories']} kcal'),
                        trailing: Text(
                          '${(act['date'] as DateTime).month}/${(act['date'] as DateTime).day}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],

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
            const SizedBox(height: 24),

            // Connect / Sync Action Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _handleConnect,
              icon: Icon(_data.isConnected ? Icons.sync_rounded : Icons.health_and_safety_rounded),
              label: Text(_data.isConnected ? 'Re-Sync Health Data' : 'Connect Health Service'),
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

