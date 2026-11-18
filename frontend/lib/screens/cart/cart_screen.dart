import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/cart_provider.dart';
import '../../widgets/common.dart';
import '../checkout/checkout_screen.dart';
import '../../core/localization.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().load(silent: true);
    });
  }

  Future<void> _update(CartItem item, int quantity) async {
    final cart = context.read<CartProvider>();
    try {
      if (quantity <= 0) {
        await cart.removeItem(item.id);
      } else {
        await cart.updateQuantity(item.id, quantity);
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
      await cart.load(silent: true);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Clear your cart?'),
        content: const AppText('All items and the selected shopping mode will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep items'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Clear cart', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<CartProvider>().clear();
      if (mounted) showMessage(context, 'Cart cleared.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final cart = provider.cart;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Your cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: provider.mutating ? null : _clear,
              child: const AppText('Clear'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 900,
          child: provider.loading && cart.isEmpty
              ? const LoadingView(message: 'Loading your cart…')
              : cart.isEmpty
                  ? EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your basket is empty',
                      message:
                          'Add products from a nearby shop to start a basket. Product Choice picks the shop for you; Shop Choice keeps the shop you select.',
                      actionLabel: 'Continue shopping',
                      onAction: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                            children: [
                              if (cart.isShopChoice && cart.selectedShop != null)
                                _selectedShopBanner(cart.selectedShop!)
                              else if (cart.isProductChoice)
                                _productChoiceBanner(),
                              if (cart.hasAvailabilityIssues) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppColors.red.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AppColors.red.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: AppColors.red, size: 19),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: AppText(
                                          'Some items no longer have enough stock. Adjust quantities before checkout.',
                                          style: TextStyle(fontSize: 11.5, color: AppColors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              ...cart.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _cartItem(item, provider.mutating),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const AppText('Add more items'),
                              ),
                              const SizedBox(height: 20),
                              _billCard(cart),
                            ],
                          ),
                        ),
                        _checkoutBar(cart, provider.mutating),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _selectedShopBanner(Shop shop) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFFFF9EC),
      borderColor: const Color(0xFFF3E3BC),
      child: Row(
        children: [
          AppImage(url: shop.imageUrl, width: 48, height: 48, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  shop.name,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                AppText(
                  'Shop Choice · ${shop.estimatedDeliveryMinutes} min'
                  '${shop.distanceKm == null ? '' : ' · ${shop.distanceKm!.toStringAsFixed(1)} km'}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const StatusPill(status: 'SHOP CHOICE'),
        ],
      ),
    );
  }

  Widget _productChoiceBanner() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.paleMint,
      borderColor: AppColors.mint,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.green, size: 21),
          SizedBox(width: 9),
          Expanded(
            child: AppText(
              'Product Choice — prices below are the best nearby prices. At checkout, one eligible shop is selected for the complete cart and the final bill is revalidated.',
              style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.darkGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartItem(CartItem item, bool busy) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(url: item.imageUrl, width: 72, height: 72, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            '${item.unit} · ${rupee(item.unitPrice)} each',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : () => _update(item, 0),
                      icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.muted),
                    ),
                  ],
                ),
                if (!item.available) ...[
                  const SizedBox(height: 3),
                  AppText(
                    'Only ${item.availableQuantity} available',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    QuantitySelector(
                      quantity: item.quantity,
                      busy: busy,
                      onIncrement: () => _update(item, item.quantity + 1),
                      onDecrement: () => _update(item, item.quantity - 1),
                    ),
                    const Spacer(),
                    AppText(
                      rupee(item.lineTotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billCard(Cart cart) {
    final remaining = 199 - cart.subtotal;
    return AppCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Bill details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InfoRow(label: 'Item subtotal', value: rupee(cart.subtotal)),
          InfoRow(
            label: 'Delivery charge',
            value: cart.estimatedDeliveryCharge == 0
                ? 'FREE'
                : rupee(cart.estimatedDeliveryCharge),
            valueColor: cart.estimatedDeliveryCharge == 0 ? AppColors.green : null,
          ),
          const Divider(height: 20),
          InfoRow(
            label: 'Estimated total',
            value: rupee(cart.estimatedTotal),
            bold: true,
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (cart.subtotal / 199).clamp(0, 1).toDouble(),
                minHeight: 5,
                backgroundColor: AppColors.border,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              'Add ${rupee(remaining)} more for free delivery',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            const AppText(
              'You unlocked free delivery.',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 8),
          const AppText(
            'Final prices and delivery are confirmed by the server at checkout.',
            style: TextStyle(fontSize: 9.5, color: AppColors.soft),
          ),
        ],
      ),
    );
  }

  Widget _checkoutBar(Cart cart, bool busy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  rupee(cart.estimatedTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                AppText(
                  '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} · incl. delivery',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 185,
            child: ElevatedButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                      ),
              child: const AppText('Proceed to checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
