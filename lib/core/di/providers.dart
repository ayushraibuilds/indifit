import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: false));
  }
  return dio;
});

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
  Timer? _timer;

  WaterNotifier() : super(WaterState(waterLogged: 0, waterGoal: 8, lastLoggedDate: '', glassSize: 250)) {
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
    final savedDate = prefs.getString('water_last_logged_date') ?? todayStr;
    
    int logged = prefs.getInt('water_logged') ?? 0;
    int goal = prefs.getInt('water_goal') ?? 8;
    int size = prefs.getInt('water_glass_size') ?? 250;
    
    if (savedDate != todayStr) {
      logged = 0;
      await prefs.setInt('water_logged', 0);
      await prefs.setString('water_last_logged_date', todayStr);
    }
    
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
    
    state = state.copyWith(
      waterLogged: newLogged,
      lastLoggedDate: todayStr,
    );
  }

  Future<void> updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', newGoal);
    state = state.copyWith(waterGoal: newGoal);
  }

  Future<void> updateGlassSize(int newSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_glass_size', newSize);
    state = state.copyWith(glassSize: newSize);
  }
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  return WaterNotifier();
});
