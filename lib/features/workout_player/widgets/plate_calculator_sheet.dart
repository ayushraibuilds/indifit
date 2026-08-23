import 'package:flutter/material.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/responsive_form_primitives.dart';

/// Reusable plate loading calculator view used across the workout player,
/// exercise details sheet, and exercise history.
class PlateCalculatorView extends StatefulWidget {
  final double initialTargetWeight;
  final bool isEditable;
  final bool showHeader;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  const PlateCalculatorView({
    super.key,
    required this.initialTargetWeight,
    this.isEditable = true,
    this.showHeader = false,
    this.onClose,
    this.padding = const EdgeInsets.all(B05Layout.space20),
  });

  @override
  State<PlateCalculatorView> createState() => _PlateCalculatorViewState();
}

class _PlateCalculatorViewState extends State<PlateCalculatorView> {
  late double _targetWeight;
  late final TextEditingController _targetWeightController;
  double _barbellWeight = 20.0; // Standard Olympic Bar
  final Map<double, int> _calculatedPlates = {};
  double _unmatchedWeight = 0.0;

  final List<double> _availablePlates = const [
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
    _targetWeight = widget.initialTargetWeight;
    _targetWeightController = TextEditingController(
      text: _targetWeight % 1 == 0
          ? _targetWeight.toInt().toString()
          : _targetWeight.toStringAsFixed(1),
    );
    _calculatePlates();
  }

  @override
  void didUpdateWidget(covariant PlateCalculatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTargetWeight != widget.initialTargetWeight) {
      _targetWeight = widget.initialTargetWeight;
      _targetWeightController.text = _targetWeight % 1 == 0
          ? _targetWeight.toInt().toString()
          : _targetWeight.toStringAsFixed(1);
      _calculatePlates();
    }
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  void _onTargetWeightChanged(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed >= 0) {
      setState(() {
        _targetWeight = parsed;
        _calculatePlates();
      });
    } else if (value.trim().isEmpty) {
      setState(() {
        _targetWeight = 0.0;
        _calculatePlates();
      });
    }
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
        return const Color(0xFFEF4444);
      case 20.0:
        return const Color(0xFF3B82F6);
      case 15.0:
        return const Color(0xFFFBBF24);
      case 10.0:
        return const Color(0xFF10B981);
      case 5.0:
        return Colors.white;
      case 2.5:
        return Colors.black54;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plate Calculator',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: B05Typography.title(context),
                  ),
                ),
                IconButton(
                  tooltip: 'Close plate calculator',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          IndiFitResponsiveFieldGroup(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Weight (kg)',
                    style: B05Typography.caption(context),
                  ),
                  const SizedBox(height: 4),
                  if (widget.isEditable)
                    TextField(
                      controller: _targetWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onTargetWeightChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixText: 'kg',
                        suffixStyle: TextStyle(color: colors.action, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Text(
                      '${_targetWeight.toStringAsFixed(1)} kg',
                      style: B05Typography.metric(
                        context,
                      ).copyWith(color: colors.action),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Barbell', style: B05Typography.caption(context)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<double>(
                    initialValue: _barbellWeight,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
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
          Text(
            'LOADING PER SIDE',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
          ),
          const SizedBox(height: 12),
          if (_calculatedPlates.isEmpty && _unmatchedWeight == 0.0)
            B05Surface(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(B05Layout.space16),
                  child: Text(
                    'Barbell alone covers target weight.',
                    style: B05Typography.body(context),
                  ),
                ),
              ),
            )
          else
            B05Surface(
              child: Padding(
                padding: const EdgeInsets.all(B05Layout.space16),
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
                                    border: Border.all(color: colors.border),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    weight % 1 == 0
                                        ? '${weight.toInt()}'
                                        : '$weight',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: weight == 5.0
                                          ? colors.textPrimary
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          Container(width: 10, height: 10, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _calculatedPlates.entries
                          .map((e) => '${e.value}x ${e.key}kg')
                          .join('  +  '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_unmatchedWeight > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Still to load: ${_unmatchedWeight.toStringAsFixed(2)} kg per side',
                        style: TextStyle(
                          color: colors.warning.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

/// Modal bottom sheet presentation for plate loading calculation.
class PlateCalculatorSheet extends StatelessWidget {
  final double targetWeight;
  final bool isEditable;

  const PlateCalculatorSheet({
    super.key,
    required this.targetWeight,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    return PlateCalculatorView(
      initialTargetWeight: targetWeight,
      isEditable: isEditable,
      showHeader: true,
    );
  }
}
