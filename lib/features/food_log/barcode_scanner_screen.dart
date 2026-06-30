import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/food_api_service.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeScanned(String code) async {
    if (_loading) return;
    
    setState(() => _loading = true);
    _scannerController.stop(); // Stop camera scan while processing

    final apiService = ref.read(foodApiServiceProvider);
    final result = await apiService.fetchByBarcode(code);

    if (mounted) {
      setState(() => _loading = false);
      
      if (result != null) {
        // Return found result back to search screen
        Navigator.pop(context, result);
      } else {
        // Show not found dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Product Not Found'),
            content: Text('Could not find product with barcode "$code" in Open Food Facts.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _scannerController.start(); // Restart scanner
                },
                child: const Text('Try Again', style: TextStyle(color: AppColors.primary)),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Food Barcode'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. Mobile Scanner widget
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null) {
                  _onBarcodeScanned(rawValue);
                  break;
                }
              }
            },
          ),
          
          // 2. Scan Reticle Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          
          // 3. Manual code fallback layout (Crucial for Simulator testing)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Simulator Testing: Enter barcode manually',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 8901030357771', // Standard Indian Barcode
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (_manualController.text.isNotEmpty) {
                            _onBarcodeScanned(_manualController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Lookup'),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // 4. Full screen loading modal
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Searching Open Food Facts...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
