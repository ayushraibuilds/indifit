import 'dart:typed_data';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/fixtures/exercise_display_muscles.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../../data/repositories/b07_exercise_context_repository.dart';
import '../../media/b05_exercise_visual_registry.dart';
import '../../media/indifit_muscle_map.dart';
import 'b02_execution_semantics.dart';

/// Compact exercise context for the live execution surface.
///
/// The widget is keyed by the exact actual performed UUID. It always renders
/// the name and logging surface independently of the asynchronous catalog or
/// media reads, so missing metadata/artwork cannot block a workout.
class B07ExerciseContextPanel extends ConsumerWidget {
  const B07ExerciseContextPanel({
    required this.canonicalExerciseId,
    required this.exerciseNameSnapshot,
    super.key,
    this.visualRegistry,
    this.assetBundle,
    this.muscleMapOnly = false,
  });

  final String canonicalExerciseId;
  final String exerciseNameSnapshot;
  final B05ExerciseVisualRegistry? visualRegistry;
  final AssetBundle? assetBundle;
  final bool muscleMapOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exactId = canonicalExerciseId.trim();
    final result = exactId.isEmpty
        ? const AsyncValue<B07ExerciseContextResult>.data(
            B07ExerciseContextResult.unavailable(),
          )
        : ref.watch(b07ExerciseContextProvider(exactId));
    final registry =
        visualRegistry ??
        ref.watch(b05ExerciseVisualRegistryProvider).valueOrNull ??
        const B05ExerciseVisualRegistry.empty();
    final resolved = result.valueOrNull;
    return B07ExerciseContextCard(
      canonicalExerciseId: exactId,
      exerciseNameSnapshot: exerciseNameSnapshot,
      contextData: resolved?.context,
      visualRegistry: registry,
      assetBundle: assetBundle,
      isLoadingContext: result.isLoading,
      muscleMapOnly: muscleMapOnly,
    );
  }
}

/// Purely presentational content card, exposed so B.7 golden/semantics tests
/// can exercise the fallback states without constructing a database.
class B07ExerciseContextCard extends StatelessWidget {
  const B07ExerciseContextCard({
    required this.canonicalExerciseId,
    required this.exerciseNameSnapshot,
    required this.contextData,
    required this.visualRegistry,
    super.key,
    this.assetBundle,
    this.isLoadingContext = false,
    this.muscleMapOnly = false,
  });

  final String canonicalExerciseId;
  final String exerciseNameSnapshot;
  final B07ExerciseContext? contextData;
  final B05ExerciseVisualRegistry visualRegistry;
  final AssetBundle? assetBundle;
  final bool isLoadingContext;

  /// The exercise pictures are already on screen (the player's hero), so
  /// this card shows the muscle map in their place.
  final bool muscleMapOnly;

