import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/health_provider.dart';
import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/health_service.dart';

class HealthSyncHubScreen extends ConsumerStatefulWidget {
  const HealthSyncHubScreen({super.key});

  @override
  ConsumerState<HealthSyncHubScreen> createState() =>
      _HealthSyncHubScreenState();
}

class _HealthSyncHubScreenState extends ConsumerState<HealthSyncHubScreen> {
  bool _loading = false;
  String? _lastSyncTimeStr;
  bool _autoSyncOnOpen = true;
  List<Map<String, dynamic>> _outdoorActivities = [];
  Map<HealthCategory, bool> _categoryStates = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    await ref.read(healthStateProvider.notifier).refresh();
    await _loadSupportingData();
  }

  Future<void> _loadSupportingData() async {
    final service = ref.read(healthServiceProvider);
    final lastSyncIso = await service.getLastSyncTime();
    final db = ref.read(databaseProvider);
    final activities = await service.importOutdoorActivities(db);
    final catStates = await service.getAllCategoryStates();
    final prefs = await SharedPreferences.getInstance();
    final autoSync = prefs.getBool('auto_sync_health_on_open') ?? true;

    String? formattedSync;
    if (lastSyncIso != null) {
      try {
        final dt = DateTime.parse(lastSyncIso);
        formattedSync =
            'Synced ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        AppLogger.warning('Failed to parse lastSyncIso: $e');
      }
    }

    if (mounted) {
      setState(() {
        _lastSyncTimeStr = formattedSync;
        _autoSyncOnOpen = autoSync;
        _outdoorActivities = activities;
        _categoryStates = catStates;
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

  Future<void> _toggleCategory(HealthCategory category, bool val) async {
    final service = ref.read(healthServiceProvider);
    await service.setCategoryState(category, val);
    if (val) {
      await service.requestCategoryPermissions(category);
    }
    setState(() {
      _categoryStates[category] = val;
    });
    await _fetchData();
  }

  Future<void> _handleConnect() async {
    setState(() => _loading = true);
    await ref.read(healthStateProvider.notifier).connectAndRefresh();
    final healthState = ref.read(healthStateProvider);
    if (healthState.status == HealthStatus.denied ||
        healthState.status == HealthStatus.error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            healthState.errorMessage ??
                'Health permissions were denied or unavailable on this device.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    await _loadSupportingData();
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthStateProvider);
    final data = healthState.summary;
    final isLoading =
        _loading ||
        healthState.status == HealthStatus.loading ||
        healthState.status == HealthStatus.refreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Sync Hub'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isLoading ? null : _fetchData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  data.isConnected
                                      ? 'Connected'
                                      : 'Not Connected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: data.isConnected
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                if (_lastSyncTimeStr != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${_lastSyncTimeStr!}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        Icon(
                          data.isConnected
                              ? Icons.sync_rounded
                              : Icons.sync_disabled_rounded,
                          color: data.isConnected
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 32,
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatWidget(
                            Icons.directions_run_rounded,
                            '${data.steps}',
                            'Steps',
                            data.isConnected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          _buildStatWidget(
                            Icons.local_fire_department_rounded,
                            '${data.activeCalories.toInt()} kcal',
                            'Active Cals',
                            data.isConnected
                                ? Colors.orangeAccent
                                : AppColors.textMuted,
                          ),
                          _buildStatWidget(
                            Icons.bedtime_rounded,
                            '${data.sleepHours.toStringAsFixed(1)}h',
                            'Sleep',
                            data.isConnected
                                ? Colors.purpleAccent
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Granular Category Permission Toggles
            const Text(
              'GRANULAR PERMISSION CATEGORIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Steps Import (Read)'),
                    subtitle: const Text('Import daily step count from native Health app'),
                    value: _categoryStates[HealthCategory.steps] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.steps, val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Active Energy Burned (Read)'),
                    subtitle: const Text('Import daily active calories burned'),
                    value: _categoryStates[HealthCategory.activeEnergy] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.activeEnergy, val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Sleep Duration (Read)'),
                    subtitle: const Text('Import sleep sessions without sharing workouts'),
                    value: _categoryStates[HealthCategory.sleep] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.sleep, val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Workout Import (Read)'),
                    subtitle: const Text('Import outdoor walks & runs from Health'),
                    value: _categoryStates[HealthCategory.workoutImport] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.workoutImport, val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Workout Export (Write)'),
                    subtitle: const Text('Export completed IndiFit workouts to Health'),
                    value: _categoryStates[HealthCategory.workoutExport] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.workoutExport, val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Body Weight Export (Write)'),
                    subtitle: const Text('Sync logged weight measurements to Health'),
                    value: _categoryStates[HealthCategory.weightExport] ?? true,
                    onChanged: (val) => _toggleCategory(HealthCategory.weightExport, val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Auto Sync Toggle
            Card(
              child: SwitchListTile(
                secondary: const Icon(
                  Icons.sync_lock_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Auto-sync on app open',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Automatically fetch step and active cals data whenever IndiFit is launched',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _autoSyncOnOpen,
                activeThumbColor: AppColors.primary,
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
                          Icon(
                            Icons.nordic_walking_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Imported Outdoor Activities',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._outdoorActivities.map(
                        (act) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryGlow,
                            child: Icon(
                              Icons.directions_run_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            act['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${act['durationMinutes']} mins • ${act['calories']} kcal (Source: ${act['sourceName'] ?? 'Health'})',
                          ),
                          trailing: Text(
                            '${(act['date'] as DateTime).month}/${(act['date'] as DateTime).day}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Connect / Sync Action Button
            ElevatedButton.icon(
              onPressed: isLoading ? null : _handleConnect,
              icon: Icon(
                data.isConnected
                    ? Icons.sync_rounded
                    : Icons.health_and_safety_rounded,
              ),
              label: Text(
                data.isConnected
                    ? 'Re-Sync Health Data'
                    : 'Connect Health Service',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatWidget(
    IconData icon,
    String value,
    String label,
    Color iconCol,
  ) {
    return Column(
      children: [
        Icon(icon, color: iconCol, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
