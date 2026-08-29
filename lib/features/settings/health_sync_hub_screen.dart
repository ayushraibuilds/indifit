import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/health_provider.dart';
import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
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
  List<Map<String, dynamic>> _outdoorActivities = [];
  Map<HealthCategory, bool> _categoryStates = {};
  String? _supportingDataError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _loading = true);
    try {
      await ref.read(healthStateProvider.notifier).refresh();
      await _loadSupportingData();
    } catch (_) {
      if (mounted) {
        setState(() {
          _supportingDataError = 'Health data could not be checked. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSupportingData() async {
    final service = ref.read(healthServiceProvider);
    try {
      final lastSyncIso = await service.getLastSyncTime();
      final categoryStates = await service.getAllCategoryStates();
      final healthState = ref.read(healthStateProvider);
      final connection = _connectionStatus(healthState);
      final db = ref.read(databaseProvider);
      final activities = _canUseHealthData(connection)
          ? await service.importOutdoorActivities(db)
          : <Map<String, dynamic>>[];

      String? formattedSync;
      if (lastSyncIso != null) {
        final date = DateTime.tryParse(lastSyncIso);
        if (date != null) {
          formattedSync =
              'Last read ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        }
      }

      if (!mounted) return;
      setState(() {
        _lastSyncTimeStr = formattedSync;
        _outdoorActivities = activities
            .where((activity) => activity['imported'] == true)
            .toList(growable: false);
        _categoryStates = categoryStates;
        _supportingDataError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supportingDataError =
            'Some Health data could not be loaded. Try again.';
        _outdoorActivities = [];
        _categoryStates = {};
      });
    }
  }

  Future<void> _toggleCategory(HealthCategory category, bool enabled) async {
    final service = ref.read(healthServiceProvider);
    try {
      await service.setCategoryState(category, enabled);
      if (enabled) {
        await service.requestCategoryPermissions(category);
      }
      if (!mounted) return;
      await _fetchData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supportingDataError =
            'Health permission could not be updated. Try again.';
      });
    }
  }

  Future<void> _handleConnect() async {
    if (mounted) setState(() => _loading = true);
    try {
      await ref.read(healthStateProvider.notifier).connectAndRefresh();
      if (!mounted) return;
      await _loadSupportingData();
    } catch (_) {
      if (mounted) {
        setState(() {
          _supportingDataError =
              'Health connection could not be updated. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDisconnect() async {
    if (mounted) setState(() => _loading = true);
    try {
      await ref.read(healthServiceProvider).disconnect();
      await ref.read(healthStateProvider.notifier).refresh();
      if (!mounted) return;
      await _loadSupportingData();
    } catch (_) {
      if (mounted) {
        setState(() {
          _supportingDataError =
              'Health connection could not be updated. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  HealthConnectionStatus _connectionStatus(HealthState healthState) {
    return switch (healthState.status) {
      HealthStatus.notRequested => HealthConnectionStatus.notConnected,
      HealthStatus.denied => HealthConnectionStatus.denied,
      HealthStatus.partial => HealthConnectionStatus.partial,
      HealthStatus.unknown => HealthConnectionStatus.unknown,
      HealthStatus.unsupported ||
      HealthStatus.unavailable => HealthConnectionStatus.unavailable,
      _ => healthState.summary.resolvedConnectionStatus,
    };
  }

  static bool _canUseHealthData(HealthConnectionStatus status) =>
      status == HealthConnectionStatus.connected ||
      status == HealthConnectionStatus.partial ||
      status == HealthConnectionStatus.unknown;

  static bool _canEditCategories(HealthConnectionStatus status, bool loading) =>
      !loading && _canUseHealthData(status);

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthStateProvider);
    final data = healthState.summary;
    final connection = _connectionStatus(healthState);
    final isLoading =
        _loading ||
        healthState.status == HealthStatus.loading ||
        healthState.status == HealthStatus.refreshing;
    final platformName = data.platformName ?? 'Health data';

    return ConsumerTaskScaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          B05IconAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh health data',
            hint: 'Check Health connection and data again.',
            onPressed: isLoading ? null : _fetchData,
          ),
        ],
      ),
      primaryAction: _buildPrimaryAction(
        healthState: healthState,
        connection: connection,
        platformName: platformName,
        isLoading: isLoading,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Health integration', style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space8),
          Text(
            _canUseHealthData(connection)
                ? 'Choose what IndiFit may use from your health app. Supported walking, running, and cycling activities can be imported. Weight logs saved in IndiFit can be added to your health app when Body weight is allowed.'
                : _disconnectedIntroduction(platformName),
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space20),
          _buildSectionLabel(context, 'HEALTH CONNECTION'),
          const SizedBox(height: B05Layout.space8),
          _buildConnectionSurface(
            context,
            healthState: healthState,
            connection: connection,
            platformName: platformName,
            isLoading: isLoading,
          ),
          if (_canUseHealthData(connection)) ...[
            const SizedBox(height: B05Layout.space20),
            _buildSectionLabel(context, 'WHAT INDIFIT MAY USE'),
            const SizedBox(height: B05Layout.space8),
            _buildCategorySurface(
              context,
              summary: data,
              connection: connection,
              isLoading: isLoading,
            ),
          ],
          if (_outdoorActivities.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space20),
            _buildImportedActivities(context),
          ],
          if (_supportingDataError != null) ...[
            const SizedBox(height: B05Layout.space20),
            ConsumerStatusRow(
              label: 'Health data could not be loaded',
              detail: _supportingDataError,
              error: true,
              onRetry: isLoading ? null : _fetchData,
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildPrimaryAction({
    required HealthState healthState,
    required HealthConnectionStatus connection,
    required String platformName,
    required bool isLoading,
  }) {
    if (healthState.status == HealthStatus.error) {
      return B05ActionButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        onPressed: isLoading ? null : _fetchData,
      );
    }
    if (healthState.status == HealthStatus.unsupported) return null;
    if (connection == HealthConnectionStatus.unavailable) {
      return B05ActionButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        onPressed: isLoading ? null : _fetchData,
        emphasis: B05ActionEmphasis.secondary,
      );
    }
    if (connection == HealthConnectionStatus.connected ||
        connection == HealthConnectionStatus.partial ||
        connection == HealthConnectionStatus.unknown) {
      return B05ActionGroup(
        children: [
          B05ActionButton(
            label: 'Refresh health data',
            icon: Icons.refresh_rounded,
            onPressed: isLoading ? null : _fetchData,
          ),
          B05ActionButton(
            label: 'Disconnect',
            icon: Icons.link_off_rounded,
            emphasis: B05ActionEmphasis.secondary,
            onPressed: isLoading ? null : _handleDisconnect,
          ),
        ],
      );
    }
    return B05ActionButton(
      label: _connectLabel(platformName),
      icon: Icons.health_and_safety_outlined,
      onPressed: isLoading ? null : _handleConnect,
    );
  }

  static String _connectLabel(String platformName) {
    if (platformName == 'Apple Health') return 'Connect Apple Health';
    if (platformName == 'Health Connect') return 'Connect Health Connect';
    return 'Connect health data';
  }

  static String _disconnectedIntroduction(String platformName) {
    final source = platformName == 'Health data'
        ? 'your health app'
        : platformName;
    return 'Connect $source to optionally use supported health data in IndiFit, including steps, activity, sleep, and other available categories.';
  }

  Widget _buildConnectionSurface(
    BuildContext context, {
    required HealthState healthState,
    required HealthConnectionStatus connection,
    required String platformName,
    required bool isLoading,
  }) {
    final status = _statusPresentation(
      healthState: healthState,
      connection: connection,
      platformName: platformName,
    );
    return B05Surface(
      tone: B05SurfaceTone.section,
      child: Semantics(
        container: true,
        label: 'Health integration status',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection status',
                        style: B05Typography.title(context),
                      ),
                      const SizedBox(height: B05Layout.space4),
                      Text(
                        'Platform: $platformName',
                        style: B05Typography.caption(context),
                      ),
                      if (_lastSyncTimeStr != null &&
                          _canUseHealthData(connection)) ...[
                        const SizedBox(height: B05Layout.space4),
                        Text(
                          _lastSyncTimeStr!,
                          style: B05Typography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _statusIcon(connection),
                  size: B05Layout.iconLarge,
                  color: context.b05Colors.status(status.status).indicator,
                  semanticLabel: status.label,
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            if (isLoading)
              const ConsumerStatusRow(
                label: 'Checking Health data',
                detail: 'Checking platform and permission status.',
                loading: true,
              )
            else
              B05StatusMessage(
                status: status.status,
                label: status.label,
                value: status.detail,
              ),
            if (healthState.status == HealthStatus.noData &&
                _canUseHealthData(connection)) ...[
              const SizedBox(height: B05Layout.space12),
              Text(
                'No step, active energy, or sleep values were returned for today.',
                style: B05Typography.body(context),
              ),
            ] else if (_canShowMetrics(healthState, connection)) ...[
              const SizedBox(height: B05Layout.space16),
              _buildMetrics(context, data: healthState.summary),
            ],
            if (_canUseHealthData(connection)) ...[
              const SizedBox(height: B05Layout.space12),
              Text(
                'Disconnecting stops future Health use in IndiFit. Existing IndiFit history stays on this device. You can also manage permissions in your device settings.',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySurface(
    BuildContext context, {
    required HealthDataSummary summary,
    required HealthConnectionStatus connection,
    required bool isLoading,
  }) {
    final canEdit = _canEditCategories(connection, isLoading);
    final descriptors = HealthService.visibleCategoryDescriptors.toList();
    return B05Surface(
      tone: B05SurfaceTone.section,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < descriptors.length; index++) ...[
            _buildCategoryTile(
              context,
              descriptor: descriptors[index],
              summary: summary,
              canEdit: canEdit,
              integrationActive: _canUseHealthData(connection),
            ),
            if (index < descriptors.length - 1)
              Divider(height: 1, color: context.b05Colors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required HealthCategoryDescriptor descriptor,
    required HealthDataSummary summary,
    required bool canEdit,
    required bool integrationActive,
  }) {
    final category = descriptor.category;
    final localEnabled =
        _categoryStates[category] ?? summary.categoryStates[category] ?? true;
    final permission = summary.permissionFor(category);
    final switchValue =
        integrationActive &&
        localEnabled &&
        (permission == HealthPermissionStatus.granted ||
            permission == HealthPermissionStatus.unknown);
    final statusText = _permissionLabel(permission);
    return Semantics(
      container: true,
      label: '${descriptor.title}, $statusText',
      child: SwitchListTile.adaptive(
        title: Text(descriptor.title, style: B05Typography.label(context)),
        subtitle: Text(
          '${descriptor.description} Status: $statusText.',
          style: B05Typography.caption(context),
        ),
        value: switchValue,
        activeTrackColor: context.b05Colors.action,
        onChanged: canEdit ? (value) => _toggleCategory(category, value) : null,
      ),
    );
  }

  Widget _buildMetrics(
    BuildContext context, {
    required HealthDataSummary data,
  }) {
    final metrics = <Widget>[];
    if (_canDisplayMetric(data, HealthCategory.steps)) {
      metrics.add(
        _buildMetric(
          context,
          Icons.directions_walk_outlined,
          '${data.steps}',
          'Steps',
        ),
      );
    }
    if (_canDisplayMetric(data, HealthCategory.activeEnergy)) {
      metrics.add(
        _buildMetric(
          context,
          Icons.local_fire_department_outlined,
          '${data.activeCalories.toInt()} kcal',
          'Active energy',
        ),
      );
    }
    if (_canDisplayMetric(data, HealthCategory.sleep)) {
      metrics.add(
        _buildMetric(
          context,
          Icons.bedtime_outlined,
          '${data.sleepHours.toStringAsFixed(1)} h',
          'Sleep',
        ),
      );
    }
    if (metrics.isEmpty) {
      return Text(
        'No readable daily metrics are available.',
        style: B05Typography.body(context),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideEnough = constraints.maxWidth >= 360;
        final content = wideEnough
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: metrics
                    .map((metric) => Expanded(child: metric))
                    .toList(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    metrics[index],
                    if (index < metrics.length - 1)
                      const SizedBox(height: B05Layout.space12),
                  ],
                ],
              );
        return B05Surface(
          tone: B05SurfaceTone.inset,
          padding: const EdgeInsets.all(B05Layout.space12),
          child: content,
        );
      },
    );
  }

  Widget _buildMetric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: context.b05Colors.action,
            size: B05Layout.iconLarge,
          ),
          const SizedBox(height: B05Layout.space4),
          Text(value, style: B05Typography.metric(context)),
          Text(label, style: B05Typography.caption(context)),
        ],
      ),
    );
  }

  Widget _buildImportedActivities(BuildContext context) {
    return B05Surface(
      tone: B05SurfaceTone.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Imported activities', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Reviewed walking, running, and cycling activities from Health.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space8),
          for (final activity in _outdoorActivities)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.directions_run_outlined,
                color: context.b05Colors.action,
              ),
              title: Text(_activityLabel(activity['activityType'])),
              subtitle: Text('${activity['durationMinutes'] ?? 0} min'),
            ),
        ],
      ),
    );
  }

  static bool _canShowMetrics(
    HealthState healthState,
    HealthConnectionStatus connection,
  ) =>
      healthState.status != HealthStatus.error &&
      healthState.status != HealthStatus.unknown &&
      _canUseHealthData(connection);

  static bool _canDisplayMetric(
    HealthDataSummary data,
    HealthCategory category,
  ) {
    final permission = data.permissionFor(category);
    return data.hasDataFor(category) &&
        (permission == HealthPermissionStatus.granted ||
            permission == HealthPermissionStatus.unknown);
  }

  static String _permissionLabel(HealthPermissionStatus status) {
    return switch (status) {
      HealthPermissionStatus.disabled => 'Off in IndiFit',
      HealthPermissionStatus.notRequested => 'Not requested',
      HealthPermissionStatus.granted => 'Allowed',
      HealthPermissionStatus.denied => 'Not allowed',
      HealthPermissionStatus.unknown => 'Access status cannot be confirmed',
      HealthPermissionStatus.unavailable => 'Unavailable on this device',
    };
  }

  static String _activityLabel(Object? activityType) => switch (activityType) {
    'walking' => 'Walking',
    'running' => 'Running',
    'cycling' => 'Cycling',
    _ => 'Imported activity',
  };

  static _StatusPresentation _statusPresentation({
    required HealthState healthState,
    required HealthConnectionStatus connection,
    required String platformName,
  }) {
    if (healthState.status == HealthStatus.error) {
      return const _StatusPresentation(
        status: B05SemanticStatus.danger,
        label: 'Health data unavailable',
        detail: 'We could not check Health data. Try again.',
      );
    }
    return switch (connection) {
      HealthConnectionStatus.connected => _StatusPresentation(
        status: B05SemanticStatus.success,
        label: 'Connected',
        detail: 'IndiFit can use the allowed $platformName categories.',
      ),
      HealthConnectionStatus.partial => const _StatusPresentation(
        status: B05SemanticStatus.warning,
        label: 'Partly connected',
        detail: 'Only categories marked Allowed can be used.',
      ),
      HealthConnectionStatus.unknown => _StatusPresentation(
        status: B05SemanticStatus.info,
        label: 'Access status unavailable',
        detail:
            '$platformName does not confirm read access. IndiFit only uses data the system returns.',
      ),
      HealthConnectionStatus.denied => const _StatusPresentation(
        status: B05SemanticStatus.danger,
        label: 'Permission not granted',
        detail: 'No selected Health categories are available.',
      ),
      HealthConnectionStatus.unavailable =>
        healthState.status == HealthStatus.unsupported
            ? const _StatusPresentation(
                status: B05SemanticStatus.unavailable,
                label: 'Not supported on this platform',
                detail: 'Health integration is not supported on this platform.',
              )
            : const _StatusPresentation(
                status: B05SemanticStatus.unavailable,
                label: 'Unavailable',
                detail: 'Health data is unavailable on this device.',
              ),
      HealthConnectionStatus.notConnected => const _StatusPresentation(
        status: B05SemanticStatus.info,
        label: 'Not connected',
        detail: 'Connect to choose the Health categories IndiFit may use.',
      ),
    };
  }

  static IconData _statusIcon(HealthConnectionStatus status) {
    return switch (status) {
      HealthConnectionStatus.connected => Icons.check_circle_outline,
      HealthConnectionStatus.partial => Icons.rule_outlined,
      HealthConnectionStatus.unknown => Icons.help_outline,
      HealthConnectionStatus.denied => Icons.lock_outline,
      HealthConnectionStatus.unavailable => Icons.do_not_disturb_alt_outlined,
      HealthConnectionStatus.notConnected => Icons.link_off_outlined,
    };
  }

  static Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: B05Typography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .8),
    );
  }
}

class _StatusPresentation {
  final B05SemanticStatus status;
  final String label;
  final String detail;

  const _StatusPresentation({
    required this.status,
    required this.label,
    required this.detail,
  });
}
