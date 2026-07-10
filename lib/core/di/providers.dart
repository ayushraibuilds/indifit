import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Shared state for hydration goals & progress
class WaterState {
  final int waterLogged;
  final int waterGoal;
  final String lastLoggedDate;

  WaterState({
    required this.waterLogged,
    required this.waterGoal,
    required this.lastLoggedDate,
  });

  WaterState copyWith({
    int? waterLogged,
    int? waterGoal,
    String? lastLoggedDate,
  }) {
    return WaterState(
      waterLogged: waterLogged ?? this.waterLogged,
      waterGoal: waterGoal ?? this.waterGoal,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
    );
  }
}

class WaterNotifier extends StateNotifier<WaterState> {
  WaterNotifier() : super(WaterState(waterLogged: 0, waterGoal: 8, lastLoggedDate: '')) {
    loadState();
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final savedDate = prefs.getString('water_last_logged_date') ?? todayStr;
    
    int logged = prefs.getInt('water_logged') ?? 0;
    int goal = prefs.getInt('water_goal') ?? 8;
    
    if (savedDate != todayStr) {
      logged = 0;
      await prefs.setInt('water_logged', 0);
      await prefs.setString('water_last_logged_date', todayStr);
    }
    
    state = WaterState(
      waterLogged: logged,
      waterGoal: goal,
      lastLoggedDate: todayStr,
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
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  return WaterNotifier();
});
