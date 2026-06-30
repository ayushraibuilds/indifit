import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/colors.dart';
import '../../core/config/app_config.dart';
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          _selectedImage = File(file.path);
          _estimatedMeal = null; // Clear previous estimation
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  Future<void> _submitTextEstimate() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _loading = true;
      _estimatedMeal = null;
    });

    try {
      final dio = Dio();
      final response = await dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-estimate-text',
        data: {'text': _textController.text},
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _estimatedMeal = response.data;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API Error: $e')),
      );
    }
  }

  Future<void> _submitPhotoEstimate() async {
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _estimatedMeal = null;
    });

    try {
      final dio = Dio();
      
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
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API Error: $e')),
      );
    }
  }

  Future<void> _logMeal() async {
    if (_estimatedMeal == null) return;

    final repo = ref.read(foodRepositoryProvider);
    
    final double carbs = (_estimatedMeal!['carbs'] as num).toDouble();
    final double protein = (_estimatedMeal!['protein'] as num).toDouble();
    final double fat = (_estimatedMeal!['fat'] as num).toDouble();

    await repo.logFoodEntry(
      name: _estimatedMeal!['name'] ?? 'AI Estimated Meal',
      calories: (_estimatedMeal!['calories'] as num).toInt(),
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      servingLogged: (_estimatedMeal!['serving_size'] as num).toDouble(),
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
            const Text(
              'Describe your meal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. 2 rotis with paneer bhurji and dal tadka',
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
    final double carbs = (_estimatedMeal!['carbs'] as num).toDouble();
    final double protein = (_estimatedMeal!['protein'] as num).toDouble();
    final double fat = (_estimatedMeal!['fat'] as num).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GEMINI ESTIMATION RESULT',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _estimatedMeal!['name'] ?? 'Estimated Food Item',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated portions: ${_estimatedMeal!['serving_size']} ${_estimatedMeal!['serving_unit']}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const Divider(color: AppColors.border, height: 24),
                
                // Macros Grid Layout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroResult('Calories', '${_estimatedMeal!['calories']} kcal', AppColors.primary),
                    _buildMacroResult('Protein', '${protein.toStringAsFixed(1)}g', AppColors.success),
                    _buildMacroResult('Carbs', '${carbs.toStringAsFixed(1)}g', AppColors.warning),
                    _buildMacroResult('Fat', '${fat.toStringAsFixed(1)}g', AppColors.danger),
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

  Widget _buildMacroResult(String label, String val, Color col) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: col)),
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
