import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../data/repositories/dashboard_personalization_repository.dart';
import 'dashboard_module_registry.dart';

enum DashboardPersonalizationStatus { loading, ready, saving, error }

class DashboardPersonalizationState {
  final DashboardPersonalizationStatus status;
  final List<DashboardModuleLayoutItem> layout;
  final String? errorMessage;

  const DashboardPersonalizationState({
    required this.status,
    this.layout = const [],
    this.errorMessage,
  });

  const DashboardPersonalizationState.loading()
    : status = DashboardPersonalizationStatus.loading,
      layout = const [],
      errorMessage = null;

  DashboardPersonalizationState copyWith({
    DashboardPersonalizationStatus? status,
    List<DashboardModuleLayoutItem>? layout,
    String? errorMessage,
    bool clearError = false,
  }) => DashboardPersonalizationState(
    status: status ?? this.status,
    layout: layout ?? this.layout,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  bool get isSaving => status == DashboardPersonalizationStatus.saving;
}

/// Presentation-only controller for B05 dashboard personalization. It calls
/// the B05 repository but does not query Drift or calculate B01–B04 facts.
class DashboardPersonalizationController
    extends StateNotifier<DashboardPersonalizationState> {
  final DashboardPersonalizationRepository _repository;
  final String _userId;
  Future<void> Function()? _retryAction;

  DashboardPersonalizationController({
    required DashboardPersonalizationRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId,
       super(const DashboardPersonalizationState.loading());

  Future<void> load() async {
    state = DashboardPersonalizationState(
      status: DashboardPersonalizationStatus.loading,
      layout: state.layout,
    );
    try {
      final layout = await _repository.readLayout(userId: _userId);
      if (!mounted) return;
      _retryAction = null;
      state = DashboardPersonalizationState(
        status: DashboardPersonalizationStatus.ready,
        layout: layout,
      );
    } catch (error) {
      if (!mounted) return;
      _retryAction = load;
      state = DashboardPersonalizationState(
        status: DashboardPersonalizationStatus.error,
        layout: state.layout,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> reorder(String moduleId, int targetIndex) => _run(
    () => _repository.reorder(
      userId: _userId,
      moduleId: moduleId,
      targetIndex: targetIndex,
    ),
  );

  Future<void> setVisible(String moduleId, bool isVisible) => _run(
    () => _repository.setVisible(
      userId: _userId,
      moduleId: moduleId,
      isVisible: isVisible,
    ),
  );

  Future<void> setCollapsed(String moduleId, bool isCollapsed) => _run(
    () => _repository.setCollapsed(
      userId: _userId,
      moduleId: moduleId,
      isCollapsed: isCollapsed,
    ),
  );

  /// A caller must invoke this explicitly; passive reads never repair data.
  Future<void> reconcile() =>
      _run(() => _repository.reconcile(userId: _userId));

  Future<void> retry() async {
    final action = _retryAction;
    if (action == null || state.isSaving) return;
    await action();
  }

  Future<void> _run(
    Future<List<DashboardModuleLayoutItem>> Function() action,
  ) async {
    if (state.isSaving) return;
    state = state.copyWith(
      status: DashboardPersonalizationStatus.saving,
      clearError: true,
    );
    try {
      final layout = await action();
      if (!mounted) return;
      _retryAction = null;
      state = DashboardPersonalizationState(
        status: DashboardPersonalizationStatus.ready,
        layout: layout,
      );
    } catch (error) {
      if (!mounted) return;
      _retryAction = () => _run(action);
      state = DashboardPersonalizationState(
        status: DashboardPersonalizationStatus.error,
        layout: state.layout,
        errorMessage: error.toString(),
      );
    }
  }
}

final dashboardModuleRegistryProvider = Provider<DashboardModuleRegistry>(
  (_) => standardDashboardModuleRegistry,
);

final dashboardPersonalizationRepositoryProvider =
    Provider<DashboardPersonalizationRepository>(
      (ref) => DashboardPersonalizationRepository(
        database: ref.watch(databaseProvider),
        registry: ref.watch(dashboardModuleRegistryProvider),
      ),
    );

final dashboardPersonalizationControllerProvider =
    StateNotifierProvider.autoDispose<
      DashboardPersonalizationController,
      DashboardPersonalizationState
    >((ref) {
      final controller = DashboardPersonalizationController(
        repository: ref.watch(dashboardPersonalizationRepositoryProvider),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.load());
      return controller;
    });
