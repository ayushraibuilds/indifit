import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera platform fake: records start() so tests can assert the camera opens.
class FakeMobileScannerPlatform extends MobileScannerPlatform {
  int startCalls = 0;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> resetZoomScale() async {}
}

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
