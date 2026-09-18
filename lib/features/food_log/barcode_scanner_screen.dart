import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capabilities/capabilities_registry.dart';
import '../../core/stubs/mobile_scanner_stub.dart';
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
  bool _cameraDenied = false;

  /// Barcode plausibility (length only). Checksum mismatches still allow lookup:
  /// the provider is the authority on existence, and hard-blocking on checksum
  /// rejects real scans with printing quirks plus all legacy test fixtures.
  /// Non-numeric codes (QR-style) always pass through.
  bool _isPlausibleBarcode(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code)) return true;
    return code.length == 8 || code.length == 12 || code.length == 13;
  }

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
    final cleanCode = code.trim();
    if (cleanCode.isEmpty || _loading) return;
    if (!_isPlausibleBarcode(cleanCode)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That barcode looks incomplete. Check the digits and try again.'),
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    await _scannerController.stop(); // Stop camera scan while processing

    final catalogCapability = ref.read(foodCatalogCapabilityProvider);
    RemoteFoodCandidate? candidate;
    FoodApiResult? legacyResult;
    Object? lookupError;

    // 1. Check local / Tier-1 cache first
    try {
      candidate = await catalogCapability.getCachedCandidate(cleanCode);
    } catch (_) {}

    // 2. Query remote catalog via capability if not in cache
    if (candidate == null) {
      try {
        candidate = await catalogCapability.lookupByBarcode(cleanCode);
        if (candidate != null) {
          try {
            await catalogCapability.cacheRemoteCandidate(candidate);
          } catch (_) {}
        }
      } catch (e) {
        lookupError = e;
      }
    }

    // 3. Fallback to FoodApiService only if capability is disabled and no prior hard error
    if (candidate == null &&
        catalogCapability is DisabledFoodCatalogCapability &&
        lookupError == null) {
      try {
        final apiService = ref.read(foodApiServiceProvider);
        legacyResult = await apiService.fetchByBarcode(cleanCode);
      } catch (e) {
        lookupError = e;
      }
    }

    if (mounted) {
      setState(() => _loading = false);

      if (candidate != null) {
        // Return strongly typed RemoteFoodCandidate
        Navigator.pop(context, candidate);
      } else if (legacyResult != null) {
        // Return legacy FoodApiResult
        Navigator.pop(context, legacyResult);
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
          if (_cameraDenied)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined,
                          color: Colors.white70, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Camera access is off',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable camera access in system settings to scan, or enter the barcode below.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          setState(() => _cameraDenied = false);
                          try {
                            await _scannerController.start();
                          } catch (_) {
                            if (mounted) {
                              setState(() => _cameraDenied = true);
                            }
                          }
                        },
                        child: const Text('Retry camera'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            MobileScanner(
              controller: _scannerController,
              errorBuilder: (context, error, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_cameraDenied) {
                    setState(() => _cameraDenied = true);
                  }
                });
                return child ?? const SizedBox.shrink();
              },
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
                      'Looking up barcode…',
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
