import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import 'tip_jar_controller.dart';
import 'tip_jar_products.dart';
import 'tip_store.dart';

/// Route for the supporter tip jar (Settings → Support IndiFit).
const tipJarRoutePath = '/settings/support';

/// Route for the thank-you screen shown after a tip goes through.
const tipThanksRoutePath = '/settings/support/thanks';

/// Optional supporter tips. Tips unlock nothing.
class TipJarScreen extends ConsumerWidget {
  const TipJarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tipJarControllerProvider);
    final controller = ref.read(tipJarControllerProvider.notifier);

    ref.listen<TipJarState>(tipJarControllerProvider, (previous, next) {
      if (next.purchase == TipPurchasePhase.thanked &&
          previous?.purchase != TipPurchasePhase.thanked) {
        context.pushReplacement(tipThanksRoutePath);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Support IndiFit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space32,
        ),
        children: [
          Text('Support IndiFit', style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space8),
          Text(
            'IndiFit has no ads and no account. If it helps you, you can leave '
            'a tip. Tips are optional and don’t unlock anything; the app stays '
            'the same for everyone.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space20),
          ..._body(context, state, controller),
          const SizedBox(height: B05Layout.space24),
          Text(
            'Payments are handled by the App Store or Google Play. IndiFit '
            'never sees your card details.',
            style: B05Typography.caption(
              context,
            ).copyWith(color: context.b05Colors.textSecondary),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    TipJarState state,
    TipJarController controller,
  ) {
    switch (state.load) {
      case TipJarLoad.loading:
        return const [
          ConsumerStatusRow(label: 'Checking the store', loading: true),
        ];
      case TipJarLoad.offline:
        return const [
          ConsumerStatusRow(
            label: 'Offline Mode is on',
            detail:
                'Tips go through the App Store or Google Play, so IndiFit '
                'doesn’t contact them while Offline Mode is on. You can turn '
                'it off in Settings → Manage your data.',
          ),
        ];
      case TipJarLoad.storeUnavailable:
        return [
          ConsumerStatusRow(
            label: 'The store isn’t available',
            detail:
                'Tips go through the App Store or Google Play, which can’t be '
                'reached on this device right now.',
            onRetry: controller.load,
          ),
        ];
      case TipJarLoad.productsMissing:
        return const [
          ConsumerStatusRow(
            label: 'Tips aren’t set up yet',
            detail:
                'Thanks for wanting to help. Tips aren’t available in your '
                'store yet, so please check back later.',
          ),
        ];
      case TipJarLoad.failed:
        return [
          ConsumerStatusRow(
            label: 'Couldn’t load tips',
            detail: 'Something went wrong reaching the store.',
            error: true,
            onRetry: controller.load,
          ),
        ];
      case TipJarLoad.ready:
        return [
          for (final product in state.products) ...[
            _TipOption(
              product: product,
              enabled: !state.isBusy,
              onPressed: () {
                controller.dismissNotice();
                controller.buy(product.id);
              },
            ),
            const SizedBox(height: B05Layout.space12),
          ],
          ?_purchaseNotice(state.purchase, controller),
        ];
    }
  }

  Widget? _purchaseNotice(
    TipPurchasePhase phase,
    TipJarController controller,
  ) => switch (phase) {
    TipPurchasePhase.inProgress => const ConsumerStatusRow(
      label: 'Opening the store',
      loading: true,
    ),
    TipPurchasePhase.pending => const ConsumerStatusRow(
      label: 'Waiting for your payment',
      detail:
          'The store is still processing this payment. It can finish later, '
          'so you don’t need to keep this screen open.',
      loading: true,
    ),
    TipPurchasePhase.cancelled => const ConsumerStatusRow(
      label: 'No payment was made',
      detail: 'That’s completely fine.',
    ),
    TipPurchasePhase.failed => const ConsumerStatusRow(
      label: 'The payment didn’t go through',
      detail: 'The store couldn’t finish this payment. You can try again.',
      error: true,
    ),
    TipPurchasePhase.idle || TipPurchasePhase.thanked => null,
  };
}

class _TipOption extends StatelessWidget {
  const _TipOption({
    required this.product,
    required this.enabled,
    required this.onPressed,
  });

  final TipProduct product;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = TipJarProducts.labels[product.id] ?? product.title;
    return B05Surface(
      child: Row(
        children: [
          Icon(Icons.local_cafe_outlined, color: context.b05Colors.action),
          const SizedBox(width: B05Layout.space12),
          Expanded(child: Text(label, style: B05Typography.label(context))),
          const SizedBox(width: B05Layout.space12),
          B05ActionButton(
            label: product.price,
            hint: 'Leave a ${product.price} tip',
            onPressed: enabled ? onPressed : null,
          ),
        ],
      ),
    );
  }
}

/// Shown after a tip goes through. It confirms that nothing changes.
class TipThanksScreen extends StatelessWidget {
  const TipThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thank you')),
      body: ListView(
        padding: const EdgeInsets.all(B05Layout.space16),
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 48,
            color: context.b05Colors.action,
          ),
          const SizedBox(height: B05Layout.space16),
          Text(
            'Thank you for your support',
            style: B05Typography.pageTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Your tip helps keep IndiFit going, with no ads and no account. '
            'Everything in the app stays exactly the same.',
            style: B05Typography.body(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: B05Layout.space24),
          B05ActionButton(
            label: 'Done',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
        ],
      ),
    );
  }
}
