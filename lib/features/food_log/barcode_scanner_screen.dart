import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../data/repositories/food_api_service.dart';
import 'custom_food_editor_screen.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scanAnimation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeScanned(String code) async {
    if (_loading) return;

    setState(() => _loading = true);
    await _scannerController.stop(); // Stop camera scan while processing

    final apiService = ref.read(foodApiServiceProvider);
    FoodApiResult? result;
    Object? lookupError;
    try {
      result = await apiService.fetchByBarcode(code);
    } catch (e) {
      lookupError = e;
    }

    if (mounted) {
      setState(() => _loading = false);

      if (result != null) {
        // Return found result back to search screen
        Navigator.pop(context, result);
      } else if (lookupError != null) {
        await showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: context.b05Colors.surface,
            title: const Text('Barcode Lookup Unavailable'),
            content: Text(
              lookupError is StateError
                  ? 'This barcode could not be looked up. Try again.'
                  : 'We could not reach the food database. Your scan was not lost; try again when you are connected.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Search foods'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await _scannerController.start();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      } else {
        // Show not found dialog
        await showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: context.b05Colors.surface,
            title: const Text('Couldn’t find that product'),
            content: const Text(
              'Search by name instead, or create a custom food if this product is new.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Search foods'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx); // Close dialog
                  await _scannerController.start(); // Restart scanner
                },
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx); // Close dialog
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomFoodEditorScreen(initialBarcode: code),
                    ),
                  );
                  if (created == true && mounted) {
                    Navigator.pop(
                      context,
                      true,
                    ); // Return true to indicate custom item created
                  } else {
                    await _scannerController.start();
                  }
                },
                child: const Text('Create Custom Food'),
              ),
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
        backgroundColor: context.b05Colors.page,
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

          // 2. Scan Reticle Overlay with animated scan line
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: context.b05Colors.action, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Positioned(
                          top: _scanAnimation.value * 235,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.b05Colors.action,
                              boxShadow: [
                                BoxShadow(
                                  color: context.b05Colors.action.withValues(
                                    alpha: 0.8,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
              color: context.b05Colors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter a barcode manually',
                    style: TextStyle(
                      color: context.b05Colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 8901030357771',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
                          backgroundColor: context.b05Colors.action,
                          foregroundColor: context.b05Colors.onAction,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Lookup'),
                      ),
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: context.b05Colors.action),
                    const SizedBox(height: 16),
                    const Text(
                      'Searching Open Food Facts...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
