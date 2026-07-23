import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class LogWeightBottomSheet extends StatefulWidget {
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
  State<LogWeightBottomSheet> createState() => _LogWeightBottomSheetState();
}

class _LogWeightBottomSheetState extends State<LogWeightBottomSheet> {
  late TextEditingController _controller;
  double _selectedWeight = 70.0;

  @override
  void initState() {
    super.initState();
    _selectedWeight = widget.currentWeight;
    _controller = TextEditingController(text: widget.currentWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    setState(() {
      _selectedWeight = (_selectedWeight + delta).clamp(20.0, 350.0);
      _controller.text = _selectedWeight.toStringAsFixed(1);
    });
  }

  void _save() {
    final val = double.tryParse(_controller.text);
    if (val != null && val >= 20.0 && val <= 350.0) {
      widget.onSave(val);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Log Body Weight',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
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
              _buildStepChip('-0.5 kg', () => _adjust(-0.5)),
              _buildStepChip('-0.1 kg', () => _adjust(-0.1)),
              _buildStepChip('+0.1 kg', () => _adjust(0.1)),
              _buildStepChip('+0.5 kg', () => _adjust(0.5)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Weight Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.cardBackground,
      side: const BorderSide(color: AppColors.border),
      onPressed: onTap,
    );
  }
}
