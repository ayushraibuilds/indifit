import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/privacy/privacy_policy.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_models.dart';
import '../repositories/coaching_preference_repository.dart';

const String kB04OptionalAiEnvelopeVersion =
    'b04-optional-ai-wording-envelope-v1';
const String kB04OptionalAiResponseVersion =
    'b04-optional-ai-wording-response-v1';

/// The only output the optional AI boundary can add to a deterministic result.
///
/// It is deliberately not a recommendation, target, safety result, evidence
/// record, or replacement for deterministic explanation text.
class B04OptionalAiWordingSuggestion {
  final String recommendationId;
  final String wording;

  const B04OptionalAiWordingSuggestion({
    required this.recommendationId,
    required this.wording,
  });
}

class B04OptionalAiWordingResponse {
  final String responseVersion;
  final String deterministicFingerprint;
  final String providerVersion;
  final List<B04OptionalAiWordingSuggestion> suggestions;

  const B04OptionalAiWordingResponse({
    required this.responseVersion,
    required this.deterministicFingerprint,
    required this.providerVersion,
    required this.suggestions,
  });

  factory B04OptionalAiWordingResponse.parse({
    required Object? raw,
    required String expectedFingerprint,
    required Set<String> allowedRecommendationIds,
    required Map<String, String> approvedWordingByRecommendationId,
  }) {
    if (raw is! Map) {
      throw const FormatException('AI response must be an object.');
    }
    final map = Map<String, dynamic>.from(raw);
    _requireExactKeys(map, const {
      'response_version',
      'deterministic_fingerprint',
      'provider_version',
      'suggestions',
    });

    final responseVersion = _requiredString(map, 'response_version');
    if (responseVersion != kB04OptionalAiResponseVersion) {
      throw const FormatException('Unsupported AI response version.');
    }
    final fingerprint = _requiredString(map, 'deterministic_fingerprint');
    if (fingerprint != expectedFingerprint) {
      throw const FormatException(
        'AI response does not match the deterministic evaluation.',
      );
    }
    final providerVersion = _requiredString(map, 'provider_version');
    final rawSuggestions = map['suggestions'];
    if (rawSuggestions is! List) {
      throw const FormatException('AI suggestions must be a list.');
    }

    final seenIds = <String>{};
    final suggestions = <B04OptionalAiWordingSuggestion>[];
    for (final rawSuggestion in rawSuggestions) {
      if (rawSuggestion is! Map) {
        throw const FormatException('AI suggestions must be objects.');
      }
      final suggestion = Map<String, dynamic>.from(rawSuggestion);
      _requireExactKeys(suggestion, const {'recommendation_id', 'wording'});
      final recommendationId = _requiredString(suggestion, 'recommendation_id');
      if (!allowedRecommendationIds.contains(recommendationId)) {
        throw const FormatException(
          'AI may only word an eligible deterministic recommendation.',
        );
      }
      if (!seenIds.add(recommendationId)) {
        throw const FormatException(
          'AI returned duplicate recommendation IDs.',
        );
      }
      final approvedWording =
          approvedWordingByRecommendationId[recommendationId];
      if (approvedWording == null) {
        throw const FormatException(
          'AI wording has no deterministic approved copy.',
        );
      }
      final wording = _validatedWording(
        suggestion['wording'],
        approvedWording: approvedWording,
      );
      suggestions.add(
        B04OptionalAiWordingSuggestion(
          recommendationId: recommendationId,
          wording: wording,
        ),
      );
    }

    return B04OptionalAiWordingResponse(
      responseVersion: responseVersion,
      deterministicFingerprint: fingerprint,
      providerVersion: providerVersion,
      suggestions: List.unmodifiable(suggestions),
    );
  }
}

/// A provider receives semantic states and opaque lineage fingerprints only.
/// It never receives a prompt assembled from raw application text.
abstract interface class B04OptionalAiProvider {
  Future<Object?> request(B04OptionalAiRedactedEnvelope envelope);
}

/// The production provider boundary. It sends only [envelope.toJson] and does
/// not persist or log either the request body or the provider response.
class B04DioOptionalAiProvider implements B04OptionalAiProvider {
  final Dio _dio;
  final String _endpoint;

  B04DioOptionalAiProvider({required Dio dio, String? endpoint})
    : _dio = dio,
      _endpoint = endpoint ?? '${AppConfig.backendUrl}/api/ai/coaching-wording';

  @override
  Future<Object?> request(B04OptionalAiRedactedEnvelope envelope) async {
    final response = await _dio.post(_endpoint, data: envelope.toJson());
    if (response.statusCode != 200) {
      throw StateError('The optional AI provider returned an HTTP failure.');
    }
    return response.data;
  }
}

