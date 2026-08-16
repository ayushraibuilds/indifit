import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';

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
    final colors = context.b05Colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.section,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.privacy_tip_rounded,
                color: colors.success.indicator,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '100% On-Device Data Storage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Local Primary Storage: All food logs, custom routines, weight measurements, and settings remain stored inside an offline SQLite database on your device.\n\n'
            '• Cloud AI Features: When enabled, AI meal estimation, photo analysis, routine generation, and Open Food Facts lookups send text or photo queries to secure servers.\n\n'
            '• Strict Offline Mode: Turning on Offline Mode blocks app-initiated remote requests, photo uploads, external food lookups, video links, and remote diagnostic reporting.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: colors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anonymous Diagnostic Logging',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Help improve stability by sending non-personal crash logs.',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _telemetryEnabled,
                onChanged: (val) {
                  setState(() => _telemetryEnabled = val);
                  widget.onTelemetryChanged?.call(val);
                },
                activeTrackColor: colors.action,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
