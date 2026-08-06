import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../../core/services/local_timezone_service.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/services/b04_recommendation_context_assembler.dart';

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
  final NutritionGoalRepository _goals;
  final CoachingPreferenceRepository _preferences;
  final LocalScheduleDateService _dates;
  final B04RecommendationContextAssembler _assembler;

  B04ProductionRecommendationContextLoader({
    required B04ProductionUserContextLoader users,
    required NutritionGoalRepository goals,
    required CoachingPreferenceRepository preferences,
    required LocalScheduleDateService dates,
    B04RecommendationContextAssembler? assembler,
  }) : _users = users,
       _goals = goals,
       _preferences = preferences,
       _dates = dates,
       _assembler = assembler ?? B04RecommendationContextAssembler();

  Future<B04RecommendationContext> load() async {
    final user = await _users.load();
    final activeGoal = await _goals.activeGoal(
      userId: user.userId,
      localDate: user.localDate,
      timezoneId: user.timezoneId,
    );
    final preferences = await _preferences.currentPreferences(
      userId: user.userId,
    );
    final eligibility = await _preferences.currentEligibility(
      userId: user.userId,
    );
    return _assembler.assemble(
      B04RecommendationContextInput(
        contextId: 'b04-production-current-food:${user.localDate}',
        userId: user.userId,
        period: B04RecommendationPeriod.daily,
        startLocalDate: user.localDate,
        endLocalDate: user.localDate,
        timezoneId: user.timezoneId,
        evaluatedAtUtc: DateTime.now().toUtc(),
        activeGoal: activeGoal,
        preferences: preferences,
        eligibility: eligibility,
        readinessSnapshot: null,
        progress: null,
        schedule: null,
        nutritionDays: const [],
        constraintEvaluations: null,
        targetResult: null,
        mealOpportunity: null,
      ),
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
        errorMessage:
            typed?.message ??
            'Coaching settings could not be loaded. You can retry.',
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
  'coaching_unavailable_age' || 'underage' =>
    'Adaptive coaching is unavailable for this age state. Logging, history and user-set targets remain available.',
  'unknown_age' || 'withheld_age' || 'conflicting_age' || 'invalid_evidence' =>
    'Adaptive coaching is unavailable until age eligibility is verified. No target is inferred or changed.',
  'adaptive_policy_hold' =>
    'Adaptive target proposals are unavailable while the current policy is on hold. Your user-set target is unchanged.',
  'eligibility_unavailable' =>
    'Adaptive coaching is unavailable because age eligibility has not been recorded.',
  'goal_unavailable' =>
    'A canonical goal version is unavailable. Set a user target to continue.',
  'readiness_incomplete' =>
    'Readiness evidence is incomplete. No readiness-based change is presented.',
  'dietary_safety_evidence_missing' ||
  'dietary_evidence_missing' ||
  'dietary_safety_scope_mismatch' ||
  'possible_conflict' ||
  'unknown_conflict' ||
  'missing_ingredient_evidence' ||
  'possible_cross_contact' =>
    'Safety-sensitive guidance is unavailable because dietary evidence is missing or uncertain.',
  _ =>
    'This guidance is unavailable because the required evidence is incomplete.',
};

String b04ProductionStateLabel(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
