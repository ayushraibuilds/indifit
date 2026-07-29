import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/equipment_preference_repository.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_repository.dart';
import '../../data/repositories/travel_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';
import '../config/app_config.dart';
import '../privacy/privacy_policy.dart';
import '../services/local_schedule_date_service.dart';

export 'user_profile_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final dioProvider = Provider<Dio>((ref) {
  // AppConfig.apiKey validates the build key and throws a deterministic StateError
  // in BOTH debug and release modes if missing, ensuring release builds never
  // silently ship with an unconfigured empty key.
  final apiKey = AppConfig.apiKey;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'x-indifit-key': apiKey},
    ),
  );
  dio.interceptors.add(PrivacyNetworkInterceptor(ref));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(responseBody: false, requestBody: false),
    );
  }
  return dio;
});

class PrivacyNetworkInterceptor extends Interceptor {
  final Ref _ref;
  PrivacyNetworkInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final policy = _ref.read(privacyPolicyProvider);
    if (policy.isOfflineOnly) {
      handler.reject(
        DioException(
          requestOptions: options,
          error:
              'Outbound network call blocked by strict offline privacy policy.',
          type: DioExceptionType.cancel,
        ),
      );
      return;
    }
    handler.next(options);
  }
}

// Shared state for hydration goals & progress
class WaterState {
  final int waterLogged;
  final int waterGoal;
  final String lastLoggedDate;
  final int glassSize; // glass capacity in ml (default: 250)

  WaterState({
    required this.waterLogged,
    required this.waterGoal,
    required this.lastLoggedDate,
    required this.glassSize,
  });

  WaterState copyWith({
    int? waterLogged,
    int? waterGoal,
    String? lastLoggedDate,
    int? glassSize,
  }) {
    return WaterState(
      waterLogged: waterLogged ?? this.waterLogged,
      waterGoal: waterGoal ?? this.waterGoal,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      glassSize: glassSize ?? this.glassSize,
    );
  }
}

class WaterNotifier extends StateNotifier<WaterState> {
  final AppDatabase? _db;
  Timer? _timer;

  WaterNotifier([this._db])
    : super(
        WaterState(
          waterLogged: 0,
          waterGoal: 8,
          lastLoggedDate: '',
          glassSize: 250,
        ),
      ) {
    loadState();
    // Periodic check every 15 seconds to support midnight resets if app is left open
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkMidnightReset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkMidnightReset() async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (state.lastLoggedDate.isNotEmpty && state.lastLoggedDate != todayStr) {
      await loadState();
    }
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    int goal = prefs.getInt('water_goal') ?? 8;
    int size = prefs.getInt('water_glass_size') ?? 250;
    int logged = 0;

    var hydratedFromDatabase = false;
    if (_db != null) {
      try {
        final record = await (_db.select(
          _db.dailyHydrations,
        )..where((tbl) => tbl.dateString.equals(todayStr))).getSingleOrNull();
        hydratedFromDatabase = true;
        if (record != null) {
          // The UI is glass-based, while the durable history is millilitre-based.
          // Round only for presentation; the database retains the precise total.
          logged = (record.totalMl / size).round();
          goal = (record.goalMl / size).round();
        }
      } catch (_) {
        // Keep the tracker usable when the database is still opening. The
        // preference mirror is only a temporary compatibility fallback.
      }
    }
    if (!hydratedFromDatabase) {
      final savedDate = prefs.getString('water_last_logged_date') ?? todayStr;
      if (savedDate == todayStr) {
        logged = prefs.getInt('water_logged') ?? 0;
      }
    }

    await prefs.setInt('water_logged', logged);
    await prefs.setString('water_last_logged_date', todayStr);

    if (!mounted) return;
    state = WaterState(
      waterLogged: logged,
      waterGoal: goal,
      lastLoggedDate: todayStr,
      glassSize: size,
    );
  }

