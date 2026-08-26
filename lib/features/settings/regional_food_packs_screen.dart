import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/crash_reporting_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/repositories/food_repository.dart';

/// Existing local catalogue controls presented as a food preference surface.
///
/// The selected packs are still owned by [FoodRepository]. This screen only
/// invokes that existing import/remove behavior; it does not create a second
/// regional-preference store or infer any nutrition conversions.
class RegionalFoodPacksScreen extends ConsumerStatefulWidget {
  const RegionalFoodPacksScreen({super.key});

  @override
  ConsumerState<RegionalFoodPacksScreen> createState() =>
      _RegionalFoodPacksScreenState();
}

class _RegionalFoodPacksScreenState
    extends ConsumerState<RegionalFoodPacksScreen> {
  static const _packIds = [
    'south_indian',
    'gujarati',
    'bengali',
    'punjabi',
    'maharashtrian',
  ];

  static const _packNames = {
    'south_indian': 'South Indian Pack',
    'gujarati': 'Gujarati Pack',
    'bengali': 'Bengali Pack',
    'punjabi': 'Punjabi Pack',
    'maharashtrian': 'Maharashtrian Pack',
  };

  static const _packDescriptions = {
    'south_indian': 'Dosa, idli, rasam, and other South Indian foods.',
    'gujarati': 'Dhokla, thepla, kadhi, and other Gujarati foods.',
    'bengali': 'Machher jhol, luchi, dal, and other Bengali foods.',
    'punjabi': 'Sarson saag, chole, dal, and other Punjabi foods.',
    'maharashtrian': 'Poha, misal, vada pav, and other Maharashtrian foods.',
  };

  static const _packAssets = {
    'south_indian': 'assets/data/regional/south_indian.json',
    'gujarati': 'assets/data/regional/gujarati.json',
    'bengali': 'assets/data/regional/bengali.json',
    'punjabi': 'assets/data/regional/punjabi.json',
    'maharashtrian': 'assets/data/regional/maharashtrian.json',
  };

  static const _packIcons = {
    'south_indian': Icons.rice_bowl_rounded,
    'gujarati': Icons.breakfast_dining_rounded,
    'bengali': Icons.set_meal_rounded,
    'punjabi': Icons.lunch_dining_rounded,
    'maharashtrian': Icons.ramen_dining_rounded,
  };

  final Map<String, bool> _loadedPacks = {
    for (final packId in _packIds) packId: false,
  };

  bool _checking = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkLoadedPacks();
  }

  Future<void> _checkLoadedPacks() async {
    if (mounted) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }
    final repo = ref.read(foodRepositoryProvider);
    final loaded = <String, bool>{};
    try {
      for (final packId in _packIds) {
        loaded[packId] = await repo.isRegionalPackLoaded(packId);
      }
      if (!mounted) return;
      setState(() {
        _loadedPacks.addAll(loaded);
        _checking = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      _recordFailure(error, stackTrace, 'regional food pack load error');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Regional foods are unavailable right now.';
      });
    }
  }

  Future<void> _togglePack(String packId, bool value) async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    final repo = ref.read(foodRepositoryProvider);

    try {
      if (value) {
        await repo.importRegionalPack(
          packId: packId,
          assetPath: _packAssets[packId]!,
        );
      } else {
        await repo.removeRegionalPack(packId);
      }
      if (!mounted) return;
      setState(() => _loadedPacks[packId] = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '${_packNames[packId]} is now included in food search.'
                : '${_packNames[packId]} is no longer included in food search.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      _recordFailure(error, stackTrace, 'regional food pack update error');
      if (!mounted) return;
      setState(() => _error = 'Could not update this food pack. Try again.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _recordFailure(Object error, StackTrace stackTrace, String reason) {
    AppLogger.warning('$reason: $error');
    CrashReportingService.recordCrash(error, stackTrace, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional foods'),
        actions: [
          IconButton(
            tooltip: 'Reload regional foods',
            onPressed: _syncing ? null : _checkLoadedPacks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _checking
          ? const Center(
              child: ConsumerStatusRow(
                label: 'Loading regional foods',
                detail: 'Checking which optional food packs are included.',
                loading: true,
              ),
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _checkLoadedPacks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space32,
        ),
        children: [
          Text('Regional foods', style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Choose optional food packs to include in search. These packs add food entries; they do not change nutrition values or create conversions.',
            style: B05Typography.body(context),
          ),
          if (_error != null) ...[
            const SizedBox(height: B05Layout.space12),
            ConsumerStatusRow(
              label: 'Regional foods could not be updated',
              detail: _error,
              error: true,
              onRetry: _syncing ? null : _checkLoadedPacks,
            ),
          ],
          if (_syncing) ...[
            const SizedBox(height: B05Layout.space12),
            const ConsumerStatusRow(
              label: 'Updating regional foods',
              detail: 'Updating the optional food pack on this device.',
              loading: true,
            ),
          ],
          const SizedBox(height: B05Layout.space20),
          for (final packId in _packIds) ...[
            _packCard(context, packId),
            const SizedBox(height: B05Layout.space12),
          ],
          Text(
            'Regional packs are optional and can be changed any time.',
            style: B05Typography.caption(context),
          ),
        ],
      ),
    );
  }

  Widget _packCard(BuildContext context, String packId) {
    final isLoaded = _loadedPacks[packId] ?? false;
    final colors = context.b05Colors;
    final packName = _packNames[packId]!;
    final status = isLoaded
        ? 'Included in food search'
        : 'Not included in food search';
    return Semantics(
      container: true,
      label: '$packName. $status. ${_packDescriptions[packId]}',
      child: B05Surface(
        tone: isLoaded ? B05SurfaceTone.selected : B05SurfaceTone.section,
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space12,
          B05Layout.space8,
          B05Layout.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: B05Layout.space8),
              child: Icon(
                _packIcons[packId],
                color: isLoaded ? colors.action : colors.textSecondary,
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: B05Layout.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(packName, style: B05Typography.title(context)),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      _packDescriptions[packId]!,
                      style: B05Typography.body(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      status,
                      style: B05Typography.caption(context).copyWith(
                        color: isLoaded
                            ? colors.success.foreground
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Switch(
              value: isLoaded,
              onChanged: _syncing
                  ? null
                  : (value) => _togglePack(packId, value),
              activeThumbColor: colors.action,
            ),
          ],
        ),
      ),
    );
  }
}
