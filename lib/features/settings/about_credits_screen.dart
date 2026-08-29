import 'package:flutter/material.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';

class AboutCreditsScreen extends StatelessWidget {
  const AboutCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & credits')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'IndiFit includes selected open-source software and third-party fitness resources.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space20),
                const _Credit(
                  title: 'MuscleMap',
                  detail:
                      'MuscleMap copyright (c) 2026 Melih Colpan; MIT License. Used for body and muscle map geometry.',
                ),
                const SizedBox(height: B05Layout.space12),
                const _Credit(
                  title: 'RepDB',
                  detail:
                      'Exercise data by RepDB (repdb.co). Approved exercise illustrations, when available, are used under the RepDB Free Tier License.',
                ),
                const SizedBox(height: B05Layout.space12),
                const _Credit(
                  title: 'Open Food Facts',
                  detail:
                      'Online food search results can be provided by Open Food Facts when you choose to use that feature.',
                ),
                const SizedBox(height: B05Layout.space20),
                B05ActionButton(
                  emphasis: B05ActionEmphasis.secondary,
                  icon: Icons.description_outlined,
                  label: 'Open-source licenses',
                  hint: 'Review licenses for software included with IndiFit.',
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'IndiFit',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(detail, style: B05Typography.body(context)),
        ],
      ),
    );
  }
}
