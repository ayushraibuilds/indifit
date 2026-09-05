import 'content_pack_models.dart';
import 'content_pack_validator.dart';

/// Activation states for downloadable content. `bundled` means the app runs
/// on its compiled-in canonical assets; anything else names an active pack.
enum ContentPackActivation {
  bundled,
  active,
}

/// In-memory activation registry: which verified pack (if any) is live.
///
/// Policy:
/// - Only envelopes that passed [ContentPackValidator] may activate; the
///   registry itself re-checks `validation.isValid` and throws otherwise, so
///   a caller bug cannot promote an unverified pack.
/// - Failed activation never touches the active pack (last-good retained).
/// - [rollbackToBundled] returns to compiled-in assets; it never deletes or
///   mutates history, downloads, or user data.
/// - No persistence here by design (hotspot rule: no schema changes in this
///   package). Durable pack pinning belongs to a later storage package.
///
/// [TDownload] is intentionally absent: acquisition (network/cache) is a
/// separate capability (`ContentDownloadCapability`); this registry only
/// decides what verified content is live.
class ContentPackRegistry {
  ContentPackRegistry();

  ContentPackEnvelope? _active;
  ContentPackEnvelope? _staged;

  ContentPackEnvelope? get active => _active;
  ContentPackEnvelope? get staged => _staged;
  ContentPackActivation get activation =>
      _active == null ? ContentPackActivation.bundled : ContentPackActivation.active;

  /// Stages a verified envelope for review/inspection without activating it.
  void stage({
    required ContentPackEnvelope envelope,
    required ContentPackValidation validation,
  }) {
    if (!validation.isValid) {
      throw ArgumentError(
        'Refusing to stage an unverified pack: ${validation.errors.join('; ')}',
      );
    }
    _staged = envelope;
  }

  /// Atomically promotes the staged envelope (must be the same instance).
  /// Anything else — including a valid-but-unstaged envelope — throws and
  /// leaves the active pack untouched.
  void activateStaged(ContentPackEnvelope envelope) {
    if (!identical(_staged, envelope)) {
      throw ArgumentError(
        'Only the staged envelope may activate; refusing to switch packs.',
      );
    }
    _active = envelope;
    _staged = null;
  }

  /// Convenience for the common path: validate-then-activate in one step.
  /// Throws on invalid input with the active pack untouched.
  void activateVerified({
    required ContentPackEnvelope envelope,
    required ContentPackValidation validation,
  }) {
    stage(envelope: envelope, validation: validation);
    activateStaged(envelope);
  }

  /// Returns to bundled canonical assets. Never throws for missing state.
  void rollbackToBundled() {
    _active = null;
    _staged = null;
  }
}
