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

/// Active connected implementation for Post-V1 capability boundary.
class ConnectedAiAssistanceCapability implements AiAssistanceCapability {
  final bool Function() _isAllowed;
  final Future<List<Map<String, dynamic>>> Function(String input)? _mealParser;

  const ConnectedAiAssistanceCapability({
    required bool Function() isAllowed,
    Future<List<Map<String, dynamic>>> Function(String input)? mealParser,
  })  : _isAllowed = isAllowed,
        _mealParser = mealParser;

  @override
  bool get isEnabled => _isAllowed();

  @override
  Future<AiAssistanceResult<List<Map<String, dynamic>>>> parseMealDescription(
    String input,
  ) async {
    if (!isEnabled) {
      return const AiAssistanceResult(
        success: false,
        errorMessage: 'AI assistance is disabled in offline mode.',
      );
    }
    if (_mealParser != null) {
      try {
        final data = await _mealParser(input);
        return AiAssistanceResult(success: true, data: data);
      } catch (e) {
        return AiAssistanceResult(success: false, errorMessage: e.toString());
      }
    }
    return const AiAssistanceResult(
      success: false,
      errorMessage: 'Meal parser is not configured.',
    );
  }

  @override
  Future<AiAssistanceResult<String>> generateCoachingGuidance({
    required String contextPrompt,
  }) async {
    return const AiAssistanceResult(
      success: false,
      errorMessage: 'Coaching guidance is not configured in this release.',
    );
  }
}
