import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Search Input Debouncing Tests', () {
    test('delays query execution until debounce timer elapses', () async {
      Timer? debounceTimer;
      int queryCount = 0;

      void onSearchChanged(String text) {
        if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 300), () {
          queryCount++;
        });
      }

      // Simulate 5 rapid keystrokes within 50ms of each other
      onSearchChanged('c');
      await Future.delayed(const Duration(milliseconds: 50));
      onSearchChanged('ch');
      await Future.delayed(const Duration(milliseconds: 50));
      onSearchChanged('chi');
      await Future.delayed(const Duration(milliseconds: 50));
      onSearchChanged('chic');
      await Future.delayed(const Duration(milliseconds: 50));
      onSearchChanged('chicken');

      // Right now queryCount should be 0 because 300ms has not elapsed since last key
      expect(queryCount, 0);

      // Wait 350ms for debounce timer to fire
      await Future.delayed(const Duration(milliseconds: 350));

      // Should have executed exactly once
      expect(queryCount, 1);

      debounceTimer?.cancel();
    });
  });
}