  Future<void> logWater(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    int currentLogged = state.waterLogged;

    if (state.lastLoggedDate != todayStr) {
      currentLogged = 0;
      await prefs.setString('water_last_logged_date', todayStr);
    }

    final newLogged = (currentLogged + amount).clamp(0, 100);
    await prefs.setInt('water_logged', newLogged);
    await prefs.setString('water_last_logged_date', todayStr);

    if (_db != null) {
      final totalMl = newLogged * state.glassSize;
      final goalMl = state.waterGoal * state.glassSize;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: totalMl,
              goalMl: goalMl,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    state = state.copyWith(waterLogged: newLogged, lastLoggedDate: todayStr);
  }

  Future<void> updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', newGoal);
    if (_db != null) {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final totalMl = state.waterLogged * state.glassSize;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: totalMl,
              goalMl: newGoal * state.glassSize,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    state = state.copyWith(waterGoal: newGoal);
  }

  Future<void> updateGlassSize(int newSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_glass_size', newSize);
    if (_db != null) {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: state.waterLogged * newSize,
              goalMl: state.waterGoal * newSize,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    state = state.copyWith(glassSize: newSize);
  }
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  return WaterNotifier(ref.watch(databaseProvider));
});

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepository(ref.watch(databaseProvider));
});

final localScheduleDateServiceProvider = Provider<LocalScheduleDateService>((
  ref,
) {
  return LocalScheduleDateService();
});

final programActivationCoordinatorProvider =
    Provider<ProgramActivationCoordinator>((ref) {
      return ProgramActivationCoordinator(
        ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
    });

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final calendarReadRepositoryProvider = Provider<CalendarReadRepository>((ref) {
  return CalendarReadRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final equipmentProfileRepositoryProvider = Provider<EquipmentProfileRepository>(
  (ref) {
    return EquipmentProfileRepository(ref.watch(databaseProvider));
  },
);

/// Compatibility alias for callers not yet migrated to the bounded-context
/// name. It is the same provider/owner, not a second authority.
final equipmentRepositoryProvider = equipmentProfileRepositoryProvider;

final exercisePreferenceRepositoryProvider =
    Provider<ExercisePreferenceRepository>((ref) {
      return ExercisePreferenceRepository(ref.watch(databaseProvider));
    });

final programListProvider = StreamProvider<List<Program>>((ref) {
  return ref.watch(programRepositoryProvider).watchAllPrograms();
});

final programVersionDetailProvider =
    StreamProvider.family<ProgramDetailAggregate?, String>((ref, versionId) {
      return ref
          .watch(programRepositoryProvider)
          .watchProgramVersionDetail(versionId);
    });

final equipmentProfileListProvider = StreamProvider<List<EquipmentProfile>>((
  ref,
) {
  return ref.watch(equipmentProfileRepositoryProvider).watchActiveProfiles();
});

final defaultEquipmentProfileIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(equipmentProfileRepositoryProvider).watchDefaultProfileId();
});

final exercisePreferenceAggregateProvider =
    StreamProvider.family<
      ExercisePreferenceAggregate?,
      ExercisePreferenceLookup
    >((ref, lookup) {
      return ref
          .watch(exercisePreferenceRepositoryProvider)
          .watchPreference(stableId: lookup.stableId, rawName: lookup.rawName);
    });

final workoutExecutionCompatibilityAdapterProvider =
    Provider<WorkoutExecutionCompatibilityAdapter>((ref) {
      return WorkoutExecutionCompatibilityAdapter(
        db: ref.watch(databaseProvider),
        calendarRepo: ref.watch(calendarRepositoryProvider),
        workoutRepo: ref.watch(workoutRepositoryProvider),
        preferenceRepo: ref.watch(exercisePreferenceRepositoryProvider),
        travelRepo: ref.watch(travelRepositoryProvider),
      );
    });

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepository(
    db: ref.watch(databaseProvider),
    calendarRepo: ref.watch(calendarRepositoryProvider),
    equipmentRepo: ref.watch(equipmentProfileRepositoryProvider),
  );
});
