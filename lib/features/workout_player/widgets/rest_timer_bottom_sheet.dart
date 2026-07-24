import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/colors.dart';

class RestTimerBottomSheet extends StatefulWidget {
  final int recommendedRestSeconds;

  const RestTimerBottomSheet({
    super.key,
    required this.recommendedRestSeconds,
  });

  static Future<void> show(BuildContext context, int restSeconds) async {
    WakelockPlus.enable();
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RestTimerBottomSheet(recommendedRestSeconds: restSeconds),
    );
    WakelockPlus.disable();
  }

  @override
  State<RestTimerBottomSheet> createState() => _RestTimerBottomSheetState();
}

class _RestTimerBottomSheetState extends State<RestTimerBottomSheet> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.recommendedRestSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        t.cancel();
        NotificationService.showRestTimerFinishedNotification();
        Vibration.hasVibrator().then((hasVib) {
          if (hasVib == true) {
            Vibration.vibrate(duration: 500);
          }
        });
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.recommendedRestSeconds > 0
        ? _secondsRemaining / widget.recommendedRestSeconds
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('End Rest Period?'),
            content: const Text('Are you sure you want to skip the rest timer early?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Continue Rest'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Skip Rest'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Text(
            'REST PERIOD',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              Text(
                '${_secondsRemaining}s',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _secondsRemaining += 30),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('+30s'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                child: const Text('Skip Rest'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
