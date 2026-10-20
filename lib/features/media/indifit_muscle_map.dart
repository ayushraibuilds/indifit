import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';

import 'indifit_muscle_map_geometry.g.dart';
import 'indifit_muscle_map_taxonomy.dart';

/// The body model used by the local presentation renderer.
enum IndiFitMuscleMapBody { male, female }

/// Which body view(s) the renderer presents.
enum IndiFitMuscleMapView { front, back, both }

/// The two caller-owned data modes plus an explicit no-data state.
///
/// [sets] shades each muscle in four steps by a count of working sets
/// (TF-4). It carries no recovery or fatigue meaning.
enum IndiFitMuscleMapMode { exercise, intensity, noData, sets }

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
       setCounts = null,
       onMuscleTap = null,
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
       secondaryMuscles = const <String>[],
       setCounts = null,
       onMuscleTap = null;

  /// Shades muscles by working sets in four steps ([setStep]); each region
  /// has its own semantics label with its count, and tapping one reports
  /// its concept to [onMuscleTap] (TF-4).
  const IndiFitMuscleMap.sets({
    required Map<String, double> this.setCounts,
    super.key,
    this.onMuscleTap,
    this.bodyModel = IndiFitMuscleMapBody.male,
    this.view = IndiFitMuscleMapView.both,
    this.showTextEquivalent = false,
  }) : mode = IndiFitMuscleMapMode.sets,
       primaryMuscle = null,
       secondaryMuscles = const <String>[],
       intensityValues = null,
       metricLabel = 'Working sets';

  const IndiFitMuscleMap.noData({
    super.key,
    this.bodyModel = IndiFitMuscleMapBody.male,
    this.view = IndiFitMuscleMapView.both,
    this.showTextEquivalent = true,
  }) : mode = IndiFitMuscleMapMode.noData,
       primaryMuscle = null,
       secondaryMuscles = const <String>[],
       intensityValues = null,
       setCounts = null,
       onMuscleTap = null,
       metricLabel = 'Intensity';

  final IndiFitMuscleMapMode mode;
  final String? primaryMuscle;
  final List<String> secondaryMuscles;
  final Map<String, double>? intensityValues;
  final String metricLabel;
  final IndiFitMuscleMapBody bodyModel;
  final IndiFitMuscleMapView view;
  final bool showTextEquivalent;

  /// Display concept ("chest", "back") → working sets, for [sets] mode.
  final Map<String, double>? setCounts;
  final ValueChanged<String>? onMuscleTap;

  /// The four shading steps: none, under 3, 3 to under 6, 6 to under 10,
  /// and 10 or more working sets.
  static int setStep(double sets) => !sets.isFinite || sets <= 0
      ? 0
      : sets < 3
      ? 1
      : sets < 6
      ? 2
      : sets < 10
      ? 3
      : 4;

  /// "4", "4½", "½".
  static String formatSets(double sets) {
    final whole = sets.floor();
    final half = sets - whole >= 0.5;
    if (!half) return '$whole';
    return whole == 0 ? '½' : '$whole½';
  }

  static const IndiFitMuscleMapTaxonomyAdapter _adapter =
      IndiFitMuscleMapTaxonomyAdapter();

  @override
  Widget build(BuildContext context) {
    final renderState = _resolveRenderState();
    final description = _description(renderState);
    final colors = context.b05Colors;

    final setsMode = mode == IndiFitMuscleMapMode.sets;
    return Semantics(
      container: true,
      // In sets mode each region carries its own label and count.
      excludeSemantics: !setsMode,
      label: setsMode ? 'Muscle groups this week map' : 'IndiFit muscle map',
      value: setsMode ? null : description,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MapLayout(
            bodyModel: bodyModel,
            view: view,
            renderState: renderState,
            colors: colors,
            onMuscleTap: onMuscleTap,
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
      case IndiFitMuscleMapMode.sets:
        final counts = setCounts ?? const <String, double>{};
        final steps = <String, int>{};
        final concepts = <String, String>{};
        final unresolved = <String>[];
        for (final entry in counts.entries) {
          final slugs = IndiFitMuscleMapTaxonomyAdapter
              .supportedConceptToGeometry[entry.key.trim().toLowerCase()];
          if (slugs == null) {
            unresolved.add(entry.key);
            continue;
          }
          final step = setStep(entry.value);
          for (final slug in slugs) {
            concepts[slug] ??= entry.key;
            if (step > (steps[slug] ?? -1)) {
              steps[slug] = step;
              concepts[slug] = entry.key;
            }
          }
        }
        return _IndiFitMuscleMapRenderState.sets(
          regionSteps: steps,
          regionConcepts: concepts,
          setCounts: counts,
          unresolvedMuscles: unresolved,
        );
    }
  }

  String _description(_IndiFitMuscleMapRenderState renderState) {
    if (renderState.mode == IndiFitMuscleMapMode.noData) {
      return 'Muscle map unavailable: no reviewed muscle data.';
    }

    if (renderState.mode == IndiFitMuscleMapMode.sets) {
      final trained = renderState.setCounts.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) =>
                '${ExerciseDisplayMuscles.formatMuscle(entry.key)} '
                '${formatSets(entry.value)}',
          )
          .toList(growable: false);
      return trained.isEmpty
          ? 'No working sets in any muscle group yet.'
          : '$metricLabel: ${trained.join(', ')}.';
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
    this.onMuscleTap,
  });

  final IndiFitMuscleMapBody bodyModel;
  final IndiFitMuscleMapView view;
  final _IndiFitMuscleMapRenderState renderState;
  final B05SemanticColors colors;
  final ValueChanged<String>? onMuscleTap;

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
              onMuscleTap: onMuscleTap,
            ),
            child: onMuscleTap == null
                ? const SizedBox.expand()
                : LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final concept = _conceptAt(
                          generatedBody,
                          side,
                          constraints.biggest,
                          details.localPosition,
                          renderState,
                        );
                        if (concept != null) onMuscleTap!(concept);
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
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
       regionIntensities = const <String, double>{},
       regionSteps = const <String, int>{},
       regionConcepts = const <String, String>{},
       setCounts = const <String, double>{};

  const _IndiFitMuscleMapRenderState.intensity({
    required this.regionIntensities,
    required this.unresolvedMuscles,
  }) : mode = IndiFitMuscleMapMode.intensity,
       primarySlugs = const <String>{},
       secondarySlugs = const <String>{},
       regionSteps = const <String, int>{},
       regionConcepts = const <String, String>{},
       setCounts = const <String, double>{};

  const _IndiFitMuscleMapRenderState.noData()
    : mode = IndiFitMuscleMapMode.noData,
      primarySlugs = const <String>{},
      secondarySlugs = const <String>{},
      regionIntensities = const <String, double>{},
      regionSteps = const <String, int>{},
      regionConcepts = const <String, String>{},
      setCounts = const <String, double>{},
      unresolvedMuscles = const <String>[];

  const _IndiFitMuscleMapRenderState.sets({
    required this.regionSteps,
    required this.regionConcepts,
    required this.setCounts,
    required this.unresolvedMuscles,
  }) : mode = IndiFitMuscleMapMode.sets,
       primarySlugs = const <String>{},
       secondarySlugs = const <String>{},
       regionIntensities = const <String, double>{};

  final IndiFitMuscleMapMode mode;
  final Set<String> primarySlugs;
  final Set<String> secondarySlugs;
  final Map<String, double> regionIntensities;

  /// Sets mode: geometry slug → shading step (0–4), slug → the concept it
  /// was shaded for, and the caller's counts by concept.
  final Map<String, int> regionSteps;
  final Map<String, String> regionConcepts;
  final Map<String, double> setCounts;
  final List<String> unresolvedMuscles;

  bool get hasMappedRegions =>
      primarySlugs.isNotEmpty ||
      secondarySlugs.isNotEmpty ||
      regionIntensities.isNotEmpty ||
      regionSteps.isNotEmpty;
}

