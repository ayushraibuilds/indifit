import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';

import 'indifit_muscle_map_geometry.g.dart';
import 'indifit_muscle_map_taxonomy.dart';

/// The body model used by the local presentation renderer.
enum IndiFitMuscleMapBody { male, female }

/// Which body view(s) the renderer presents.
enum IndiFitMuscleMapView { front, back, both }

/// The two caller-owned data modes plus an explicit no-data state.
enum IndiFitMuscleMapMode { exercise, intensity, noData }

/// A static, local, deterministic muscle-map renderer foundation.
///
/// This widget is intentionally isolated from Progress, Training, Workout
/// Player, persistence, and production media approval. It accepts canonical
/// display concepts or caller-provided intensity values and paints only the
/// local geometry registry.
class IndiFitMuscleMap extends StatelessWidget {
  const IndiFitMuscleMap.exercise({
    required this.primaryMuscle,
    super.key,
    this.secondaryMuscles = const <String>[],
    this.bodyModel = IndiFitMuscleMapBody.male,
    this.view = IndiFitMuscleMapView.both,
    this.showTextEquivalent = true,
  }) : mode = IndiFitMuscleMapMode.exercise,
       intensityValues = null,
       metricLabel = 'Intensity';

  const IndiFitMuscleMap.intensity({
    required this.intensityValues,
    super.key,
    this.metricLabel = 'Intensity',
    this.bodyModel = IndiFitMuscleMapBody.male,
    this.view = IndiFitMuscleMapView.both,
    this.showTextEquivalent = true,
  }) : mode = IndiFitMuscleMapMode.intensity,
       primaryMuscle = null,
       secondaryMuscles = const <String>[];

  const IndiFitMuscleMap.noData({
    super.key,
    this.bodyModel = IndiFitMuscleMapBody.male,
    this.view = IndiFitMuscleMapView.both,
    this.showTextEquivalent = true,
  }) : mode = IndiFitMuscleMapMode.noData,
       primaryMuscle = null,
       secondaryMuscles = const <String>[],
       intensityValues = null,
       metricLabel = 'Intensity';

  final IndiFitMuscleMapMode mode;
  final String? primaryMuscle;
  final List<String> secondaryMuscles;
  final Map<String, double>? intensityValues;
  final String metricLabel;
  final IndiFitMuscleMapBody bodyModel;
  final IndiFitMuscleMapView view;
  final bool showTextEquivalent;

  static const IndiFitMuscleMapTaxonomyAdapter _adapter =
      IndiFitMuscleMapTaxonomyAdapter();

  @override
  Widget build(BuildContext context) {
    final renderState = _resolveRenderState();
    final description = _description(renderState);
    final colors = context.b05Colors;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'IndiFit muscle map',
      value: description,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MapLayout(
            bodyModel: bodyModel,
            view: view,
            renderState: renderState,
            colors: colors,
          ),
          if (showTextEquivalent) ...[
            const SizedBox(height: B05Layout.space8),
            Text(description, style: B05Typography.caption(context)),
          ],
        ],
      ),
    );
  }

  _IndiFitMuscleMapRenderState _resolveRenderState() {
    switch (mode) {
      case IndiFitMuscleMapMode.exercise:
        final resolution = _adapter.resolveExercise(
          primary: primaryMuscle,
          secondary: secondaryMuscles,
        );
        return _IndiFitMuscleMapRenderState.exercise(
          primarySlugs: resolution.primarySlugs,
          secondarySlugs: resolution.secondarySlugs,
          unresolvedMuscles: resolution.unresolvedMuscles,
        );
      case IndiFitMuscleMapMode.intensity:
        final resolution = _adapter.resolveHeat(intensityValues ?? const {});
        return _IndiFitMuscleMapRenderState.intensity(
          regionIntensities: resolution.regionIntensities,
          unresolvedMuscles: resolution.unresolvedMuscles,
        );
      case IndiFitMuscleMapMode.noData:
        return const _IndiFitMuscleMapRenderState.noData();
    }
  }

  String _description(_IndiFitMuscleMapRenderState renderState) {
    if (renderState.mode == IndiFitMuscleMapMode.noData) {
      return 'Muscle map unavailable: no reviewed muscle data.';
    }

    if (renderState.mode == IndiFitMuscleMapMode.exercise) {
      final sentences = <String>[];
      if (primaryMuscle != null && primaryMuscle!.trim().isNotEmpty) {
        sentences.add('Primary muscle: ${primaryMuscle!.trim()}.');
      }
      final secondary = secondaryMuscles
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (secondary.isNotEmpty) {
        sentences.add('Secondary muscles: ${secondary.join(', ')}.');
      }
      if (renderState.unresolvedMuscles.isNotEmpty) {
        sentences.add(
          'Unresolved muscle concepts: '
          '${renderState.unresolvedMuscles.join(', ')}.',
        );
      }
      if (!renderState.hasMappedRegions) {
        sentences.add('No local geometry is highlighted.');
      }
      return sentences.isEmpty
          ? 'Muscle map unavailable: no reviewed muscle data.'
          : sentences.join(' ');
    }

    if (intensityValues == null || intensityValues!.isEmpty) {
      return 'Muscle map unavailable: no reviewed intensity data.';
    }

    final values = <String>[];
    for (final entry in (intensityValues ?? const {}).entries) {
      final percent = (entry.value * 100).round();
      values.add('${entry.key.trim()}: $percent%');
    }
    final sentences = <String>[
      if (values.isNotEmpty) '$metricLabel: ${values.join(', ')}.',
      if (renderState.unresolvedMuscles.isNotEmpty)
        'Unresolved muscle concepts: '
            '${renderState.unresolvedMuscles.join(', ')}.',
      if (!renderState.hasMappedRegions) 'No local geometry is highlighted.',
    ];
    return sentences.isEmpty
        ? 'Muscle map unavailable: no reviewed intensity data.'
        : sentences.join(' ');
  }
}

