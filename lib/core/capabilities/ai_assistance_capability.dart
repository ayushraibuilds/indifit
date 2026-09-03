/// Output of an AI assistance query.
class AiAssistanceResult<T> {
  const AiAssistanceResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.modelName,
  });

  final bool success;
  final T? data;
  final String? errorMessage;
  final String? modelName;
}

/// Abstract contract for optional cloud AI assistance (e.g. natural language meal
/// parsing, adaptive suggestion text, routine ideas).
///
/// Invariant: AI is an accelerator, never an authority. AI outputs must be
/// reviewed and user-confirmed before committing as canonical personal records.
/// AI never originates canonical nutrition targets, PRs, or weight records.
abstract class AiAssistanceCapability {
  /// True if an AI service is configured and enabled by the user.
  bool get isEnabled;

  /// Parses natural language food text into structured food candidates.
  Future<AiAssistanceResult<List<Map<String, dynamic>>>> parseMealDescription(
    String input,
  );

  /// Requests context-aware workout coaching suggestions.
  Future<AiAssistanceResult<String>> generateCoachingGuidance({
    required String contextPrompt,
  });
}

/// Default disabled implementation for air-gapped / offline operation.
class DisabledAiAssistanceCapability implements AiAssistanceCapability {
  const DisabledAiAssistanceCapability();

  @override
  bool get isEnabled => false;

  @override
  Future<AiAssistanceResult<List<Map<String, dynamic>>>> parseMealDescription(
    String input,
  ) async =>
      const AiAssistanceResult(
        success: false,
        errorMessage: 'AI assistance is disabled in offline mode.',
      );

  @override
  Future<AiAssistanceResult<String>> generateCoachingGuidance({
    required String contextPrompt,
  }) async =>
      const AiAssistanceResult(
        success: false,
        errorMessage: 'AI coaching is disabled in offline mode.',
      );
}
