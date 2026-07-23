import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

import 'log_weight_bottom_sheet.dart';

class WeightSparklineCard extends StatelessWidget {
  final double currentWeight;
  final List<double> weightHistory;
  final ValueChanged<double> onWeightAdjusted;

  const WeightSparklineCard({
    super.key,
    required this.currentWeight,
    required this.weightHistory,
    required this.onWeightAdjusted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weight Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Current weight: ${currentWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                
                // Weight entry Log button
                OutlinedButton.icon(
                  onPressed: () => LogWeightBottomSheet.show(context, currentWeight, onWeightAdjusted),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Log', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (weightHistory.length < 2)
              Container(
                height: 80,
                alignment: Alignment.center,
                child: const Text(
                  'Log at least 2 weight entries to see your trend chart.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 100,
                child: Builder(
                  builder: (context) {
                    final minW = weightHistory.reduce((a, b) => a < b ? a : b) - 1.0;
                    final maxW = weightHistory.reduce((a, b) => a > b ? a : b) + 1.0;
                    final spots = List.generate(
                      weightHistory.length,
                      (i) => FlSpot(i.toDouble(), weightHistory[i]),
                    );

                    return LineChart(
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
                                  const TextStyle(
                                    color: Colors.white,
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
                            color: AppColors.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
