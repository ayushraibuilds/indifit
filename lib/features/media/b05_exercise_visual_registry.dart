import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/fixtures/b05_third_party_asset_manifest.dart';
import '../../core/fixtures/exercise_identity_fixtures.dart';
import '../../core/theme/indifit_icons.dart';
import 'indifit_muscle_map.dart';

enum ExerciseVisualPose { start, peak, main }

class B05ExerciseVisualAsset {
  final String mediaRole;
  final String localPath;
  final String checksum;

  const B05ExerciseVisualAsset({
    required this.mediaRole,
    required this.localPath,
    required this.checksum,
  });
}

class B05ExerciseVisualAssetSet {
  final String assetSetId;
  final Set<String> canonicalExerciseUuids;
  final Map<String, B05ExerciseVisualAsset> mediaByRole;
  final String techniqueDisclosure;

  const B05ExerciseVisualAssetSet({
    required this.assetSetId,
    required this.canonicalExerciseUuids,
    required this.mediaByRole,
    required this.techniqueDisclosure,
  });

  B05ExerciseVisualAsset? assetFor(ExerciseVisualPose pose) {
    final role = switch (pose) {
      ExerciseVisualPose.start => 'start',
      ExerciseVisualPose.peak => 'peak',
      ExerciseVisualPose.main => 'main',
    };
    return mediaByRole[role] ?? mediaByRole['main'];
  }
}

/// Exact canonical-UUID lookup for approved local exercise illustrations.
///
/// The registry is presentation-only. It does not infer identity from names,
/// technique prefixes, family names, or external metadata.
class B05ExerciseVisualRegistry {
  final Map<String, B05ExerciseVisualAssetSet> _byCanonicalUuid;

  const B05ExerciseVisualRegistry.empty()
    : _byCanonicalUuid = const <String, B05ExerciseVisualAssetSet>{};

  B05ExerciseVisualRegistry._(
    Map<String, B05ExerciseVisualAssetSet> byCanonicalUuid,
  ) : _byCanonicalUuid = Map.unmodifiable(byCanonicalUuid);

  factory B05ExerciseVisualRegistry.fromAssetSets(
    Iterable<B05ExerciseVisualAssetSet> sets,
  ) {
    final byUuid = <String, B05ExerciseVisualAssetSet>{};
    for (final set in sets) {
      for (final uuid in set.canonicalExerciseUuids) {
        final previous = byUuid[uuid];
        if (previous != null && previous.assetSetId != set.assetSetId) {
          throw StateError(
            'Canonical UUID $uuid is bound to multiple visual asset sets.',
          );
        }
        byUuid[uuid] = set;
      }
    }
    return B05ExerciseVisualRegistry._(byUuid);
  }

  factory B05ExerciseVisualRegistry.fromProvenance(
    B05ThirdPartyAssetManifest manifest,
  ) {
    manifest.validateStructure();
    final byUuid = <String, B05ExerciseVisualAssetSet>{};
    for (final set in manifest.visualAssetSets) {
      final files = set.mediaByRole.values.toList(growable: false);
      if (set.sourceKey != 'repdb_free_tier' ||
          files.any((asset) => asset.approvalStatus != 'production')) {
        continue;
      }
      final media = <String, B05ExerciseVisualAsset>{};
      for (final asset in files) {
        final destination = asset.localDestination;
        final disclosure = asset.techniqueDisclosure;
        if (disclosure == null) continue;
        media[asset.mediaRole] = B05ExerciseVisualAsset(
          mediaRole: asset.mediaRole,
          localPath: destination,
          checksum: asset.checksum,
        );
      }
      if (media.isEmpty) continue;
      final visualSet = B05ExerciseVisualAssetSet(
        assetSetId: set.assetSetId,
        canonicalExerciseUuids: set.canonicalExerciseUuids.toSet(),
        mediaByRole: Map.unmodifiable(media),
        techniqueDisclosure: set.techniqueDisclosure.text,
      );
      for (final uuid in set.canonicalExerciseUuids) {
        final previous = byUuid[uuid];
        if (previous != null && previous.assetSetId != visualSet.assetSetId) {
          throw B05RegistryValidationException(
            'duplicate_visual_uuid_binding',
            'Canonical UUID $uuid is bound to multiple visual asset sets.',
          );
        }
        byUuid[uuid] = visualSet;
      }
    }
    return B05ExerciseVisualRegistry._(byUuid);
  }

  B05ExerciseVisualAssetSet? lookup(String canonicalExerciseUuid) {
    final uuid = canonicalExerciseUuid.trim();
    if (uuid.isEmpty) return null;
    return _byCanonicalUuid[uuid];
  }

  int get bindingCount => _byCanonicalUuid.length;
  int get assetSetCount =>
      _byCanonicalUuid.values.map((set) => set.assetSetId).toSet().length;
}

class B05AssetBundleExerciseVisualRegistrySource {
  final AssetBundle bundle;
  final String manifestAssetPath;

  const B05AssetBundleExerciseVisualRegistrySource({
    required this.bundle,
    this.manifestAssetPath = 'assets/third_party/asset_manifest.json',
  });

  Future<B05ExerciseVisualRegistry> load() async {
    final raw = await bundle.loadString(manifestAssetPath);
    return B05ExerciseVisualRegistry.fromProvenance(
      B05ThirdPartyAssetManifest.fromJson(jsonDecode(raw)),
    );
  }
}