/// Where the painter draws [side]'s view box inside [size].
({double scale, double dx, double dy, IndiFitMuscleMapViewBox box})?
_viewTransform(
  IndiFitMuscleMapBodyModel bodyModel,
  IndiFitMuscleMapSide side,
  Size size,
) {
  final viewBox = IndiFitMuscleMapGeometryRegistry
      .viewBoxes[IndiFitMuscleMapGeometryRegistry.viewBoxKey(bodyModel, side)]!;
  final scale = math.min(
    size.width / viewBox.width,
    size.height / viewBox.height,
  );
  if (!scale.isFinite || scale <= 0) return null;
  return (
    scale: scale,
    dx: (size.width - viewBox.width * scale) / 2 - viewBox.originX * scale,
    dy: (size.height - viewBox.height * scale) / 2 - viewBox.originY * scale,
    box: viewBox,
  );
}

/// The shaded concept under [point], if any (sets mode).
String? _conceptAt(
  IndiFitMuscleMapBodyModel bodyModel,
  IndiFitMuscleMapSide side,
  Size size,
  Offset point,
  _IndiFitMuscleMapRenderState renderState,
) {
  final transform = _viewTransform(bodyModel, side, size);
  if (transform == null) return null;
  final local = Offset(
    (point.dx - transform.dx) / transform.scale,
    (point.dy - transform.dy) / transform.scale,
  );
  for (final region in IndiFitMuscleMapGeometryRegistry.forView(
    bodyModel,
    side,
  )) {
    final concept = renderState.regionConcepts[region.upstreamSlug];
    if (concept != null && region.toPath().contains(local)) return concept;
  }
  return null;
}

