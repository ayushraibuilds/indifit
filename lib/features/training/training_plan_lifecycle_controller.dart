import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/program_lifecycle_repository.dart';

/// Presentation command boundary for Training. Widgets request a user-facing
/// action here; the repository owns validation, idempotency, and the database
/// transaction.
class TrainingPlanLifecycleController {
  final ProgramLifecycleRepository _repository;
  final Uuid _uuid;

  TrainingPlanLifecycleController(this._repository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  Future<EndActivePlanResult> finishPlan() => _end(PlanEndOutcome.finished);

  Future<EndActivePlanResult> leavePlan() => _end(PlanEndOutcome.left);

  Future<EndActivePlanResult> _end(PlanEndOutcome outcome) {
    return _repository.endActivePlan(
      EndActivePlanCommand(
        outcome: outcome,
        commandId: 'training-plan-${outcome.storageValue}::${_uuid.v4()}',
      ),
    );
  }
}

final trainingPlanLifecycleControllerProvider =
    Provider<TrainingPlanLifecycleController>((ref) {
      return TrainingPlanLifecycleController(
        ref.watch(programLifecycleRepositoryProvider),
      );
    });
