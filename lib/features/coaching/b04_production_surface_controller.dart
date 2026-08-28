import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/services/local_timezone_service.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/services/b04_production_recommendation_orchestrator.dart';

/// Version identifiers for the reviewed adaptive-coaching disclosure.
///
/// The UI persists these identifiers with consent events; it never persists
/// the disclosure text itself.
const String kB04AdaptiveConsentPolicyVersion = 'B04-D04-04-CONSENT-V1';
const String kB04AdaptiveConsentCopyVersion = 'B04-D04-04-COACHING-COPY-V1';

class B04ProductionUserContext {
  final String userId;
  final String localDate;
  final String timezoneId;

  const B04ProductionUserContext({
    required this.userId,
    required this.localDate,
    required this.timezoneId,
  });
}

class B04ProductionUserContextLoader {
  final AppDatabase _database;
  final LocalScheduleDateService _dates;
  final LocalTimezoneService _timezones;

  const B04ProductionUserContextLoader({
    required AppDatabase database,
    required LocalScheduleDateService dates,
    required LocalTimezoneService timezones,
  }) : _database = database,
       _dates = dates,
       _timezones = timezones;

  Future<B04ProductionUserContext> load() async {
    final profiles = await _database.select(_database.userProfiles).get();
    if (profiles.isEmpty) {
      throw const B04ProductionSurfaceError(
        'profile_unavailable',
        'Your profile is not ready yet. Try again after setup finishes.',
      );
    }
    final timezoneId = await _timezones.currentTimezoneId();
    return B04ProductionUserContext(
      userId: profiles.first.id.toString(),
      localDate: _dates.todayIn(timezoneId),
      timezoneId: timezoneId,
    );
  }
}

/// Builds the production read boundary for the current-food card. It supplies
/// only already-owned local state; absent nutrition, safety and meal evidence
/// intentionally remains unavailable rather than being filled with defaults.
class B04ProductionRecommendationContextLoader {
  final B04ProductionUserContextLoader _users;
  final LocalScheduleDateService _dates;
  final String _nutritionUserId;
  final Future<B04ProductionRecommendationOrchestrator> Function()
  _loadOrchestrator;

  B04ProductionRecommendationContextLoader({
    required B04ProductionUserContextLoader users,
    required LocalScheduleDateService dates,
    String nutritionUserId = kLocalNutritionUserScopeId,
    required Future<B04ProductionRecommendationOrchestrator> Function()
    loadOrchestrator,
  }) : _users = users,
       _dates = dates,
       _nutritionUserId = nutritionUserId,
       _loadOrchestrator = loadOrchestrator;

  Future<B04RecommendationContext> load() async {
    final user = await _users.load();
    return (await _loadOrchestrator()).loadCurrentFoodContext(
      userId: user.userId,
      nutritionUserId: _nutritionUserId,
      localDate: user.localDate,
      timezoneId: user.timezoneId,
    );
  }

  String weekStartFor(B04ProductionUserContext context) =>
      _dates.addCalendarDays(context.localDate, context.timezoneId, -6);
}

enum B04GoalSettingsStatus { idle, loading, ready, failure }

class B04GoalSettingsState {
  final B04GoalSettingsStatus status;
  final B04ProductionUserContext? context;
  final NutritionGoalVersionReadModel? activeGoal;
  final List<NutritionGoalVersionReadModel> goalHistory;
  final CoachingAvailabilityReadModel? availability;
  final List<CoachingConsentEventReadModel> consentHistory;
  final String? errorCode;
  final String? errorMessage;

  const B04GoalSettingsState({
    this.status = B04GoalSettingsStatus.idle,
    this.context,
    this.activeGoal,
    this.goalHistory = const [],
    this.availability,
    this.consentHistory = const [],
    this.errorCode,
    this.errorMessage,
  });

  bool get isLoading => status == B04GoalSettingsStatus.loading;

  B04GoalSettingsState copyWith({
    B04GoalSettingsStatus? status,
    Object? context = _unset,
    Object? activeGoal = _unset,
    List<NutritionGoalVersionReadModel>? goalHistory,
    Object? availability = _unset,
    List<CoachingConsentEventReadModel>? consentHistory,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
  }) => B04GoalSettingsState(
    status: status ?? this.status,
    context: context == _unset
        ? this.context
        : context as B04ProductionUserContext?,
    activeGoal: activeGoal == _unset
        ? this.activeGoal
        : activeGoal as NutritionGoalVersionReadModel?,
    goalHistory: goalHistory ?? this.goalHistory,
    availability: availability == _unset
        ? this.availability
        : availability as CoachingAvailabilityReadModel?,
    consentHistory: consentHistory ?? this.consentHistory,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
  );
}

