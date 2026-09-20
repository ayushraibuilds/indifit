/// IndiFit Dependency Injection Barrel
///
/// Re-exports core infrastructure providers and domain-owned feature providers
/// decomposed from the monolithic DI layer (C3B).
library;

export '../../features/coaching/coaching_providers.dart';
export '../../features/hydration/hydration_providers.dart';
export '../../features/nutrition/nutrition_providers.dart';
export '../../features/training/training_providers.dart';
export '../../features/workout_player/workout_player_providers.dart';
export '../services/data_erasure_service.dart';
export 'core_providers.dart';
export 'user_profile_provider.dart';
export 'user_provider_invalidator.dart';