@immutable
class ExerciseVisualMuscleFacts {
  final String? primaryMuscle;
  final List<String> secondaryMuscles;

  const ExerciseVisualMuscleFacts({
    this.primaryMuscle,
    this.secondaryMuscles = const <String>[],
  });

  bool get isNotEmpty =>
      (primaryMuscle?.trim().isNotEmpty ?? false) ||
      secondaryMuscles.any((muscle) => muscle.trim().isNotEmpty);
}

/// Reusable static exercise illustration with the R08 fallback chain.
///
/// START and PEAK are caller-selected poses; they are never auto-looped. A
/// MAIN-only set is used for every pose request. The widget owns visual
/// semantics only when [decorative] is false; callers should provide an
/// exercise-specific [semanticsContext] for the best announcement.
class ExerciseVisual extends StatefulWidget {
  final String canonicalExerciseUuid;
  final B05ExerciseVisualRegistry registry;
  final ExerciseVisualMuscleFacts? displayMuscles;
  final String? equipment;
  final IconData? semanticIcon;
  final ExerciseVisualPose pose;
  final String? semanticsContext;
  final bool decorative;
  final bool showTechniqueDisclosure;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AssetBundle? assetBundle;

  const ExerciseVisual({
    required this.canonicalExerciseUuid,
    this.registry = const B05ExerciseVisualRegistry.empty(),
    this.displayMuscles,
    this.equipment,
    this.semanticIcon,
    this.pose = ExerciseVisualPose.start,
    this.semanticsContext,
    this.decorative = false,
    this.showTechniqueDisclosure = false,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.assetBundle,
    super.key,
  });

  @override
  State<ExerciseVisual> createState() => _ExerciseVisualState();
}

class _ExerciseVisualState extends State<ExerciseVisual> {
  static final Map<String, String> _canonicalNamesByUuid = {
    for (final entry in ExerciseCatalogManifest.goldenCatalogUuids.entries)
      entry.value: entry.key,
  };

  late Future<Uint8List?> _assetFuture;

  @override
  void initState() {
    super.initState();
    _assetFuture = _loadApprovedAsset();
  }

  @override
  void didUpdateWidget(covariant ExerciseVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canonicalExerciseUuid != widget.canonicalExerciseUuid ||
        oldWidget.registry != widget.registry ||
        oldWidget.pose != widget.pose ||
        oldWidget.assetBundle != widget.assetBundle) {
      _assetFuture = _loadApprovedAsset();
    }
  }

  Future<Uint8List?> _loadApprovedAsset() async {
    final set = widget.registry.lookup(widget.canonicalExerciseUuid);
    final asset = set?.assetFor(widget.pose);
    if (asset == null) return null;
    try {
      final data = await (widget.assetBundle ?? rootBundle).load(
        asset.localPath,
      );
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final actual = 'sha256:${sha256.convert(bytes)}';
      return actual.toLowerCase() == asset.checksum.toLowerCase()
          ? bytes
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.registry.lookup(widget.canonicalExerciseUuid);
    return FutureBuilder<Uint8List?>(
      future: _assetFuture,
      builder: (context, snapshot) {
        final visual = snapshot.data == null
            ? _fallback(context)
            : Image.memory(
                snapshot.data!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                gaplessPlayback: true,
                errorBuilder: (errorContext, error, stackTrace) {
                  return _fallback(errorContext);
                },
              );
        final content = _withDisclosure(visual, set);
        if (widget.decorative) return ExcludeSemantics(child: content);
        return Semantics(
          container: true,
          image: true,
          label: _semanticsLabel,
          value: widget.showTechniqueDisclosure && set != null
              ? set.techniqueDisclosure
              : null,
          child: ExcludeSemantics(child: content),
        );
      },
    );
  }

  String get _semanticsLabel {
    final context = widget.semanticsContext?.trim();
    if (context != null && context.isNotEmpty) return context;
    final canonicalName =
        _canonicalNamesByUuid[widget.canonicalExerciseUuid.trim()];
    if (canonicalName == null) return 'Exercise visual';
    return '${_titleCase(canonicalName)} exercise illustration';
  }

  static String _titleCase(String value) => value
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  Widget _withDisclosure(Widget visual, B05ExerciseVisualAssetSet? set) {
    if (!widget.showTechniqueDisclosure || set == null) return visual;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        visual,
        const SizedBox(height: 8),
        Text(set.techniqueDisclosure),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    final muscles = widget.displayMuscles;
    if (muscles?.isNotEmpty == true) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: IndiFitMuscleMap.exercise(
          primaryMuscle: muscles!.primaryMuscle,
          secondaryMuscles: muscles.secondaryMuscles,
          showTextEquivalent: false,
        ),
      );
    }
    final equipment = widget.equipment?.trim();
    final icon =
        widget.semanticIcon ??
        (equipment == null || equipment.isEmpty
            ? null
            : _iconForEquipment(equipment));
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Icon(icon ?? Icons.image_not_supported_outlined, size: 32),
      ),
    );
  }

  static IconData _iconForEquipment(String? equipment) {
    final normalized = equipment?.trim().toLowerCase();
    return switch (normalized) {
      'barbell' ||
      'dumbbell' ||
      'dumbbells' ||
      'cable' ||
      'cables' ||
      'machine' ||
      'bodyweight' => IndiFitIcons.equipment,
      _ => IndiFitIcons.exercise,
    };
  }
}
