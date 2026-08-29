import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

import 'log_weight_bottom_sheet.dart';

class WeightSparklineCard extends StatelessWidget {
  final double currentWeight;
  final List<double> weightHistory;
  final Future<void> Function(double) onWeightAdjusted;

  const WeightSparklineCard({
    super.key,
    required this.currentWeight,
    required this.weightHistory,
    required this.onWeightAdjusted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      radius: B05SurfaceRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight Progress',
                      style: B05Typography.title(context).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current weight: ${currentWeight.toStringAsFixed(1)} kg',
                      style: B05Typography.caption(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Weight entry Log button
              OutlinedButton.icon(
                onPressed: () => LogWeightBottomSheet.show(
                  context,
                  currentWeight,
                  onWeightAdjusted,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Log', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.action,
                  side: BorderSide(color: colors.action),
                  minimumSize: const Size(64, B05Layout.minTouchTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (weightHistory.isEmpty)
            Container(
              height: 80,
              alignment: Alignment.center,
              child: Text(
                'Log your body weight to track your progress trend over time.',
                style: B05Typography.caption(context).copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else if (weightHistory.length == 1)
            Container(
              height: 80,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '1 weigh-in logged (${currentWeight.toStringAsFixed(1)} kg)',
                    style: B05Typography.label(context).copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a second weigh-in on another day to see your trend line.',
                    style: B05Typography.caption(context).copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 100,
              child: Builder(
                builder: (context) {
                  final minW =
                      weightHistory.reduce((a, b) => a < b ? a : b) - 1.0;
                  final maxW =
                      weightHistory.reduce((a, b) => a > b ? a : b) + 1.0;
                  final spots = List.generate(
                    weightHistory.length,
                    (i) => FlSpot(i.toDouble(), weightHistory[i]),
                  );

                  return Semantics(
                    container: true,
                    label:
                        'Weight progress chart showing ${weightHistory.length} recorded weigh-ins. Latest: ${currentWeight.toStringAsFixed(1)} kg.',
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.y.toStringAsFixed(1)} kg',
                                  TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        minX: 0,
                        maxX: (weightHistory.length - 1).toDouble(),
                        minY: minW,
                        maxY: maxW,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: colors.action,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: colors.action.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