const _unset = Object();

class B04ProductionSurfaceError implements Exception {
  final String code;
  final String message;

  const B04ProductionSurfaceError(this.code, this.message);

  @override
  String toString() => 'B04ProductionSurfaceError($code): $message';
}

/// State owner for the settings/goal surface. Goal versions and consent
/// events are read and written only through their canonical repositories.
class B04GoalSettingsController extends StateNotifier<B04GoalSettingsState> {
  final Future<B04ProductionUserContext> Function() _loadContext;
  final NutritionGoalRepository _goals;
  final CoachingPreferenceRepository _preferences;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;

  B04GoalSettingsController({
    required Future<B04ProductionUserContext> Function() loadContext,
    required NutritionGoalRepository goals,
    required CoachingPreferenceRepository preferences,
    required LocalScheduleDateService dates,
    DateTime Function()? nowUtc,
  }) : _loadContext = loadContext,
       _goals = goals,
       _preferences = preferences,
       _dates = dates,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       super(const B04GoalSettingsState());

  Future<void> load({DateTime? atUtc}) async {
    state = state.copyWith(
      status: B04GoalSettingsStatus.loading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final context = await _loadContext();
      final activeGoal = await _goals.activeGoal(
        userId: context.userId,
        localDate: context.localDate,
        timezoneId: context.timezoneId,
      );
      final goalHistory = await _goals.listVersions(userId: context.userId);
      final availability = await _preferences.adaptiveAvailability(
        userId: context.userId,
        atUtc: atUtc,
      );
      final consentHistory = await _preferences.listConsentHistory(
        userId: context.userId,
        category: CoachingConsentCategory.adaptiveCoaching,
      );
      if (!mounted) return;
      state = B04GoalSettingsState(
        status: B04GoalSettingsStatus.ready,
        context: context,
        activeGoal: activeGoal,
        goalHistory: goalHistory,
        availability: availability,
        consentHistory: consentHistory,
      );
    } catch (error) {
      if (!mounted) return;
      final typed = error is B04ProductionSurfaceError ? error : null;
      state = state.copyWith(
        status: B04GoalSettingsStatus.failure,
        errorCode: typed?.code ?? 'b04_settings_load_failed',
        errorMessage: ProductFailurePresentation.fromCode(
          typed?.code,
          title: 'Coaching settings unavailable',
        ).message,
      );
    }
  }

  Future<void> saveUserSetGoal({
    required NutritionGoalType goalType,
    required int calorieTargetKcal,
    required double proteinTargetG,
    required double carbsTargetG,
    required double fatTargetG,
    String? commandId,
  }) async {
    final context = state.context;
    if (context == null) return;
    await _goals.recordUserSetGoal(
      NutritionGoalCommand(
        userId: context.userId,
        goalType: goalType,
        calorieTargetKcal: calorieTargetKcal,
        proteinTargetG: proteinTargetG,
        carbsTargetG: carbsTargetG,
        fatTargetG: fatTargetG,
        effectiveFromLocalDate: context.localDate,
        timezoneId: context.timezoneId,
        commandId: commandId,
      ),
    );
    await load();
  }

  Future<void> setAdaptiveConsent(CoachingConsentAction action) async {
    final context = state.context;
    if (context == null) return;
    final prior = state.availability?.preferences.adaptiveCoachingEvent;
    if (prior?.action == action) return;
    final timestampUtc = _nextConsentTimestamp(prior);
    await _preferences.recordConsent(
      CoachingConsentCommand(
        userId: context.userId,
        category: CoachingConsentCategory.adaptiveCoaching,
        action: action,
        consentPolicyVersion: kB04AdaptiveConsentPolicyVersion,
        copyVersion: kB04AdaptiveConsentCopyVersion,
        timestampUtc: timestampUtc,
        localDate: context.localDate,
        timezoneId: context.timezoneId,
        actorSource: 'settings',
        relatedOrSupersededEventId: prior?.id,
      ),
    );
    await load(atUtc: timestampUtc);
  }

