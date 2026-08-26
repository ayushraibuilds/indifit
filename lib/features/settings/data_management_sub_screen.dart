import 'package:flutter/material.dart';

import 'widgets/data_management_section.dart';

class DataManagementSubScreen extends StatelessWidget {
  const DataManagementSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & privacy')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [DataManagementSection()],
            ),
          ),
        ),
      ),
    );
  }
}