class _IndiFitMuscleMapPainter extends CustomPainter {
  const _IndiFitMuscleMapPainter({
    required this.bodyModel,
    required this.side,
    required this.renderState,
    required this.colors,
    this.onMuscleTap,
  });

  final IndiFitMuscleMapBodyModel bodyModel;
  final IndiFitMuscleMapSide side;
  final _IndiFitMuscleMapRenderState renderState;
  final B05SemanticColors colors;
  final ValueChanged<String>? onMuscleTap;

  /// Sets mode: one node per shaded muscle on this side, labelled with its
  /// count, so the shading is never the only signal.
  @override
  SemanticsBuilderCallback? get semanticsBuilder =>
      renderState.mode != IndiFitMuscleMapMode.sets
      ? null
      : (size) {
          final transform = _viewTransform(bodyModel, side, size);
          if (transform == null) return const [];
          final bounds = <String, Rect>{};
          for (final region in IndiFitMuscleMapGeometryRegistry.forView(
            bodyModel,
            side,
          )) {
            final concept = renderState.regionConcepts[region.upstreamSlug];
            if (concept == null) continue;
            final box = region.toPath().getBounds();
            final rect = Rect.fromLTRB(
              box.left * transform.scale + transform.dx,
              box.top * transform.scale + transform.dy,
              box.right * transform.scale + transform.dx,
              box.bottom * transform.scale + transform.dy,
            );
            bounds[concept] = bounds[concept]?.expandToInclude(rect) ?? rect;
          }
          return [
            for (final entry in bounds.entries)
              CustomPainterSemantics(
                key: ValueKey('muscle_${side.name}_${entry.key}'),
                rect: entry.value,
                properties: SemanticsProperties(
                  label: _setsLabel(
                    entry.key,
                    renderState.setCounts[entry.key] ?? 0,
                  ),
                  button: onMuscleTap != null,
                  onTap: onMuscleTap == null
                      ? null
                      : () => onMuscleTap!(entry.key),
                  textDirection: TextDirection.ltr,
                ),
              ),
          ];
        };

  @override
  bool shouldRebuildSemantics(covariant _IndiFitMuscleMapPainter old) => true;

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
      case IndiFitMuscleMapMode.sets:
        for (final entry in renderState.regionSteps.entries) {
          final path = paths[entry.key];
          if (path != null && entry.value > 0) {
            _drawStep(canvas, path, entry.value, scale);
          }
        }
      case IndiFitMuscleMapMode.noData:
        break;
    }

    canvas.restore();
  }

  /// One brand tone at four strengths; never a warning or danger colour.
  void _drawStep(ui.Canvas canvas, ui.Path path, int step, double scale) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = IndiFitMuscleMapLegend.stepColor(colors, step)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / scale
        ..color = colors.action
        ..isAntiAlias = true,
    );
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

String _setsLabel(String concept, double sets) =>
    '${ExerciseDisplayMuscles.formatMuscle(concept)} group: '
    '${IndiFitMuscleMap.formatSets(sets)} working '
    '${sets == 1 ? 'set' : 'sets'}';

/// The four shading steps with their set ranges (TF-4).
class IndiFitMuscleMapLegend extends StatelessWidget {
  const IndiFitMuscleMapLegend({super.key});

  static const stepLabels = ['½–2½', '3–5½', '6–9½', '10+'];

  static Color stepColor(B05SemanticColors colors, int step) => colors.action
      .withValues(alpha: const <double>[0, 0.22, 0.45, 0.7, 0.95][step]);

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Wrap(
      spacing: B05Layout.space12,
      runSpacing: B05Layout.space4,
      children: [
        for (var step = 1; step <= 4; step++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    stepColor(colors, step),
                    colors.disabled,
                  ),
                  border: Border.all(color: colors.action),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: B05Layout.space4),
              Text(stepLabels[step - 1], style: B05Typography.caption(context)),
            ],
          ),
      ],
    );
  }
}