  /// Records explicit age evidence through the B04 append-only authority.
  /// Blank input is an explicit missing-age evaluation; malformed input is
  /// retained as invalid evidence rather than falling back to profile age.
  Future<void> recordEligibility({String? dateOfBirthLocalDate}) async {
    final context = state.context;
    if (context == null) return;
    final entered = dateOfBirthLocalDate?.trim() ?? '';
    final hasValue = entered.isNotEmpty;
    final validFormat =
        hasValue && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entered);
    var validCivilDate = false;
    if (validFormat) {
      try {
        _dates.normalizeLocalDate(entered);
        validCivilDate = true;
      } catch (_) {
        // Keep malformed civil dates as an explicit invalid evaluation rather
        // than retaining a previously eligible state.
      }
    }
    final source = !hasValue
        ? CoachingAgeEvidenceSource.missing
        : validCivilDate
        ? CoachingAgeEvidenceSource.userEnteredDob
        : CoachingAgeEvidenceSource.invalid;
    final dateOfBirth = source == CoachingAgeEvidenceSource.userEnteredDob
        ? entered
        : null;
    final timestamp = _nowUtc().toUtc();
    final recorded = await _preferences.recordEligibility(
      CoachingEligibilityCommand(
        userId: context.userId,
        dateOfBirthLocalDate: dateOfBirth,
        source: source,
        localDate: context.localDate,
        timezoneId: context.timezoneId,
        evidenceTimestampUtc: timestamp,
        evaluationUtc: timestamp,
      ),
    );
    // The repository may advance a same-timestamp correction by one second
    // to preserve append-only ordering. Reload at the durable evaluation
    // instant so the UI cannot project the prior eligibility row.
    await load(atUtc: recorded.evaluationUtc);
  }

  DateTime _nextConsentTimestamp(CoachingConsentEventReadModel? prior) {
    final now = _nowUtc().toUtc();
    if (prior == null || now.isAfter(prior.timestampUtc)) return now;
    // The durable SQLite timestamp representation is second-precision. Keep
    // the append-only related-event order valid even when the injected clock
    // returns the same instant for consecutive UI commands.
    return prior.timestampUtc.add(const Duration(seconds: 1));
  }

  String weekStartFor(B04ProductionUserContext context) =>
      _dates.addCalendarDays(context.localDate, context.timezoneId, -6);
}

