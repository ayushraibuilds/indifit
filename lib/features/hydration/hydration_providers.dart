import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/core_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/hydration_repository.dart';

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
  final HydrationRepository _repo;
  final SharedPreferences? _prefsInstance;
  Timer? _timer;

  WaterNotifier([
    AppDatabase? db,
    HydrationRepository? repo,
    SharedPreferences? prefs,
  ])  : _db = db,
        _repo = repo ?? HydrationRepository(db, prefs: prefs),
        _prefsInstance = prefs,
        super(
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

  Future<SharedPreferences> _getPrefs() async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkMidnightReset() async {
    final todayStr = HydrationRepository.currentLocalDateKey();
    if (state.lastLoggedDate.isNotEmpty && state.lastLoggedDate != todayStr) {
      await loadState();
    }
  }

  Future<void> loadState() async {
    final prefs = await _getPrefs();
    final todayStr = HydrationRepository.currentLocalDateKey();
    int size = prefs.getInt(HydrationRepository.prefWaterGlassSize) ?? 250;
    if (size <= 0) size = 250;

    int goal = prefs.getInt(HydrationRepository.prefWaterGoal) ?? 8;
    int logged = 0;

    if (_db != null) {
      try {
        final daily = await _repo.getDailyHydration(todayStr);
        logged = (daily.totalMl / size).round();
        goal = (daily.goalMl / size).round().clamp(1, 100);
      } catch (_) {
        // Keep the tracker usable when the database is still opening.
        final savedDate =
            prefs.getString(HydrationRepository.prefWaterLastLoggedDate) ??
            todayStr;
        if (savedDate == todayStr) {
          logged = prefs.getInt(HydrationRepository.prefWaterLogged) ?? 0;
        }
      }
    } else {
      final savedDate =
          prefs.getString(HydrationRepository.prefWaterLastLoggedDate) ??
          todayStr;
      if (savedDate == todayStr) {
        logged = prefs.getInt(HydrationRepository.prefWaterLogged) ?? 0;
      }
    }

    await prefs.setInt(HydrationRepository.prefWaterLogged, logged);
    await prefs.setString(
      HydrationRepository.prefWaterLastLoggedDate,
      todayStr,
    );

    if (!mounted) return;
    state = WaterState(
      waterLogged: logged,
      waterGoal: goal,
      lastLoggedDate: todayStr,
      glassSize: size,
    );
  }

  Future<void> logWater(int amount) async {
    if (amount == 0) return;
    final todayStr = HydrationRepository.currentLocalDateKey();

    if (amount > 0) {
      final amountMl = amount * state.glassSize;
      await _repo.logIntake(
        localDate: todayStr,
        amountMl: amountMl,
        source: 'quickAdd',
        containerType: 'glass',
      );
    } else {
      final glassesToRemove = -amount;
      for (int i = 0; i < glassesToRemove; i++) {
        await _repo.deleteLatestIntakeEntry(
          todayStr,
          containerType: 'glass',
          amountMl: state.glassSize,
        );
      }
    }

    await loadState();
  }

  Future<void> updateGoal(int newGoal) async {
    final prefs = await _getPrefs();
    await prefs.setInt(HydrationRepository.prefWaterGoal, newGoal);
    final goalMl = newGoal * state.glassSize;
    await _repo.setDailyGoal(goalMl: goalMl);
    state = state.copyWith(waterGoal: newGoal);
  }

  Future<void> updateGlassSize(int newSize) async {
    await _repo.updateGlassSize(newSize);
    state = state.copyWith(glassSize: newSize);
  }
}

final hydrationRepositoryProvider = Provider<HydrationRepository>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return HydrationRepository(
    ref.watch(databaseProvider),
    prefs: prefs,
    dateService: ref.watch(localScheduleDateServiceProvider),
  );
});

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return WaterNotifier(
    ref.watch(databaseProvider),
    ref.watch(hydrationRepositoryProvider),
    prefs,
  );
});
