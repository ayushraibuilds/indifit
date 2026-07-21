import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../data/repositories/food_repository.dart';

class RegionalFoodPacksScreen extends ConsumerStatefulWidget {
  const RegionalFoodPacksScreen({super.key});

  @override
  ConsumerState<RegionalFoodPacksScreen> createState() => _RegionalFoodPacksScreenState();
}

class _RegionalFoodPacksScreenState extends ConsumerState<RegionalFoodPacksScreen> {
  final Map<String, bool> _loadedPacks = {
    'south_indian': false,
    'gujarati': false,
    'bengali': false,
    'punjabi': false,
    'maharashtrian': false,
  };

  final Map<String, String> _packNames = {
    'south_indian': 'South Indian Pack',
    'gujarati': 'Gujarati Pack',
    'bengali': 'Bengali Pack',
    'punjabi': 'Punjabi Pack',
    'maharashtrian': 'Maharashtrian Pack',
  };

  final Map<String, String> _packDescriptions = {
    'south_indian': 'Includes Dosa, Idli Sambar, Medu Vada, Coconut Chutney, Tomato Rasam.',
    'gujarati': 'Includes Khaman Dhokla, Methi Thepla, Gujarati Kadhi, Undhiyu, Shrikhand.',
    'bengali': 'Includes Machher Jhol, Luchi, Begun Bhaja, Chholar Dal, Mishti Doi.',
    'punjabi': 'Includes Sarson Saag, Makki Roti, Chole Bhature, Dal Makhani, Lassi.',
    'maharashtrian': 'Includes Kanda Poha, Misal Pav, Puran Poli, Vada Pav, Pithla Bhakri.',
  };

  final Map<String, String> _packAssets = {
    'south_indian': 'assets/data/regional/south_indian.json',
    'gujarati': 'assets/data/regional/gujarati.json',
    'bengali': 'assets/data/regional/bengali.json',
    'punjabi': 'assets/data/regional/punjabi.json',
    'maharashtrian': 'assets/data/regional/maharashtrian.json',
  };

  final Map<String, IconData> _packIcons = {
    'south_indian': Icons.rice_bowl_rounded,
    'gujarati': Icons.breakfast_dining_rounded,
    'bengali': Icons.set_meal_rounded,
    'punjabi': Icons.lunch_dining_rounded,
    'maharashtrian': Icons.ramen_dining_rounded,
  };

  bool _checking = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _checkLoadedPacks();
  }

  Future<void> _checkLoadedPacks() async {
    final repo = ref.read(foodRepositoryProvider);
    for (final packId in _loadedPacks.keys) {
      final isLoaded = await repo.isRegionalPackLoaded(packId);
      _loadedPacks[packId] = isLoaded;
    }
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _togglePack(String packId, bool value) async {
    setState(() => _syncing = true);
    final repo = ref.read(foodRepositoryProvider);

    try {
      if (value) {
        // Load pack
        await repo.importRegionalPack(
          packId: packId,
          assetPath: _packAssets[packId]!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${_packNames[packId]} into local database!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Remove pack
        await repo.removeRegionalPack(packId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${_packNames[packId]} from local database.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
      _loadedPacks[packId] = value;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update pack. Please check file assets.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Regional Food Packs'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _checking
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _loadedPacks.length,
                  itemBuilder: (context, index) {
                    final packId = _loadedPacks.keys.elementAt(index);
                    final isLoaded = _loadedPacks[packId] ?? false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: SwitchListTile(
                          activeColor: AppColors.primary,
                          title: Row(
                            children: [
                              Icon(_packIcons[packId], color: isLoaded ? AppColors.primary : AppColors.textMuted),
                              const SizedBox(width: 12),
                              Text(
                                _packNames[packId]!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0, left: 32.0),
                            child: Text(
                              _packDescriptions[packId]!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          value: isLoaded,
                          onChanged: _syncing ? null : (val) => _togglePack(packId, val),
                        ),
                      ),
                    );
                  },
                ),
          if (_syncing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Syncing local catalog...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