class _MapLayout extends StatelessWidget {
  const _MapLayout({
    required this.bodyModel,
    required this.view,
    required this.renderState,
    required this.colors,
  });

  final IndiFitMuscleMapBody bodyModel;
  final IndiFitMuscleMapView view;
  final _IndiFitMuscleMapRenderState renderState;
  final B05SemanticColors colors;

  @override
  Widget build(BuildContext context) {
    final Widget map;
    final double maxWidth;
    if (view == IndiFitMuscleMapView.both) {
      maxWidth = 560;
      map = Row(
        key: const ValueKey<String>('indifit_muscle_map_both'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _singleView(IndiFitMuscleMapSide.front)),
          const SizedBox(width: B05Layout.space8),
          Expanded(child: _singleView(IndiFitMuscleMapSide.back)),
        ],
      );
    } else {
      maxWidth = 300;
      map = _singleView(
        view == IndiFitMuscleMapView.front
            ? IndiFitMuscleMapSide.front
            : IndiFitMuscleMapSide.back,
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: map,
      ),
    );
  }

  Widget _singleView(IndiFitMuscleMapSide side) {
    final generatedBody = bodyModel == IndiFitMuscleMapBody.male
        ? IndiFitMuscleMapBodyModel.male
        : IndiFitMuscleMapBodyModel.female;
    final viewBox =
        IndiFitMuscleMapGeometryRegistry
            .viewBoxes[IndiFitMuscleMapGeometryRegistry.viewBoxKey(
          generatedBody,
          side,
        )]!;

    return AspectRatio(
      aspectRatio: viewBox.width / viewBox.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.inset,
          border: Border.all(color: colors.border),
          borderRadius: B05Radii.mediumRadius,
        ),
        child: RepaintBoundary(
          child: CustomPaint(
            key: ValueKey<String>(
              'indifit_muscle_map_${generatedBody.name}_${side.name}',
            ),
            painter: _IndiFitMuscleMapPainter(
              bodyModel: generatedBody,
              side: side,
              renderState: renderState,
              colors: colors,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

@immutable
class _IndiFitMuscleMapRenderState {
  const _IndiFitMuscleMapRenderState.exercise({
    required this.primarySlugs,
    required this.secondarySlugs,
    required this.unresolvedMuscles,
  }) : mode = IndiFitMuscleMapMode.exercise,
       regionIntensities = const <String, double>{};

  const _IndiFitMuscleMapRenderState.intensity({
    required this.regionIntensities,
    required this.unresolvedMuscles,
  }) : mode = IndiFitMuscleMapMode.intensity,
       primarySlugs = const <String>{},
       secondarySlugs = const <String>{};

  const _IndiFitMuscleMapRenderState.noData()
    : mode = IndiFitMuscleMapMode.noData,
      primarySlugs = const <String>{},
      secondarySlugs = const <String>{},
      regionIntensities = const <String, double>{},
      unresolvedMuscles = const <String>[];

  final IndiFitMuscleMapMode mode;
  final Set<String> primarySlugs;
  final Set<String> secondarySlugs;
  final Map<String, double> regionIntensities;
  final List<String> unresolvedMuscles;

  bool get hasMappedRegions =>
      primarySlugs.isNotEmpty ||
      secondarySlugs.isNotEmpty ||
      regionIntensities.isNotEmpty;
}

class _IndiFitMuscleMapPainter extends CustomPainter {
  const _IndiFitMuscleMapPainter({
    required this.bodyModel,
    required this.side,
    required this.renderState,
    required this.colors,
  });

  final IndiFitMuscleMapBodyModel bodyModel;
  final IndiFitMuscleMapSide side;
  final _IndiFitMuscleMapRenderState renderState;
  final B05SemanticColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final viewBox =
        IndiFitMuscleMapGeometryRegistry
            .viewBoxes[IndiFitMuscleMapGeometryRegistry.viewBoxKey(
          bodyModel,
          side,
        )]!;
    final scale = math.min(
      size.width / viewBox.width,
      size.height / viewBox.height,
    );
    if (!scale.isFinite || scale <= 0) return;

    final paintedWidth = viewBox.width * scale;
    final paintedHeight = viewBox.height * scale;
    final offsetX = (size.width - paintedWidth) / 2;
    final offsetY = (size.height - paintedHeight) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);
    canvas.translate(-viewBox.originX, -viewBox.originY);

    final paths = <String, ui.Path>{};
    final regions = IndiFitMuscleMapGeometryRegistry.forView(bodyModel, side);
    final baseFill = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.disabled
      ..isAntiAlias = true;
    final baseStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 / scale
      ..color = colors.textDisabled.withValues(alpha: 0.78)
      ..isAntiAlias = true;

    for (final region in regions) {
      final path = region.toPath();
      paths[region.upstreamSlug] = path;
      canvas.drawPath(path, baseFill);
      canvas.drawPath(path, baseStroke);
    }

    switch (renderState.mode) {
      case IndiFitMuscleMapMode.exercise:
        for (final slug in renderState.primarySlugs) {
          final path = paths[slug];
          if (path != null) {
            _drawPrimary(canvas, path, scale);
          }
        }
        for (final slug in renderState.secondarySlugs) {
          final path = paths[slug];
          if (path != null) {
            _drawSecondary(canvas, path, scale);
          }
        }
      case IndiFitMuscleMapMode.intensity:
        for (final entry in renderState.regionIntensities.entries) {
          final path = paths[entry.key];
          if (path != null) {
            _drawHeat(canvas, path, entry.value, scale);
          }
        }
      case IndiFitMuscleMapMode.noData:
        break;
    }

    canvas.restore();
  }

  void _drawPrimary(ui.Canvas canvas, ui.Path path, double scale) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.success.indicator.withValues(alpha: 0.88)
      ..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 / scale
      ..color = colors.success.foreground
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawSecondary(ui.Canvas canvas, ui.Path path, double scale) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.info.container.withValues(alpha: 0.96)
      ..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / scale
      ..color = colors.info.indicator
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    canvas.save();
    canvas.clipPath(path);
    final hatch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 / scale
      ..color = colors.info.indicator.withValues(alpha: 0.72)
      ..isAntiAlias = true;
    final spacing = 16 / scale;
    for (
      var x = bounds.left - bounds.height;
      x < bounds.right + bounds.height;
      x += spacing
    ) {
      canvas.drawLine(
        ui.Offset(x, bounds.bottom),
        ui.Offset(x + bounds.height, bounds.top),
        hatch,
      );
    }
    canvas.restore();
  }

  void _drawHeat(ui.Canvas canvas, ui.Path path, double value, double scale) {
    final normalized = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = ui.Color.lerp(
        colors.info.container,
        colors.danger.indicator,
        normalized,
      )!
      ..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / scale
      ..color = normalized > 0.5
          ? colors.danger.foreground
          : colors.info.indicator
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _IndiFitMuscleMapPainter oldDelegate) => true;
}