/// The provider envelope is intentionally narrower than the deterministic
/// evaluation's own redacted map. In particular, it omits user identity,
/// explanation text, exact target values, ranges, food labels, safety IDs,
/// raw health/allergy data, prompts, images, and catalogue payloads.
class B04OptionalAiRedactedEnvelope {
  final String evaluationFingerprint;
  final String contextFingerprint;
  final B04RecommendationEvaluationScope scope;
  final B04RecommendationPeriod period;
  final String startLocalDate;
  final String endLocalDate;
  final String policyVersion;
  final List<Map<String, dynamic>> recommendations;
  final Map<String, String> recommendationIdByToken;
  final Map<String, String> approvedWordingByToken;

  const B04OptionalAiRedactedEnvelope({
    required this.evaluationFingerprint,
    required this.contextFingerprint,
    required this.scope,
    required this.period,
    required this.startLocalDate,
    required this.endLocalDate,
    required this.policyVersion,
    required this.recommendations,
    this.recommendationIdByToken = const {},
    this.approvedWordingByToken = const {},
  });

  factory B04OptionalAiRedactedEnvelope.fromEvaluation(
    B04RecommendationEvaluation evaluation,
  ) {
    final recommendationIdByToken = <String, String>{};
    final approvedWordingByToken = <String, String>{};
    final recommendations = <Map<String, dynamic>>[];
    var tokenIndex = 0;
    for (final recommendation in evaluation.recommendations) {
      if (!_isWordingEligible(recommendation)) continue;
      final token = 'recommendation-${++tokenIndex}';
      recommendationIdByToken[token] = recommendation.id;
      approvedWordingByToken[token] = recommendation.explanation;
      recommendations.add(_recommendationMap(recommendation, token: token));
    }
    return B04OptionalAiRedactedEnvelope(
      evaluationFingerprint: evaluation.fingerprint,
      contextFingerprint: evaluation.contextFingerprint,
      scope: evaluation.scope,
      period: evaluation.period,
      startLocalDate: evaluation.startLocalDate,
      endLocalDate: evaluation.endLocalDate,
      policyVersion: evaluation.policyVersion,
      recommendations: List.unmodifiable(recommendations),
      recommendationIdByToken: Map.unmodifiable(recommendationIdByToken),
      approvedWordingByToken: Map.unmodifiable(approvedWordingByToken),
    );
  }

  Map<String, dynamic> toJson() => {
    'envelope_version': kB04OptionalAiEnvelopeVersion,
    'evaluation_fingerprint': evaluationFingerprint,
    'context_fingerprint': contextFingerprint,
    'scope': scope.stableId,
    'period': period.stableId,
    'start_local_date': startLocalDate,
    'end_local_date': endLocalDate,
    'policy_version': policyVersion,
    'recommendations': recommendations,
  };
}

abstract interface class B04OptionalAiConsentReader {
  Future<bool> isOptionalAiEnabled({required String userId, DateTime? atUtc});
}

/// Production consent reader backed by the append-only optional-AI consent
/// event stream. The mutable preference row is never used as authority.
class CoachingPreferenceOptionalAiConsentReader
    implements B04OptionalAiConsentReader {
  final CoachingPreferenceRepository _preferences;

  const CoachingPreferenceOptionalAiConsentReader(
    CoachingPreferenceRepository preferences,
  ) : _preferences = preferences;

  @override
  Future<bool> isOptionalAiEnabled({
    required String userId,
    DateTime? atUtc,
  }) async {
    final current = await _preferences.currentPreferences(
      userId: userId,
      atUtc: atUtc,
    );
    return current.optionalAiEnabled;
  }
}

enum B04OptionalAiAssistanceStatus {
  applied,
  noDeterministicResult,
  consentRequired,
  consentUnavailable,
  offline,
  providerUnavailable,
  malformedResponse,
}

extension B04OptionalAiAssistanceStatusId on B04OptionalAiAssistanceStatus {
  String get stableId => name;
}

class B04OptionalAiAssistanceResult {
  final B04RecommendationEvaluation? deterministicEvaluation;
  final B04OptionalAiAssistanceStatus status;
  final String reasonCode;
  final Map<String, String> wordingByRecommendationId;
  final String? providerVersion;

  B04OptionalAiAssistanceResult({
    required this.deterministicEvaluation,
    required this.status,
    required this.reasonCode,
    Map<String, String> wordingByRecommendationId = const {},
    this.providerVersion,
  }) : wordingByRecommendationId = Map.unmodifiable(wordingByRecommendationId);

  bool get deterministicAuthorityPreserved => deterministicEvaluation != null;
}

/// Optional AI wording is a post-processing adapter. It cannot be used to
/// calculate or mutate a target, safety result, identity, ranking, evidence,
/// range, completeness, availability, confidence, or historical record.
class B04OptionalAiAssistanceService {
  final B04OptionalAiConsentReader _consent;
  final B04OptionalAiProvider _provider;
  final PrivacyPolicy _privacyPolicy;

