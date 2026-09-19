import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import 'thali_plate_layout.dart';

/// Interactive circular Indian Thali plate presenting dishes in traditional
/// center staple (roti/rice) and perimeter bowls (katoris) with an outer macro ring.
class CircularThaliPlate extends StatelessWidget {
  final List<NutritionThaliItem> items;
  final List<NutritionThaliItemPreview> previews;
  final NutritionThaliPreview? preview;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback onAddDish;
  final VoidCallback onViewAllDishes;

  const CircularThaliPlate({
    super.key,
    required this.items,
    required this.previews,
    this.preview,
    this.selectedItemId,
    required this.onSelectItem,
    required this.onAddDish,
    required this.onViewAllDishes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : availableWidth;
        if (availableHeight < 140 || availableWidth < 140) {
          return const SizedBox.shrink();
        }
        final maxDiameter = math.min(availableWidth - 24, availableHeight - 16);
        if (maxDiameter < 140) {
          return const SizedBox.shrink();
        }
        final plateDiameter = maxDiameter.clamp(140.0, 350.0);

        final layout = ThaliPlateLayoutEngine.computeLayout(
          items: items,
          previews: previews,
          colors: colors,
          showAddSlot: true,
        );

        return Center(
          child: SizedBox(
            width: plateDiameter,
            height: plateDiameter,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. RepaintBoundary Stainless Steel Plate Platter & Dynamic Macro Ring
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Semantics(
                      label: preview?.isPartial == true
                          ? 'Thali macro distribution ring with partial nutrition estimate'
                          : 'Thali macro distribution ring',
                      child: CustomPaint(
                        painter: ThaliPlatePainter(
                          colors: colors,
                          preview: preview,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Center Platter Area (Staples / Rotis / Rice or Embossed Plate Center)
                _CenterStaplePlatter(
                  centerStaples: layout.centerStaples,
                  selectedItemId: selectedItemId,
                  plateDiameter: plateDiameter,
                  onSelectItem: onSelectItem,
                ),

                // 3. Perimeter Katori Slots (Dishes, Add Slot, Overflow Slot)
                ...layout.perimeterSlots.map((slot) {
                  return _PositionedKatori(
                    slot: slot,
                    plateDiameter: plateDiameter,
                    selectedItemId: selectedItemId,
                    onSelectItem: onSelectItem,
                    onAddDish: onAddDish,
                    onViewAllDishes: onViewAllDishes,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the stainless steel thali platter and outer dynamic macro distribution ring.
class ThaliPlatePainter extends CustomPainter {
  final B05SemanticColors colors;
  final NutritionThaliPreview? preview;

  ThaliPlatePainter({
    required this.colors,
    this.preview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer rim bevel & metallic platter base
    final platterPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.9,
        colors: [
          colors.surface,
          colors.border.withValues(alpha: 0.6),
          colors.surface,
          colors.border,
        ],
        stops: const [0.0, 0.7, 0.92, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 2, platterPaint);

    // Subtle metallic rim border
    final rimPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 2, rimPaint);

    // Inner bevel groove
    final innerRimPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.90, innerRimPaint);

    // 2. Center staple divider circle
    final centerDividerPaint = Paint()
      ..color = colors.border.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.42, centerDividerPaint);

    // 3. Dynamic Macro Distribution Ring around outer edge
    _paintMacroRing(canvas, center, radius - 3);
  }

  void _paintMacroRing(Canvas canvas, Offset center, double ringRadius) {
    const strokeWidth = 3.5;
    final facts = preview?.aggregate.facts;
    final protein = facts?['protein']?.point?.value.asDouble ?? 0.0;
    final carbs = facts?['carbohydrate']?.point?.value.asDouble ?? 0.0;
    final fat = facts?['fat']?.point?.value.asDouble ?? 0.0;
    final isPartial = preview?.isPartial ?? false;

    // Caloric energy contribution from macros (4 kcal/g P, 4 kcal/g C, 9 kcal/g F)
    final pCal = protein * 4.0;
    final cCal = carbs * 4.0;
    final fCal = fat * 9.0;
    final totalMacroCal = pCal + cCal + fCal;

    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    if (totalMacroCal <= 0.0) {
      // Neutral track when macros are unavailable or 0
      final neutralPaint = Paint()
        ..color = colors.border.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, ringRadius, neutralPaint);
      return;
    }

    final pFraction = pCal / totalMacroCal;
    final cFraction = cCal / totalMacroCal;
    final fFraction = fCal / totalMacroCal;

    // Start at top (-pi / 2)
    double currentAngle = -math.pi / 2;

    void drawMacroArc(Color color, double fraction) {
      if (fraction <= 0.001) return;
      final sweepAngle = fraction * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Inset slightly by 0.02 rad so arcs have a crisp separator gap
      const gap = 0.03;
      if (sweepAngle > gap * 2) {
        canvas.drawArc(
          ringRect,
          currentAngle + gap / 2,
          sweepAngle - gap,
          false,
          paint,
        );
      } else {
        canvas.drawArc(ringRect, currentAngle, sweepAngle, false, paint);
      }
      currentAngle += sweepAngle;
    }

    // 1. Protein arc (Action green)
    drawMacroArc(colors.action, pFraction);

    // 2. Carbs arc (Warning amber)
    drawMacroArc(colors.warning.indicator, cFraction);

    // 3. Fat arc (Info cyan)
    drawMacroArc(colors.info.indicator, fFraction);

    // If partial, draw an indicator dot / dash on the track
    if (isPartial) {
      final partialPaint = Paint()
        ..color = colors.warning.indicator
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, ringRadius - 4, partialPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ThaliPlatePainter oldDelegate) {
    if (oldDelegate.preview != preview) return true;
    if (oldDelegate.colors != colors) return true;
    return false;
  }
}

/// Center platter component rendering staple items (roti stack, rice bowl) or empty placeholder.
class _CenterStaplePlatter extends StatelessWidget {
  final List<ThaliItemSlot> centerStaples;
  final String? selectedItemId;
  final double plateDiameter;
  final ValueChanged<String?> onSelectItem;

  const _CenterStaplePlatter({
    required this.centerStaples,
    required this.selectedItemId,
    required this.plateDiameter,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final centerDiameter = plateDiameter * 0.38;

    if (centerStaples.isEmpty) {
      // Elegant engraved platter centerpiece placeholder
      return Semantics(
        label: 'Center platter, empty',
        child: Container(
          width: centerDiameter,
          height: centerDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface.withValues(alpha: 0.3),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.grain_rounded,
              size: 28,
              color: colors.textDisabled.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    if (centerStaples.length >= 2) {
      return Container(
        width: centerDiameter,
        height: centerDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: _buildHalfStaple(
                context,
                centerStaples[0],
                isTop: true,
              ),
            ),
            Container(height: 1.0, color: colors.border.withValues(alpha: 0.5)),
            Expanded(
              child: _buildHalfStaple(
                context,
                centerStaples[1],
                isTop: false,
              ),
            ),
          ],
        ),
      );
    }

    // Primary staple (e.g. roti or rice)
    final stapleSlot = centerStaples.first;
    final item = stapleSlot.item;
    final isSelected = selectedItemId == item.id;
    final energy = stapleSlot.preview?.calculation.facts['energy']?.point?.value.asDouble;
    final energyStr = energy != null ? '${energy.round()} kcal' : null;

    final quantityStr = '${item.quantity.amount} ${item.quantity.unit.name == 'piece' ? 'pc' : item.quantity.unit.name}';

    return B05TouchTarget(
      minWidth: B05Layout.minTouchTarget,
      minHeight: B05Layout.minTouchTarget,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${item.displayLabel ?? stapleSlot.placement.categoryLabel}, ${stapleSlot.placement.categoryLabel}, $quantityStr${energyStr != null ? ", $energyStr" : ""}',
        child: GestureDetector(
          key: Key('thali_plate_staple_${item.id}'),
          onTap: () {
            onSelectItem(isSelected ? null : item.id);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: B05MotionPolicy.transitionDuration(
              context,
              standard: const Duration(milliseconds: 180),
            ),
            width: centerDiameter,
            height: centerDiameter,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(
                color: isSelected ? colors.action : stapleSlot.placement.tint,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: colors.action.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      stapleSlot.placement.icon,
                      size: 22,
                      color: stapleSlot.placement.tint,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displayLabel ?? stapleSlot.placement.categoryLabel,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      quantityStr,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                    if (energyStr != null)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: B05Radii.smallRadius,
                        ),
                        child: Text(
                          energyStr,
                          style: TextStyle(
                            color: colors.action,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHalfStaple(
    BuildContext context,
    ThaliItemSlot stapleSlot, {
    required bool isTop,
  }) {
    final colors = context.b05Colors;
    final item = stapleSlot.item;
    final isSelected = selectedItemId == item.id;
    final energy = stapleSlot.preview?.calculation.facts['energy']?.point?.value.asDouble;
    final energyStr = energy != null ? '${energy.round()} kcal' : null;
    final quantityStr = '${item.quantity.amount} ${item.quantity.unit.name == 'piece' ? 'pc' : item.quantity.unit.name}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${item.displayLabel ?? stapleSlot.placement.categoryLabel}, ${stapleSlot.placement.categoryLabel}, $quantityStr${energyStr != null ? ", $energyStr" : ""}',
      child: GestureDetector(
        key: Key('thali_plate_staple_${item.id}'),
        onTap: () => onSelectItem(isSelected ? null : item.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: isSelected
              ? colors.action.withValues(alpha: 0.18)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    stapleSlot.placement.icon,
                    size: 16,
                    color: isSelected ? colors.action : stapleSlot.placement.tint,
                  ),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayLabel ?? stapleSlot.placement.categoryLabel,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$quantityStr${energyStr != null ? " · $energyStr" : ""}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positioned wrapper for a perimeter katori slot.
class _PositionedKatori extends StatelessWidget {
  final ThaliPlateSlot slot;
  final double plateDiameter;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback onAddDish;
  final VoidCallback onViewAllDishes;

  const _PositionedKatori({
    required this.slot,
    required this.plateDiameter,
    required this.selectedItemId,
    required this.onSelectItem,
    required this.onAddDish,
    required this.onViewAllDishes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final center = plateDiameter / 2;
    // Perimeter orbit radius: placed nicely between center staple and outer macro ring
    final orbitRadius = plateDiameter * 0.355;
    final katoriSize = (plateDiameter * 0.21).clamp(42.0, 68.0);

    final x = center + orbitRadius * math.cos(slot.angle) - (katoriSize / 2);
    final y = center + orbitRadius * math.sin(slot.angle) - (katoriSize / 2);

    return Positioned(
      left: x,
      top: y,
      width: katoriSize,
      height: katoriSize,
      child: _buildSlotContent(context, colors, katoriSize),
    );
  }

  Widget _buildSlotContent(
    BuildContext context,
    B05SemanticColors colors,
    double size,
  ) {
    switch (slot) {
      case ThaliItemSlot(:final item, :final preview, :final placement):
        final isSelected = selectedItemId == item.id;
        final energy = preview?.calculation.facts['energy']?.point?.value.asDouble;
        final energyStr = energy != null ? '${energy.round()}' : null;

        return B05TouchTarget(
          minWidth: B05Layout.minTouchTarget,
          minHeight: B05Layout.minTouchTarget,
          child: Semantics(
            button: true,
            selected: isSelected,
            label: '${item.displayLabel ?? placement.categoryLabel}, ${placement.categoryLabel}${energyStr != null ? ", $energyStr calories" : ""}',
            child: GestureDetector(
              key: Key('thali_plate_katori_${item.id}'),
              onTap: () {
                onSelectItem(isSelected ? null : item.id);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: B05MotionPolicy.transitionDuration(
                  context,
                  standard: const Duration(milliseconds: 180),
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface,
                  border: Border.all(
                    color: isSelected ? colors.action : placement.tint,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: colors.action.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          placement.icon,
                          size: 16,
                          color: placement.tint,
                        ),
                        const SizedBox(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item.displayLabel ?? placement.categoryLabel,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (energyStr != null)
                          Text(
                            '$energyStr kcal',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case ThaliAddSlot():
        return B05TouchTarget(
          minWidth: B05Layout.minTouchTarget,
          minHeight: B05Layout.minTouchTarget,
          child: Semantics(
            button: true,
            label: 'Add dish to platter',
            child: GestureDetector(
              key: const Key('thali_plate_add_slot'),
              onTap: onAddDish,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface.withValues(alpha: 0.4),
                  border: Border.all(
                    color: colors.action.withValues(alpha: 0.6),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: colors.action,
                    ),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: colors.action,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case ThaliOverflowSlot(:final overflowCount):
        return B05TouchTarget(
          minWidth: B05Layout.minTouchTarget,
          minHeight: B05Layout.minTouchTarget,
          child: Semantics(
            button: true,
            label: 'View all $overflowCount more dishes in list',
            child: GestureDetector(
              key: const Key('thali_plate_overflow_slot'),
              onTap: onViewAllDishes,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceSubtle,
                  border: Border.all(
                    color: colors.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+$overflowCount',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'more',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
