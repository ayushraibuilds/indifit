import 'package:flutter_test/flutter_test.dart';

double calculate1RM(double weight, int reps) {
  if (reps <= 0 || weight <= 0) return 0.0;
  return weight * (1 + reps / 30.0);
}

void main() {
  group('Progressive Overload 1RM Tests', () {
    test('calculates 1RM accurately using Epley formula', () {
      // 100kg for 10 reps -> 100 * (1 + 10/30) = 133.33 kg
      final oneRm = calculate1RM(100.0, 10);
      expect(oneRm, closeTo(133.33, 0.01));
    });

    test('detects PR when current 1RM exceeds previous 1RM', () {
      final prev1Rm = calculate1RM(100.0, 8); // 126.66 kg
      final current1Rm = calculate1RM(102.5, 8); // 129.83 kg

      expect(current1Rm > prev1Rm, isTrue);
    });

    test('does not trigger PR when current 1RM is lower', () {
      final prev1Rm = calculate1RM(100.0, 10); // 133.33 kg
      final current1Rm = calculate1RM(95.0, 10); // 126.66 kg

      expect(current1Rm > prev1Rm, isFalse);
    });
  });
}