  @override
  Widget build(BuildContext context) {
    final name = exerciseNameSnapshot.trim().isEmpty
        ? 'Current exercise'
        : exerciseNameSnapshot.trim();
    final displayMuscles = contextData?.displayMuscles;
    final equipment = contextData?.equipment.trim();
    final hasEquipment = equipment?.isNotEmpty == true;
    return Semantics(
      container: true,
      label: 'Exercise context for $name',
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.all(B05Layout.space8),
        // Context is asynchronous, but the logging list is lazy. Every
        // collapsed state below keeps the same compact rows, so a result
        // cannot unmount a focused set field.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (muscleMapOnly)
              _B07MuscleMapStrip(displayMuscles: displayMuscles)
            else
              B07ExerciseVisualRegion(
                canonicalExerciseId: canonicalExerciseId,
                exerciseNameSnapshot: name,
                displayMuscles: displayMuscles == null
                    ? null
                    : ExerciseVisualMuscleFacts(
                        primaryMuscle: displayMuscles.primary,
                        secondaryMuscles: displayMuscles.secondary,
                      ),
                equipment: hasEquipment ? equipment : null,
                registry: visualRegistry,
                assetBundle: assetBundle,
              ),
            const SizedBox(height: B05Layout.space4),
            _B07MuscleAndEquipmentLine(
              displayMuscles: displayMuscles,
              equipment: hasEquipment ? equipment : null,
            ),
            if (!isLoadingContext && contextData?.hasGuidance == true) ...[
              const SizedBox(height: B05Layout.space4),
              _B07CueSummary(
                cues: contextData!.formCues,
                commonMistakes: contextData!.commonMistakes,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uses only the existing exact-UUID R08-0 registry and its established
/// fallback chain. Start/Peak are shown only when both frames load and pass
/// their checksum; no second frame is manufactured for MAIN-only or partial
/// sets, and missing files never show two identical fallbacks.
class B07ExerciseVisualRegion extends StatefulWidget {
  const B07ExerciseVisualRegion({
    required this.canonicalExerciseId,
    required this.exerciseNameSnapshot,
    required this.registry,
    super.key,
    this.displayMuscles,
    this.equipment,
    this.assetBundle,
  });

  final String canonicalExerciseId;
  final String exerciseNameSnapshot;
  final ExerciseVisualMuscleFacts? displayMuscles;
  final String? equipment;
  final B05ExerciseVisualRegistry registry;
  final AssetBundle? assetBundle;

  @override
  State<B07ExerciseVisualRegion> createState() =>
      _B07ExerciseVisualRegionState();
}

class _B07ExerciseVisualRegionState extends State<B07ExerciseVisualRegion> {
  late Future<B05ExerciseImages?> _images;

  String get canonicalExerciseId => widget.canonicalExerciseId;
  String get exerciseNameSnapshot => widget.exerciseNameSnapshot;
  ExerciseVisualMuscleFacts? get displayMuscles => widget.displayMuscles;
  String? get equipment => widget.equipment;
  B05ExerciseVisualRegistry get registry => widget.registry;
  AssetBundle? get assetBundle => widget.assetBundle;

  @override
  void initState() {
    super.initState();
    _images = _load();
  }

  @override
  void didUpdateWidget(covariant B07ExerciseVisualRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canonicalExerciseId != widget.canonicalExerciseId ||
        oldWidget.registry != widget.registry ||
        oldWidget.assetBundle != widget.assetBundle) {
      _images = _load();
    }
  }

  Future<B05ExerciseImages?> _load() => b05LoadExerciseImages(
    registry: widget.registry,
    canonicalExerciseUuid: widget.canonicalExerciseId,
    bundle: widget.assetBundle,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<B05ExerciseImages?>(
      future: _images,
      builder: (context, snapshot) {
        // Keep the slot height while the files are checked.
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 64);
        }
        return _region(context, hasStartPeak: snapshot.data?.isPair == true);
      },
    );
  }

  Widget _region(BuildContext context, {required bool hasStartPeak}) {
    final set = registry.lookup(canonicalExerciseId);
    final label = hasStartPeak
        ? 'Start and peak exercise illustrations for $exerciseNameSnapshot'
        : 'Exercise illustration for $exerciseNameSnapshot';
    return Semantics(
      container: true,
      label: label,
      child: SizedBox(
        // Keep the same slot height while the exact registry lookup changes
        // from loading/icon fallback to an approved two-frame visual.
        height: 64,
        child: hasStartPeak
            ? Row(
                children: [
                  Expanded(
                    child: _pose(
                      context,
                      pose: ExerciseVisualPose.start,
                      label: 'Start position',
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: _pose(
                      context,
                      pose: ExerciseVisualPose.peak,
                      label: 'Peak position',
                    ),
                  ),
                ],
              )
            : _singleVisual(context, set),
      ),
    );
  }

  Widget _pose(
    BuildContext context, {
    required ExerciseVisualPose pose,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ExerciseVisual(
            canonicalExerciseUuid: canonicalExerciseId,
            registry: registry,
            displayMuscles: displayMuscles,
            equipment: equipment,
            pose: pose,
            assetBundle: assetBundle,
            cacheWidth: _cacheWidth(context),
            width: double.infinity,
            height: double.infinity,
            semanticsContext: '$exerciseNameSnapshot $label illustration',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: B05Typography.caption(context),
        ),
      ],
    );
  }

  Widget _singleVisual(BuildContext context, B05ExerciseVisualAssetSet? set) {
    final pose = set?.mediaByRole['main'] != null
        ? ExerciseVisualPose.main
        : set?.mediaByRole['start'] != null
        ? ExerciseVisualPose.start
        : set?.mediaByRole['peak'] != null
        ? ExerciseVisualPose.peak
        : ExerciseVisualPose.main;
    return ExerciseVisual(
      canonicalExerciseUuid: canonicalExerciseId,
      registry: registry,
      displayMuscles: displayMuscles,
      equipment: equipment,
      pose: pose,
      assetBundle: assetBundle,
      cacheWidth: _cacheWidth(context),
      width: double.infinity,
      height: double.infinity,
      semanticsContext: '$exerciseNameSnapshot exercise illustration',
    );
  }

  int _cacheWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logicalWidth = (width / 2).clamp(120.0, 360.0);
    return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
  }
}

/// The muscle map at the compact visual's height. Empty when the muscles are
/// unknown; the line below then says so.
class _B07MuscleMapStrip extends StatelessWidget {
  const _B07MuscleMapStrip({required this.displayMuscles});

