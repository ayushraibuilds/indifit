import 'package:flutter/material.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../core/widgets/responsive_form_primitives.dart';
import '../../../data/models/b02_execution_models.dart';

/// Pure presentation predicate to determine whether an exercise is relevant for
/// barbell plate calculation per docs/reference/ui/REFERENCE_GUIDE.md:363
/// ("plate calculator should be attached to relevant barbell exercises").
///
/// Order of operations:
/// 1. Hard-false on typed bodyweight load basis.
/// 2. Blocklist evaluated first (excludes non-barbell equipment and bodyweight/pulley families).
/// 3. Allowlist evaluated second (matches explicit barbell or canonical barbell lifts).
/// 4. Default-show for unrecognized exercise names (avoids hiding utility on unknown lifts).
bool isBarbellPlateCalculatorSupported({
  required String exerciseName,
  B02LoadBasis? loadBasis,
}) {
  if (loadBasis == B02LoadBasis.bodyweight) return false;
  final name = exerciseName.trim().toLowerCase();
  if (name.isEmpty) return true;

  // Blocklist evaluated first:
  const blocklist = [
    'dumbbell',
    'cable',
    'machine',
    'band',
    'kettlebell',
    'bodyweight',
    'pull-up',
    'pullup',
    'chin-up',
    'chinup',
    'pulldown',
    'lat pulldown',
    'dip',
    'push-up',
    'pushup',
    'crunch',
    'plank',
    'hyperextension',
  ];
  for (final term in blocklist) {
    if (name.contains(term)) return false;
  }

  // Allowlist evaluated second:
  if (name.contains('barbell')) return true;
  const allowlist = [
    'deadlift',
    'squat',
    'bench press',
    'overhead press',
    'clean and jerk',
    'snatch',
    'power clean',
    'front squat',
    'zercher',
    'good morning',
    'hip thrust',
    'pendlay row',
    'barbell row',
  ];
  for (final term in allowlist) {
    if (name.contains(term)) return true;
  }

  // Explicit documented default:
  return true;
}

/// Reusable plate loading calculator view used across the workout player,
/// exercise details sheet, and exercise history.
class PlateCalculatorView extends StatefulWidget {
  final double initialTargetWeight;
  final bool isEditable;
  final bool showHeader;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;
  final ValueChanged<double>? onApplyWeight;

  const PlateCalculatorView({
    super.key,
    required this.initialTargetWeight,
    this.isEditable = true,
    this.showHeader = false,
    this.onClose,
    this.padding = const EdgeInsets.all(B05Layout.space20),
    this.onApplyWeight,
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

  static String _formatPlateEntry(MapEntry<double, int> entry) {
    final weightStr =
        entry.key % 1 == 0 ? entry.key.toStringAsFixed(1) : '${entry.key}';
    return '${entry.value} × $weightStr kg';
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
                  onPressed:
                      widget.onClose ?? () => Navigator.of(context).maybePop(),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: _onTargetWeightChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixText: 'kg',
                        suffixStyle: TextStyle(
                          color: colors.action,
                          fontWeight: FontWeight.bold,
                        ),
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
                    Semantics(
                      label:
                          'Barbell loading diagram: ${_calculatedPlates.entries.map(_formatPlateEntry).join(', ')} per side',
                      child: SingleChildScrollView(
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
                            Container(
                              width: 10,
                              height: 10,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _calculatedPlates.entries
                          .map(_formatPlateEntry)
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
          if (widget.onApplyWeight != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: B05ActionButton(
                label: 'Apply to set',
                hint:
                    'Apply ${_targetWeight % 1 == 0 ? _targetWeight.toInt() : _targetWeight.toStringAsFixed(1)} kg to set input',
                icon: Icons.check_rounded,
                onPressed: () => widget.onApplyWeight!(_targetWeight),
              ),
            ),
          ],
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
  final ValueChanged<double>? onApplyWeight;
  final VoidCallback? onClose;

  const PlateCalculatorSheet({
    super.key,
    required this.targetWeight,
    this.isEditable = true,
    this.onApplyWeight,
    this.onClose,
  });

  /// Opens the plate calculator as an IndiFit bottom sheet.
  ///
  /// To ensure single delivery and prevent double writes, callers should
  /// either supply [onApplyWeight] or consume the returned [Future<double?>].
  static Future<double?> show({
    required BuildContext context,
    required double initialWeight,
    ValueChanged<double>? onApplyWeight,
  }) {
    return showIndiFitBottomSheet<double>(
      context: context,
      semanticLabel: 'Plate calculator',
      builder: (sheetContext) => PlateCalculatorSheet(
        targetWeight: initialWeight,
        onApplyWeight: (weight) {
          onApplyWeight?.call(weight);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlateCalculatorView(
      initialTargetWeight: targetWeight,
      isEditable: isEditable,
      showHeader: true,
      onApplyWeight: onApplyWeight == null
          ? null
          : (weight) {
              Navigator.of(context).pop(weight);
              onApplyWeight!(weight);
            },
      onClose: onClose,
    );
  }
}
