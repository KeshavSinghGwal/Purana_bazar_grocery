import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../orders/order_details_screen.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageWidth(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.7, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: AppColors.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 47),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Order confirmed!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 7),
              Text(
                'Your order is now with ${order.shop.name}. You will pay ${rupee(order.totalAmount)} on delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(18),
                shadow: true,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ORDER NUMBER',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        StatusPill(status: order.orderStatus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        AppImage(
                          url: order.shop.imageUrl,
                          width: 46,
                          height: 46,
                          radius: 10,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.shop.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.shop.estimatedDeliveryMinutes} min · ${order.shoppingMode == 'PRODUCT_CHOICE' ? 'Product Choice' : 'Shop Choice'}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          rupee(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.deliveryAddress,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order items', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 9),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} × ${item.quantity}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              rupee(item.totalPrice),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    InfoRow(label: 'Subtotal', value: rupee(order.subtotal)),
                    InfoRow(
                      label: 'Delivery',
                      value:
                          order.deliveryCharge == 0 ? 'FREE' : rupee(order.deliveryCharge),
                    ),
                    InfoRow(label: 'Total', value: rupee(order.totalAmount), bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(orderId: order.id),
                  ),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Track this order'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
