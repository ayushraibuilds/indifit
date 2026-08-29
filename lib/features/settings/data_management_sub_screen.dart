import 'package:flutter/material.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';
import 'widgets/data_management_section.dart';

class DataManagementSubScreen extends StatelessWidget {
  const DataManagementSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage your data')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            B05Layout.space12,
            B05Layout.space16,
            B05Layout.space32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: const DataManagementSection(),
            ),
          ),
        ),
      ),
    );
  }
}