  final ExerciseDisplayMuscles? displayMuscles;

  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final primary = displayMuscles?.primary;
    final secondary = displayMuscles?.secondary ?? const <String>[];
    if ((primary == null || primary.trim().isEmpty) && secondary.isEmpty) {
      return const SizedBox.shrink();
    }
    // The line below reads the muscles out; the map is decorative here.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            // The both-view geometry is about 1.15:1.
            width: height * 1.15,
            height: height,
            child: IndiFitMuscleMap.exercise(
              primaryMuscle: primary,
              secondaryMuscles: secondary,
              showTextEquivalent: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _B07MuscleAndEquipmentLine extends StatelessWidget {
  const _B07MuscleAndEquipmentLine({
    required this.displayMuscles,
    required this.equipment,
  });

  final ExerciseDisplayMuscles? displayMuscles;
  final String? equipment;

  @override
  Widget build(BuildContext context) {
    final primary = displayMuscles?.primary?.trim();
    final secondary = displayMuscles?.secondary
        .map((muscle) => muscle.trim())
        .where((muscle) => muscle.isNotEmpty)
        .toList(growable: false);
    final muscleText = primary?.isNotEmpty == true
        ? 'Primary: $primary'
        : 'Muscle context unavailable';
    final secondaryText = secondary?.isNotEmpty == true
        ? ' · Secondary: ${secondary!.join(', ')}'
        : '';
    final equipmentText = equipment?.trim();
    return Semantics(
      container: true,
      label: [
        muscleText,
        if (secondaryText.isNotEmpty) secondaryText.substring(3),
        if (equipmentText?.isNotEmpty == true) 'Equipment: $equipmentText',
      ].join('. '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.accessibility_new_rounded,
              size: B05Layout.iconSmall,
              color: context.b05Colors.action,
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: Text(
                [
                  '$muscleText$secondaryText',
                  if (equipmentText?.isNotEmpty == true)
                    'Equipment: $equipmentText',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: B05Typography.caption(context).copyWith(
                  color: context.b05Colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _B07CueSummary extends StatelessWidget {
  const _B07CueSummary({required this.cues, required this.commonMistakes});

  final List<String> cues;
  final List<String> commonMistakes;

  @override
  Widget build(BuildContext context) {
    final firstCue = cues.firstOrNull;
    final hasDisclosure = cues.length > 1 || commonMistakes.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: B05Layout.minTouchTarget),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: B05Layout.iconSmall,
            color: context.b05Colors.action,
          ),
          const SizedBox(width: B05Layout.space8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: firstCue == null ? '' : 'Key cue · ',
                    style: B05Typography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: firstCue ?? 'More technique guidance'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasDisclosure)
            TextButton(
              onPressed: () => _showGuidance(
                context,
                cues: cues,
                commonMistakes: commonMistakes,
              ),
              style: TextButton.styleFrom(
                minimumSize: B05Layout.minimumTouchTarget,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Technique'),
            ),
        ],
      ),
    );
  }

  Future<void> _showGuidance(
    BuildContext context, {
    required List<String> cues,
    required List<String> commonMistakes,
  }) {
    return showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Exercise technique',
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            0,
            B05Layout.space16,
            B05Layout.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Technique', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space8),
              if (cues.isNotEmpty)
                _B07GuidanceSection(title: 'Cues', values: cues),
              if (commonMistakes.isNotEmpty)
                _B07GuidanceSection(
                  title: 'Common things to watch',
                  values: commonMistakes,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _B07GuidanceSection extends StatelessWidget {
  const _B07GuidanceSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: B05Typography.label(context)),
          const SizedBox(height: B05Layout.space4),
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space4),
              child: Text('• $value', style: B05Typography.body(context)),
            ),
        ],
      ),
    );
  }
}

/// Small next-exercise context built from the already-canonical B.5 slot
/// progression. It does not infer adjacency from names or display order.
class B07NextExerciseContext extends StatelessWidget {
  const B07NextExerciseContext({
    required this.currentSlot,
    super.key,
    this.nextSlot,
  });