  const B04OptionalAiAssistanceService({
    required B04OptionalAiConsentReader consent,
    required B04OptionalAiProvider provider,
    required PrivacyPolicy privacyPolicy,
  }) : _consent = consent,
       _provider = provider,
       _privacyPolicy = privacyPolicy;

  Future<B04OptionalAiAssistanceResult> assist({
    required B04RecommendationEvaluation? deterministicEvaluation,
    DateTime? atUtc,
  }) async {
    if (deterministicEvaluation == null) {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: null,
        status: B04OptionalAiAssistanceStatus.noDeterministicResult,
        reasonCode: 'deterministic_result_required',
      );
    }

    final evaluation = deterministicEvaluation;
    final consentEnabled = await _readConsent(
      userId: evaluation.userId,
      atUtc: atUtc,
    );
    if (consentEnabled == null) {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.consentUnavailable,
        reasonCode: 'ai_consent_unavailable',
      );
    }
    if (!consentEnabled) {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.consentRequired,
        reasonCode: 'ai_consent_required',
      );
    }
    if (_privacyPolicy.isOfflineOnly) {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.offline,
        reasonCode: 'ai_offline',
      );
    }

    final envelope = B04OptionalAiRedactedEnvelope.fromEvaluation(evaluation);
    Object? rawResponse;
    try {
      rawResponse = await _provider.request(envelope);
    } on Object {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.providerUnavailable,
        reasonCode: 'ai_provider_unavailable',
      );
    }

    try {
      final response = B04OptionalAiWordingResponse.parse(
        raw: rawResponse,
        expectedFingerprint: evaluation.fingerprint,
        allowedRecommendationIds: envelope.recommendationIdByToken.keys.toSet(),
        approvedWordingByRecommendationId: envelope.approvedWordingByToken,
      );
      final wordingByRecommendationId = <String, String>{};
      for (final suggestion in response.suggestions) {
        final recommendationId =
            envelope.recommendationIdByToken[suggestion.recommendationId];
        if (recommendationId == null) {
          throw const FormatException(
            'AI wording token has no local recommendation identity.',
          );
        }
        wordingByRecommendationId[recommendationId] = suggestion.wording;
      }
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.applied,
        reasonCode: 'ai_wording_applied',
        wordingByRecommendationId: wordingByRecommendationId,
        providerVersion: response.providerVersion,
      );
    } on Object {
      return B04OptionalAiAssistanceResult(
        deterministicEvaluation: evaluation,
        status: B04OptionalAiAssistanceStatus.malformedResponse,
        reasonCode: 'ai_response_discarded',
      );
    }
  }

  Future<bool?> _readConsent({
    required String userId,
    required DateTime? atUtc,
  }) async {
    try {
      return await _consent.isOptionalAiEnabled(userId: userId, atUtc: atUtc);
    } on Object {
      return null;
    }
  }
}

Map<String, dynamic> _recommendationMap(
  B04Recommendation recommendation, {
  required String token,
}) {
  return {
    'id': token,
    'action': recommendation.action.stableId,
    'state': recommendation.state.stableId,
    'priority': recommendation.priority.stableId,
    'confidence': recommendation.confidence.stableId,
    'completeness': recommendation.completeness.stableId,
    'eligibility_state': recommendation.eligibilityState.stableId,
    'consent_state': recommendation.consentState.stableId,
    'policy_state': recommendation.policyState.stableId,
    'target_acceptance_state': recommendation.targetAcceptanceState.stableId,
    'wording_allowed': true,
  };
}

bool _isWordingEligible(B04Recommendation recommendation) =>
    recommendation.state == B04RecommendationState.available ||
        recommendation.state == B04RecommendationState.cautious ||
        recommendation.state == B04RecommendationState.confirm
    ? (recommendation.action == B04RecommendationAction.training ||
              recommendation.action == B04RecommendationAction.education) &&
          recommendation.safetyDisposition == null
    : false;

String _validatedWording(Object? value, {required String approvedWording}) {
  if (value is! String) {
    throw const FormatException('AI wording must be text.');
  }
  final wording = value.trim();
  if (wording.isEmpty || wording != approvedWording.trim()) {
    throw const FormatException(
      'AI wording must match the deterministic approved explanation.',
    );
  }
  return wording;
}

void _requireExactKeys(Map<String, dynamic> map, Set<String> expected) {
  if (!map.keys.toSet().containsAll(expected) ||
      !expected.containsAll(map.keys.toSet())) {
    throw const FormatException('AI payload contains unsupported fields.');
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('AI field $key must be a non-empty string.');
  }
  return value.trim();
}
