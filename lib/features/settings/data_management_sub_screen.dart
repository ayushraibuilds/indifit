import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'widgets/data_management_section.dart';

class DataManagementSubScreen extends StatelessWidget {
  const DataManagementSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Auto-Backup'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: DataManagementSection(),
      ),
    );
  }
}
