import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/health_service.dart';
import '../presentation/product_failure_presentation.dart';

enum HealthStatus {
  initial,
  loading,
  notRequested,
  denied,
  partial,
  unknown,
  unsupported,
  unavailable,
  available,
  noData,
  error,
  refreshing,
}

class HealthState {
  final HealthStatus status;
  final HealthDataSummary summary;
  final String? errorMessage;

  const HealthState({
    required this.status,
    this.summary = const HealthDataSummary(),
    this.errorMessage,
  });

  HealthState copyWith({
    HealthStatus? status,
    HealthDataSummary? summary,
    String? errorMessage,
  }) {
    return HealthState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class HealthStateNotifier extends StateNotifier<HealthState> {
  final HealthService _healthService;
  bool _isLoading = false;

  HealthStateNotifier(this._healthService)
    : super(const HealthState(status: HealthStatus.initial)) {
    loadHealthData();
  }

  Future<void> loadHealthData() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(status: HealthStatus.loading);

    try {
      final summary = await _healthService.fetchTodayHealthData();
      if (!mounted) return;

      final status = _statusForSummary(summary);
      state = HealthState(
        status: status,
        summary: summary,
        errorMessage: switch (status) {
          HealthStatus.error ||
          HealthStatus.notRequested ||
          HealthStatus.denied ||
          HealthStatus.partial ||
          HealthStatus.unknown ||
          HealthStatus.unsupported ||
          HealthStatus.unavailable => summary.statusMessage,
          _ => null,
        },
      );
    } catch (error) {
      if (!mounted) return;
      state = HealthState(
        status: HealthStatus.error,
        errorMessage: ProductFailurePresentation.fromError(
          error,
          title: 'Health data unavailable',
          code: 'health_unavailable',
        ).message,
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> connectAndRefresh() async {
    state = state.copyWith(status: HealthStatus.refreshing);
    bool granted;
    try {
      granted = await _healthService.requestPermissions();
    } catch (error) {
      if (!mounted) return;
      state = HealthState(
        status: HealthStatus.error,
        errorMessage: ProductFailurePresentation.fromError(
          error,
          title: 'Health data unavailable',
          code: 'health_unavailable',
        ).message,
      );
      return;
    }
    if (!mounted) return;

    if (!granted) {
      final requestStatus = _healthService.lastPermissionRequestStatus;
      final status = switch (requestStatus) {
        HealthConnectionStatus.unavailable => HealthStatus.unavailable,
        HealthConnectionStatus.notConnected => HealthStatus.notRequested,
        _ => HealthStatus.denied,
      };
      final connectionStatus = switch (status) {
        HealthStatus.unavailable => HealthConnectionStatus.unavailable,
        HealthStatus.notRequested => HealthConnectionStatus.notConnected,
        _ => HealthConnectionStatus.denied,
      };
      state = HealthState(
        status: status,
        summary: state.summary.copyWith(
          isConnected: false,
          isError: false,
          connectionStatus: connectionStatus,
          integrationEnabled: false,
          permissionStates: const {},
          statusMessage: switch (status) {
            HealthStatus.unavailable =>
              'Health data is unavailable on this device.',
            HealthStatus.notRequested => 'No Health categories are selected.',
            _ =>
              'Health permissions were denied. No selected Health permissions are available.',
          },
        ),
        errorMessage: switch (status) {
          HealthStatus.unavailable =>
            'Health data is unavailable on this device.',
          HealthStatus.notRequested => 'No Health categories are selected.',
          _ =>
            'Health permissions were denied. No selected Health permissions are available.',
        },
      );
      return;
    }

    await loadHealthData();
  }

  Future<void> refresh() async {
    state = state.copyWith(status: HealthStatus.refreshing);
    await loadHealthData();
  }

  static HealthStatus _statusForSummary(HealthDataSummary summary) {
    if (summary.isError) return HealthStatus.error;
    switch (summary.availability) {
      case HealthPlatformAvailability.unsupported:
        return HealthStatus.unsupported;
      case HealthPlatformAvailability.unavailable:
      case HealthPlatformAvailability.error:
        return HealthStatus.unavailable;
      case HealthPlatformAvailability.unknown:
      case HealthPlatformAvailability.supported:
        break;
    }

    return switch (summary.resolvedConnectionStatus) {
      HealthConnectionStatus.notConnected => HealthStatus.notRequested,
      HealthConnectionStatus.denied => HealthStatus.denied,
      HealthConnectionStatus.partial => HealthStatus.partial,
      HealthConnectionStatus.unknown => HealthStatus.unknown,
      HealthConnectionStatus.unavailable => HealthStatus.unavailable,
      HealthConnectionStatus.connected =>
        summary.hasDailyMetricData
            ? HealthStatus.available
            : HealthStatus.noData,
    };
  }
}

final healthStateProvider =
    StateNotifierProvider<HealthStateNotifier, HealthState>((ref) {
      final service = ref.watch(healthServiceProvider);
      return HealthStateNotifier(service);
    });
