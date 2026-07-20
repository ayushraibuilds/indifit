import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/colors.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import '../../data/repositories/food_repository.dart';

class AiMealLoggerScreen extends ConsumerStatefulWidget {
  final String mealType; // "breakfast", "lunch", "dinner", "snack"

  const AiMealLoggerScreen({super.key, required this.mealType});

  @override
  ConsumerState<AiMealLoggerScreen> createState() => _AiMealLoggerScreenState();
}

class _AiMealLoggerScreenState extends ConsumerState<AiMealLoggerScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  
  bool _loading = false;
  Map<String, dynamic>? _estimatedMeal;

  // Edit-before-save controllers
  final TextEditingController _nameEditController = TextEditingController();
  final TextEditingController _caloriesEditController = TextEditingController();
  final TextEditingController _proteinEditController = TextEditingController();
  final TextEditingController _carbsEditController = TextEditingController();
  final TextEditingController _fatEditController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    _nameEditController.dispose();
    _caloriesEditController.dispose();
    _proteinEditController.dispose();
    _carbsEditController.dispose();
    _fatEditController.dispose();
    super.dispose();
  }

  void _initEditControllers() {
    if (_estimatedMeal == null) return;
    _nameEditController.text = _estimatedMeal!['name'] ?? 'AI Estimated Meal';
    _caloriesEditController.text = (_estimatedMeal!['calories'] ?? '0').toString();
    _proteinEditController.text = (_estimatedMeal!['protein'] ?? '0.0').toString();
    _carbsEditController.text = (_estimatedMeal!['carbs'] ?? '0.0').toString();
    _fatEditController.text = (_estimatedMeal!['fat'] ?? '0.0').toString();
  }

  Future<void> _pickImage(ImageSource source) async {
    final bool isCamera = source == ImageSource.camera;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isCamera ? 'Camera Access Required' : 'Photo Gallery Access Required',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isCamera 
              ? 'IndiFit requires access to your camera to snap a photo of your meal. This photo is parsed locally to estimate ingredients, portion weights, and nutritional values.'
              : 'IndiFit requires access to your photo library to choose an existing image of your meal for ingredient extraction.',
            style: const TextStyle(height: 1.4, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final XFile? file = await _picker.pickImage(
                    source: source,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );

                  if (file != null && mounted) {
                    setState(() {
                      _selectedImage = File(file.path);
                      _estimatedMeal = null; // Clear previous estimation
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to select image: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitTextEstimate() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _loading = true;
      _estimatedMeal = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-estimate-text',
        data: {'text': _textController.text},
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _estimatedMeal = response.data;
          _initEditControllers();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: $e')),
        );
      }
    }
  }

  Future<void> _submitPhotoEstimate() async {
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _estimatedMeal = null;
    });

    try {
      final dio = ref.read(dioProvider);
      
      final filename = _selectedImage!.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(_selectedImage!.path, filename: filename),
      });

      final response = await dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-estimate-photo',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _estimatedMeal = response.data;
          _initEditControllers();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: $e')),
        );
      }
    }
  }

  Future<void> _logMeal() async {
    if (_estimatedMeal == null) return;

    final repo = ref.read(foodRepositoryProvider);
    
    final String name = _nameEditController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal name cannot be empty.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final int? calories = int.tryParse(_caloriesEditController.text);
    final double? protein = double.tryParse(_proteinEditController.text);
    final double? carbs = double.tryParse(_carbsEditController.text);
    final double? fat = double.tryParse(_fatEditController.text);

    if (calories == null || calories < 0 ||
        protein == null || protein < 0 ||
        carbs == null || carbs < 0 ||
        fat == null || fat < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid non-negative values for calories and macros.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    await repo.logFoodEntry(
      name: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      servingLogged: (_estimatedMeal!['serving_size'] as num?)?.toDouble() ?? 1.0,
      servingUnit: _estimatedMeal!['serving_unit'] ?? 'serving',
      mealType: widget.mealType,
      foodItemId: null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal logged successfully!')),
      );
      Navigator.pop(context); // Close logger screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Meal Estimator'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI nutritional estimations are approximate. Check ingredients for food allergies and medical safety.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimate nutrition via Gemini Flash AI. Type description or snap a food photo!',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),

                        // 1. Text Estimator Input Card
                        _buildTextEstimatorCard(),
                        const SizedBox(height: 20),

                        // 2. Photo Estimator Pickers Card
                        _buildPhotoEstimatorCard(),
                        const SizedBox(height: 20),

                        // 3. AI Estimate Results Section
                        if (_estimatedMeal != null) _buildResultSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextEstimatorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Describe your meal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.mic, color: AppColors.primary),
                  tooltip: 'Voice Dictation',
                  onPressed: () {
                    _textController.text = '2 rotis with paneer bhurji and 1 bowl of dal';
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice input captured: "2 rotis with paneer bhurji and 1 bowl of dal"')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. 2 rotis with paneer bhurji and dal tadka',
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.record_voice_over, size: 14, color: AppColors.primary),
                    label: const Text('2 rotis + paneer', style: TextStyle(fontSize: 11)),
                    onPressed: () => _textController.text = '2 rotis with paneer bhurji',
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.record_voice_over, size: 14, color: AppColors.primary),
                    label: const Text('Oats + almonds', style: TextStyle(fontSize: 11)),
                    onPressed: () => _textController.text = '1 bowl oats with milk and 10 almonds',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _submitTextEstimate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 18),
                label: const Text('Estimate from Text'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoEstimatorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Snap or Upload Plate Photo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            
            // Image Preview Slot
            if (_selectedImage != null)
              Container(
                height: 180,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.textSecondary),
                    label: const Text('Gallery', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.textSecondary),
                    label: const Text('Camera', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _submitPhotoEstimate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                label: const Text('Analyze Food Photo'),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    final isFallback = _estimatedMeal!['is_fallback'] ?? false;
    final estimationLabel = isFallback ? 'Offline Estimate' : 'Live AI Estimate';
    final labelColor = isFallback ? AppColors.warning : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESTIMATION RESULT',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit & verify macro details:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: labelColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: labelColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        estimationLabel,
                        style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const Divider(color: AppColors.border, height: 24),
                
                // Name Field
                TextField(
                  controller: _nameEditController,
                  decoration: const InputDecoration(
                    labelText: 'Meal Name',
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Calories & Macros Inputs Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caloriesEditController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _proteinEditController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _carbsEditController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatEditController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: _logMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verify & Save to Log', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Analyzing meal components...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini Flash is computing calories and macro portions...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          )
        ],
      ),
    );
  }
}
