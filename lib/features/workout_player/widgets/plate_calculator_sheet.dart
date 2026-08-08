import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/responsive_form_primitives.dart';

class PlateCalculatorSheet extends StatefulWidget {
  final double targetWeight;

  const PlateCalculatorSheet({super.key, required this.targetWeight});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _targetWeight;
  double _barbellWeight = 20.0; // Standard Olympic Bar
  final Map<double, int> _calculatedPlates = {};
  double _unmatchedWeight = 0.0;

  final List<double> _availablePlates = [
    25.0,
    20.0,
    15.0,
    10.0,
    5.0,
    2.5,
    1.25,
  ];

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.targetWeight;
    _calculatePlates();
  }

  void _calculatePlates() {
    _calculatedPlates.clear();
    double remaining = (_targetWeight - _barbellWeight) / 2.0;

    if (remaining <= 0) {
      _unmatchedWeight = 0.0;
      return;
    }

    for (final plate in _availablePlates) {
      final count = (remaining / plate).floor();
      if (count > 0) {
        _calculatedPlates[plate] = count;
        remaining -= count * plate;
      }
    }

    _unmatchedWeight = double.parse(remaining.toStringAsFixed(2));
  }

  Color _getPlateColor(double weight) {
    switch (weight) {
      case 25.0:
        return Colors.redAccent;
      case 20.0:
        return Colors.blueAccent;
      case 15.0:
        return Colors.amber;
      case 10.0:
        return Colors.green;
      case 5.0:
        return Colors.white;
      case 2.5:
        return Colors.black54;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Plate Calculator',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Close plate calculator',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IndiFitResponsiveFieldGroup(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Weight (kg)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_targetWeight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barbell',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<double>(
                    value: _barbellWeight,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 20.0,
                        child: Text(
                          '20 kg (Olympic)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 15.0,
                        child: Text(
                          '15 kg (Women)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 10.0,
                        child: Text(
                          '10 kg (EZ Bar)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _barbellWeight = val;
                          _calculatePlates();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'LOADING PER SIDE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_calculatedPlates.isEmpty && _unmatchedWeight == 0.0)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Barbell alone covers target weight.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 6, color: Colors.grey),
                          ..._calculatedPlates.entries.map((entry) {
                            final double weight = entry.key;
                            final int count = entry.value;
                            return Row(
                              children: List.generate(
                                count,
                                (_) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  width: weight >= 20 ? 12 : 8,
                                  height: weight >= 20 ? 50 : 36,
                                  decoration: BoxDecoration(
                                    color: _getPlateColor(weight),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    weight % 1 == 0
                                        ? '${weight.toInt()}'
                                        : '$weight',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _calculatedPlates.entries
                          .map((e) => '${e.value}x ${e.key}kg')
                          .join('  +  '),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
