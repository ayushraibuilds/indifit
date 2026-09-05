import '../../../core/presentation/product_failure_presentation.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../../data/repositories/program_activation_coordinator.dart';
import '../../workout_player/widgets/b02_execution_semantics.dart';

/// Program review label helpers (PV1-ENG-05E first pass).
///
/// Extracted verbatim from `program_review_screen.dart`; unchanged.

String activationFailureMessage(Object error) {
  if (error is ActivationRejectedException &&
      error.message.contains('existing workout draft')) {
    return 'Finish or discard your current workout before using this plan.';
  }
  return ProductFailurePresentation.fromError(error).message;
}

String groupTypeLabel(String raw) {
  try {
    return b02ExecutionGroupTypeLabel(B02GroupType.parse(raw));
  } catch (_) {
    return 'Grouped exercises';
  }
}
