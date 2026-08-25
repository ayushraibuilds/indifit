import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../settings/unit_preference.dart';

class LogWeightBottomSheet extends ConsumerStatefulWidget {
  final double currentWeight;
  final Future<void> Function(double) onSave;

  const LogWeightBottomSheet({
    super.key,
    required this.currentWeight,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context,
    double currentWeight,
    Future<void> Function(double) onSave,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.b05Colors.section,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: LogWeightBottomSheet(
            currentWeight: currentWeight,
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<LogWeightBottomSheet> createState() =>
      _LogWeightBottomSheetState();
}

class _LogWeightBottomSheetState extends ConsumerState<LogWeightBottomSheet> {
  late TextEditingController _controller;
  double _selectedWeight = 70.0;
  String _units = UnitPreferenceNotifier.metric;
  WeightLogStatus? _status;
  bool _loadingStatus = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitPreferenceProvider);
    _selectedWeight = UnitPreferencePresentation.weightForDisplay(
      widget.currentWeight,
      _units,
    );
    _controller = TextEditingController(
      text: _selectedWeight.toStringAsFixed(1),
    );
    _checkStatus();
  }

  bool _statusError = false;

  Future<void> _checkStatus() async {
    setState(() {
      _loadingStatus = true;
      _statusError = false;
    });
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final status = await repo.getWeightLogStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _loadingStatus = false;
          _statusError = false;
          if (status.isEditingToday && status.todayWeight != null) {
            _selectedWeight = UnitPreferencePresentation.weightForDisplay(
              status.todayWeight!,
              _units,
            );
            _controller.text = _selectedWeight.toStringAsFixed(1);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingStatus = false;
          _statusError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isSaveDisabled =>
      _loadingStatus ||
      _isSaving ||
      _statusError ||
      (_status != null && !_status!.canLog);

  void _adjust(double delta) {
    if (_isSaveDisabled) return;
    setState(() {
      final minimum = UnitPreferencePresentation.weightForDisplay(
        minimumLoggedWeightKg,
        _units,
      );
      final maximum = UnitPreferencePresentation.weightForDisplay(
        maximumLoggedWeightKg,
        _units,
      );
      _selectedWeight = (_selectedWeight + delta).clamp(minimum, maximum);
      _controller.text = _selectedWeight.toStringAsFixed(1);
    });
  }

  Future<void> _save() async {
    if (_isSaveDisabled) return;
    final displayed = double.tryParse(_controller.text.trim());
    final kilograms = displayed == null
        ? null
        : UnitPreferencePresentation.weightForStorage(displayed, _units);
    if (kilograms == null || !isValidLoggedWeightKg(kilograms)) {
      final minimum = UnitPreferencePresentation.weightForDisplay(
        minimumLoggedWeightKg,
        _units,
      );
      final maximum = UnitPreferencePresentation.weightForDisplay(
        maximumLoggedWeightKg,
        _units,
      );
      final symbol = UnitPreferencePresentation.weightSymbol(_units);
      setState(
        () => _errorMessage =
            'Enter a weight between ${_formatWeightLimit(minimum)} '
            'and ${_formatWeightLimit(maximum)} $symbol.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(kilograms);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Weight could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(unitPreferenceProvider, (previous, next) {
      if (previous == next) return;
      final previousUnits = previous ?? _units;
      final kilograms = UnitPreferencePresentation.weightForStorage(
        _selectedWeight,
        previousUnits,
      );
      setState(() {
        _units = next;
        _selectedWeight = UnitPreferencePresentation.weightForDisplay(
          kilograms,
          next,
        );
        _controller.text = _selectedWeight.toStringAsFixed(1);
      });
    });
    final colors = context.b05Colors;
    final isLocked = _status != null && !_status!.canLog;
    final weightSymbol = UnitPreferencePresentation.weightSymbol(_units);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Body Weight',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_loadingStatus)
                      Text(
                        'Checking lock status...',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      )
                    else if (isLocked)
                      Text(
                        'Locked for ${_status!.daysUntilUnlock} days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.warning.indicator,
                        ),
                      )
                    else if (_status?.isEditingToday == true)
                      Text(
                        'Editing Today\'s Entry (${_selectedWeight.toStringAsFixed(1)} $weightSymbol)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.action,
                        ),
                      )
                    else
                      Text(
                        'New Weekly Entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.success.indicator,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.container,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.warning.indicator.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    color: colors.warning.indicator,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Weight logging is locked for ${_status!.daysUntilUnlock} more days. Weekly tracking avoids noise from daily water weight.',
                      style: TextStyle(
                        color: colors.warning.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.danger.container,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.danger.indicator.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.danger.indicator,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: colors.danger.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSaveDisabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !_isSaveDisabled,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Weight ($weightSymbol)',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    suffixText: weightSymbol,
                    suffixStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.focus, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val);
                    if (d != null) {
                      _selectedWeight = d;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick increment / decrement chips
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStepChip(
                context,
                '-0.5 $weightSymbol',
                _isSaveDisabled ? null : () => _adjust(-0.5),
              ),
              _buildStepChip(
                context,
                '-0.1 $weightSymbol',
                _isSaveDisabled ? null : () => _adjust(-0.1),
              ),
              _buildStepChip(
                context,
                '+0.1 $weightSymbol',
                _isSaveDisabled ? null : () => _adjust(0.1),
              ),
              _buildStepChip(
                context,
                '+0.5 $weightSymbol',
                _isSaveDisabled ? null : () => _adjust(0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaveDisabled ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                disabledBackgroundColor: colors.disabled,
                disabledForegroundColor: colors.textDisabled,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAction,
                      ),
                    )
                  : Text(
                      _loadingStatus
                          ? 'Checking Status...'
                          : isLocked
                          ? 'Locked for ${_status!.daysUntilUnlock} Days'
                          : 'Save Weight Entry',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(
    BuildContext context,
    String label,
    VoidCallback? onTap,
  ) {
    final colors = context.b05Colors;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      backgroundColor: colors.inset,
      side: BorderSide(color: colors.border),
      onPressed: onTap,
    );
  }
}

String _formatWeightLimit(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
