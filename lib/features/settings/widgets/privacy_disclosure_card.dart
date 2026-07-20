import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class PrivacyDisclosureCard extends StatefulWidget {
  final bool initialTelemetryEnabled;
  final ValueChanged<bool>? onTelemetryChanged;

  const PrivacyDisclosureCard({
    super.key,
    this.initialTelemetryEnabled = false,
    this.onTelemetryChanged,
  });

  @override
  State<PrivacyDisclosureCard> createState() => _PrivacyDisclosureCardState();
}

class _PrivacyDisclosureCardState extends State<PrivacyDisclosureCard> {
  late bool _telemetryEnabled;

  @override
  void initState() {
    super.initState();
    _telemetryEnabled = widget.initialTelemetryEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('100% On-Device Data Storage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Local Data Only: All food logs, custom routines, weight measurements, and settings remain stored strictly inside an offline SQLite database on your device.\n\n'
            '• Zero Cloud Tracking: IndiFit does not collect personal identifiers or transmit data off your device.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anonymous Diagnostic Logging', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Help improve stability by sending non-personal crash logs.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _telemetryEnabled,
                onChanged: (val) {
                  setState(() => _telemetryEnabled = val);
                  widget.onTelemetryChanged?.call(val);
                },
                activeColor: AppColors.primary,
              )
            ],
          )
        ],
      ),
    );
  }
}