/// Presentation-safe copy for B04 state keys. Numerical and safety states
/// remain owned by the read models; this catalog only maps reviewed wording.
String b04ProductionStateCopy(String reasonCode) => switch (reasonCode) {
  'coaching_consent_required' =>
    'Adaptive coaching is off. Review the disclosure before enabling it.',
  'adaptive_consent_disabled' || 'adaptive_consent_missing' =>
    'Adaptive coaching is off. Review the disclosure before enabling it.',
  'coaching_unavailable_age' || 'underage' =>
    'Coaching suggestions are unavailable for this age. Your logged activity and target remain available.',
  'unknown_age' || 'withheld_age' =>
    'Add your date of birth to check whether adaptive coaching is available. Your target stays the same.',
  'conflicting_age' || 'invalid_evidence' =>
    'Coaching availability couldn\'t be checked from those age details. Check your date of birth and try again. Your target stays the same.',
  'eligibility_underage' =>
    'Coaching suggestions are unavailable for this age. Your logged activity and target remain available.',
  'eligibility_unknown_age' || 'eligibility_withheld_age' =>
    'Add your date of birth to check whether adaptive coaching is available. Your target stays the same.',
  'eligibility_conflicting_age' || 'eligibility_invalid_evidence' =>
    'Coaching availability couldn\'t be checked from those age details. Check your date of birth and try again. Your target stays the same.',
  'eligibility_policy_unavailable' =>
    'Coaching availability couldn\'t be checked right now. Your target stays the same.',
  'adaptive_policy_hold' =>
    'Coaching suggestions are unavailable right now. Your target stays the same.',
  'adaptive_policy_inactive' =>
    'Coaching suggestions are not active today. Your target stays the same.',
  'adaptive_policy_not_enabled' || 'adaptive_policy_scope_mismatch' =>
    'Coaching suggestions are unavailable here. Your target stays the same.',
  'unsupported_policy_version' ||
  'target_policy_unavailable' ||
  'target_policy_missing' ||
  'target_policy_lineage_mismatch' ||
  'policy_unavailable' =>
    'Target guidance is unavailable right now. Your target stays the same.',
  'policy_boundary_reached' || 'user_target_outside_supported_policy' =>
    'That change is outside the supported range. Your current target stays the same.',
  'rapid_change_review' =>
    'Recent changes need a quick review before coaching suggestions are shown. Your current target stays the same.',
  'unsupported_goal_rate' ||
  'unsupported_goal_type' ||
  'invalid_goal_type' ||
  'invalid_policy_result' ||
  'invalid_exact_result' ||
  'missing_proposal_identity' ||
  'goal_target_invalid' ||
  'adaptive_goal_unsupported_pregnancy_or_breastfeeding' ||
  'clinician_managed_plan' =>
    'This goal or request is outside supported coaching. Your target stays the same.',
  'eligibility_unavailable' =>
    'Add your date of birth to check whether adaptive coaching is available.',
  'eligibility_not_evaluated_for_context' =>
    'Age details are unavailable for this period. Your target stays the same.',
  'goal_unavailable' || 'goal_missing' || 'goal_target_missing' =>
    'Your current goal is unavailable. Set a daily target to continue.',
  'goal_owner_mismatch' ||
  'goal_timezone_mismatch' ||
  'goal_not_effective' ||
  'goal_not_effective_for_context' =>
    'Your goal is not available for this period. Your target stays the same.',
  'readiness_incomplete' ||
  'readiness_unavailable' ||
  'readiness_incomplete_or_unavailable' ||
  'missing_readiness_evidence' =>
    'We need a little more activity information before showing a change.',
  'workload_unavailable' || 'schedule_unavailable' =>
    'We need your workout plan or recent activity before showing a change.',
  'constraint_evaluation_unavailable' || 'dietary_restriction_unavailable' =>
    'We couldn’t check your dietary preferences, so food guidance is paused.',
  'dietary_safety_evidence_missing' ||
  'dietary_evidence_missing' ||
  'dietary_safety_scope_mismatch' ||
  'possible_conflict' ||
  'unknown_conflict' ||
  'insufficient_evidence' ||
  'missing_ingredient_evidence' ||
  'possible_cross_contact' ||
  'candidate_evidence_missing' ||
  'candidate_evidence_unavailable' ||
  'candidate_evidence_unidentified' ||
  'candidate_evidence_unknown' ||
  'candidate_evidence_partial' ||
  'candidate_evidence_invalid' ||
  'candidate_nutrient_evidence_missing' ||
  'candidate_nutrient_evidence_not_applicable' ||
  'candidate_nutrient_evidence_unknown' ||
  'candidate_nutrient_evidence_partial' ||
  'candidate_nutrient_evidence_invalid' ||
  'structurally_invalid_evidence' ||
  'structurally_invalid_nutrient_evidence' ||
  'insufficient_nutrient_evidence' ||
  'nutrient_range_crosses_boundary' ||
  'nutrient_boundary_exceeded' ||
  'safety_evidence_missing' ||
  'safety_evidence_unavailable' ||
  'dietary_unavailable' ||
  'candidate_unavailable' =>
    'I need more dietary information before I can show a suggestion.',
  'daily_totals_unavailable' ||
  'daily_totals_unknown' ||
  'daily_totals_partial' ||
  'daily_totals_missing' ||
  'daily_totals_limited' ||
  'consumed_totals_partial' ||
  'consumed_totals_unknown' ||
  'nutrition_totals_unknown' ||
  'remaining_energy_missing' ||
  'remaining_energy_unknown' ||
  'remaining_energy_invalid' ||
  'candidate_energy_unknown' ||
  'candidate_nutrient_unknown' ||
  'remaining_target_unavailable' =>
    'Log a meal to see today’s nutrition totals.',
  'no_explicit_candidate' ||
  'explicit_opportunity_required' ||
  'no_candidate' ||
  'no_candidate_after_filter' =>
    'Nothing to recommend yet. Log a meal and I’ll suggest something that fits your day.',
  'target_fit_unavailable' ||
  'target_range_uncertain' ||
  'exceeds_remaining_target' =>
    'I need more nutrition information to check this option.',
  'guidance_unavailable' =>
    'Suggestions aren’t ready yet. Log a meal to continue.',
  'confirmed_conflict' ||
  'dietary_confirmed_conflict' ||
  'dietary_hard_block' ||
  'constraint_conflict' =>
    'This option doesn’t match a dietary preference you saved.',
  'medical_restriction' ||
  'medical_decision_required' ||
  'consult_professional' =>
    'This feature does not make medical or treatment decisions. Consider a qualified healthcare professional for those decisions.',
  'emergency_out_of_scope' || 'severe_symptoms_out_of_scope' =>
    'Severe or emergency symptoms are outside this feature. Seek local emergency help.',
  'no_known_conflict' =>
    'No known conflict was found in the information checked. This is not a safety guarantee.',
  _ =>
    'This guidance is unavailable because the required information is incomplete.',
};

String b04ProductionStateLabel(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
