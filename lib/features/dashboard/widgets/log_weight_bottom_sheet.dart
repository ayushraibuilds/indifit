import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../data/repositories/workout_repository.dart';

class LogWeightBottomSheet extends ConsumerStatefulWidget {
  final double currentWeight;
  final ValueChanged<double> onSave;

  const LogWeightBottomSheet({
    super.key,
    required this.currentWeight,
    required this.onSave,
  });

  static Future<void> show(BuildContext context, double currentWeight, ValueChanged<double> onSave) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: LogWeightBottomSheet(currentWeight: currentWeight, onSave: onSave),
      ),
    );
  }

  @override
  ConsumerState<LogWeightBottomSheet> createState() => _LogWeightBottomSheetState();
}

class _LogWeightBottomSheetState extends ConsumerState<LogWeightBottomSheet> {
  late TextEditingController _controller;
  double _selectedWeight = 70.0;
  WeightLogStatus? _status;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _selectedWeight = widget.currentWeight;
    _controller = TextEditingController(text: widget.currentWeight.toStringAsFixed(1));
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final status = await repo.getWeightLogStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _loadingStatus = false;
          if (status.isEditingToday && status.todayWeight != null) {
            _selectedWeight = status.todayWeight!;
            _controller.text = status.todayWeight!.toStringAsFixed(1);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    if (_status != null && !_status!.canLog) return;
    setState(() {
      _selectedWeight = (_selectedWeight + delta).clamp(20.0, 350.0);
      _controller.text = _selectedWeight.toStringAsFixed(1);
    });
  }

  void _save() {
    if (_status != null && !_status!.canLog) return;
    final val = double.tryParse(_controller.text);
    if (val != null && val >= 20.0 && val <= 350.0) {
      widget.onSave(val);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _status != null && !_status!.canLog;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log Body Weight',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  if (_loadingStatus)
                    const Text('Checking lock status...', style: TextStyle(fontSize: 11, color: AppColors.textMuted))
                  else if (isLocked)
                    Text(
                      'Locked for ${_status!.daysUntilUnlock} days',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                    )
                  else if (_status?.isEditingToday == true)
                    Text(
                      'Editing Today\'s Entry (${_selectedWeight.toStringAsFixed(1)} kg)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    )
                  else
                    const Text(
                      'New Weekly Entry',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Weight logging is locked for ${_status!.daysUntilUnlock} more days. Weekly tracking avoids noise from daily water weight.',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
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
                  enabled: !isLocked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: !isLocked,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepChip('-0.5 kg', isLocked ? null : () => _adjust(-0.5)),
              _buildStepChip('-0.1 kg', isLocked ? null : () => _adjust(-0.1)),
              _buildStepChip('+0.1 kg', isLocked ? null : () => _adjust(0.1)),
              _buildStepChip('+0.5 kg', isLocked ? null : () => _adjust(0.5)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLocked ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isLocked ? 'Locked for ${_status!.daysUntilUnlock} Days' : 'Save Weight Entry',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, VoidCallback? onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.cardBackground,
      side: const BorderSide(color: AppColors.border),
      onPressed: onTap,
    );
  }
}
