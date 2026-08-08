import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';

class RestTimerBottomSheet extends StatefulWidget {
  final int recommendedRestSeconds;

  const RestTimerBottomSheet({super.key, required this.recommendedRestSeconds});

  static Future<void> show(BuildContext context, int restSeconds) async {
    await WakelockPlus.enable();
    if (context.mounted) {
      await showIndiFitBottomSheet<void>(
        context: context,
        semanticLabel: 'Rest timer',
        builder: (context) =>
            RestTimerBottomSheet(recommendedRestSeconds: restSeconds),
      );
    }
    await WakelockPlus.disable();
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
    final colors = context.b05Colors;
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
            backgroundColor: context.b05Colors.section,
            title: const Text('End Rest Period?'),
            content: const Text(
              'Are you sure you want to skip the rest timer early?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Continue Rest'),
              ),
              B05ActionButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                label: 'Skip rest',
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space24,
          B05Layout.space12,
          B05Layout.space24,
          B05Layout.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'REST PERIOD',
              style: B05Typography.caption(
                context,
              ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.action),
                  ),
                ),
                Text(
                  '${_secondsRemaining}s',
                  style: B05Typography.metric(context).copyWith(fontSize: 32),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: B05ActionButton(
                    onPressed: () => setState(() => _secondsRemaining += 30),
                    icon: Icons.add_rounded,
                    label: 'Add 30 sec',
                    emphasis: B05ActionEmphasis.secondary,
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: B05ActionButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Skip rest',
                    emphasis: B05ActionEmphasis.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
