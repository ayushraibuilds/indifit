import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/health_service.dart';
import '../presentation/product_failure_presentation.dart';

enum HealthStatus {
  initial,
  loading,
  notRequested,
  denied,
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

      if (summary.isError) {
        state = HealthState(
          status: HealthStatus.error,
          summary: summary,
          errorMessage: summary.statusMessage,
        );
      } else if (!summary.isConnected) {
        state = HealthState(
          status: HealthStatus.notRequested,
          summary: summary,
          errorMessage: summary.statusMessage,
        );
      } else if (summary.steps == 0 &&
          summary.activeCalories == 0.0 &&
          summary.sleepHours == 0.0) {
        state = HealthState(status: HealthStatus.noData, summary: summary);
      } else {
        state = HealthState(status: HealthStatus.available, summary: summary);
      }
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
      state = const HealthState(
        status: HealthStatus.denied,
        errorMessage: 'Health permissions denied by user.',
      );
      return;
    }

    await loadHealthData();
  }

  Future<void> refresh() async {
    state = state.copyWith(status: HealthStatus.refreshing);
    await loadHealthData();
  }
}

final healthStateProvider =
    StateNotifierProvider<HealthStateNotifier, HealthState>((ref) {
      final service = ref.watch(healthServiceProvider);
      return HealthStateNotifier(service);
    });
