import 'package:flutter/material.dart';

/// Lightweight simulator stub for `mobile_scanner`.
///
/// Enables compilation and UI testing on Apple Silicon iOS simulators where
/// native GoogleMLKit precompiled CocoaPods binaries lack simulator ARM64 slices.
class MobileScannerController {
  Future<void> start() async {}
  Future<void> stop() async {}
  void dispose() {}
}

class Barcode {
  final String? rawValue;
  const Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;
  const BarcodeCapture({this.barcodes = const []});
}

typedef MobileScannerErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  Widget? child,
);

class MobileScanner extends StatelessWidget {
  final MobileScannerController? controller;
  final MobileScannerErrorBuilder? errorBuilder;
  final void Function(BarcodeCapture capture)? onDetect;

  const MobileScanner({
    super.key,
    this.controller,
    this.errorBuilder,
    this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.qr_code_scanner, color: Colors.white54, size: 56),
              SizedBox(height: 12),
              Text(
                'Camera Inactive (Simulator Mode)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Enter barcode numbers using the manual input below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