  final B02StrengthExecutionSlot currentSlot;
  final B02StrengthExecutionSlot? nextSlot;

  @override
  Widget build(BuildContext context) {
    final groupType = nextSlot?.groupType;
    final position = groupType == null
        ? null
        : [
            b02ExecutionGroupTypeLabel(groupType),
            if (nextSlot?.roundOrdinal != null)
              'Round ${(nextSlot?.roundOrdinal ?? 0) + 1}',
            if (nextSlot?.memberOrdinal != null)
              'Member ${(nextSlot?.memberOrdinal ?? 0) + 1}',
          ].join(' · ');
    final nextName = nextSlot?.exerciseNameSnapshot.trim();
    return Semantics(
      container: true,
      label: nextName == null || nextName.isEmpty
          ? 'End of workout sequence'
          : 'Next exercise $nextName${position == null ? '' : ', $position'}',
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space12,
          vertical: B05Layout.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              nextName == null || nextName.isEmpty
                  ? Icons.flag_outlined
                  : Icons.skip_next_rounded,
              color: context.b05Colors.action,
              size: B05Layout.iconMedium,
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextName == null || nextName.isEmpty
                        ? 'End of workout sequence'
                        : 'Next exercise',
                    style: B05Typography.label(context),
                  ),
                  if (nextName != null && nextName.isNotEmpty)
                    Text(nextName, style: B05Typography.body(context)),
                  if (position != null)
                    Text(position, style: B05Typography.caption(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The exercise pictures at the top of the player (V5, concept G): start and
/// peak side by side, large enough to read the movement. The player shows it
/// only when approved images loaded. Folded, it is one "Show pictures" row.
class B07ExerciseHero extends StatelessWidget {
  const B07ExerciseHero({
    required this.images,
    required this.exerciseName,
    required this.expanded,
    required this.onExpandedChanged,
    super.key,
  });

  final B05ExerciseImages images;
  final String exerciseName;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: B05Layout.minimumTouchTarget,
          ),
          onPressed: () => onExpandedChanged(true),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Show exercise pictures'),
        ),
      );
    }
    final pictures = images.isPair
        ? Row(
            children: [
              Expanded(
                child: _B07HeroTile(bytes: images.start!, label: 'Start'),
              ),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: _B07HeroTile(bytes: images.peak!, label: 'Peak'),
              ),
            ],
          )
        : _B07HeroTile(bytes: images.single!, aspectRatio: 16 / 9);
    return Semantics(
      container: true,
      image: true,
      label: images.isPair
          ? 'Start and peak pictures for $exerciseName'
          : 'Picture of $exerciseName',
      child: Stack(
        children: [
          ExcludeSemantics(child: pictures),
          Positioned(
            top: B05Layout.space4,
            right: B05Layout.space4,
            child: IconButton.filledTonal(
              tooltip: 'Hide exercise pictures',
              onPressed: () => onExpandedChanged(false),
              icon: const Icon(Icons.expand_less_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _B07HeroTile extends StatelessWidget {
  const _B07HeroTile({required this.bytes, this.label, this.aspectRatio = 1});

  final Uint8List bytes;
  final String? label;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round();
        return ClipPath(
          clipper: ShapeBorderClipper(
            shape: SmoothRectangleBorder(borderRadius: B05Radii.rowRadius),
          ),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: ColoredBox(
              color: context.b05Colors.inset,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                    gaplessPlayback: true,
                  ),
                  if (label != null)
                    Positioned(
                      left: B05Layout.space8,
                      bottom: B05Layout.space8,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: const StadiumBorder(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: B05Layout.space8,
                            vertical: 2,
                          ),
                          child: Text(
                            label!,
                            style: B05Typography.caption(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
