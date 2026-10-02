import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Test fake for `MobileScanner` view, allowing tests to simulate camera
/// detection events without native camera hardware.
Widget fakeMobileScannerViewBuilder({
  Key? key,
  required MobileScannerController controller,
  required Widget Function(BuildContext context, MobileScannerException error)?
  errorBuilder,
  required void Function(BarcodeCapture capture) onDetect,
}) {
  return Container(
    key: key ?? const ValueKey('fake_mobile_scanner'),
    color: Colors.black,
    child: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Camera Inactive (Simulator Mode)',
              style: TextStyle(color: Colors.white),
            ),
            ElevatedButton(
              key: const ValueKey('simulate_barcode_detection'),
              onPressed: () => onDetect(
                const BarcodeCapture(
                  barcodes: [Barcode(rawValue: '8901030383704')],
                ),
              ),
              child: const Text('Simulate Scan'),
            ),
          ],
        ),
      ),
    ),
  );
}
