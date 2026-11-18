import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ApiClient _api = ApiClient.instance;
  Order? _order;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  Timer? _refreshTimer;

  static const _timeline = [
    'PENDING',
    'ACCEPTED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final order = _order;
      if (!mounted || order == null || _isTerminal(order.orderStatus)) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isTerminal(String status) =>
      status == 'DELIVERED' ||
      status == 'CANCELLED' ||
      status == 'REJECTED' ||
      status == 'PAYMENT_FAILED';

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _order == null;
        _error = null;
      });
    }
    try {
      final data = await _api.get('/orders/${widget.orderId}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _order = Order.fromJson(data));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!silent) setState(() => _error = error.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _payNow() async {
    final order = _order;
    if (order == null || _paying) return;
    setState(() => _paying = true);
    try {
      final paid = await PaymentService.instance.payForOrder(context, order);
      if (!mounted) return;
      setState(() => _order = paid);
      showMessage(context, 'Payment successful. Your order is confirmed.');
    } on PaymentCancelledException {
      if (mounted) {
        showMessage(context, 'Payment cancelled. You can retry any time.',
            error: true);
      }
    } on PaymentException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Cancel this order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'The shop will be notified and any reserved stock will be restored.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr(context, 'Reason (optional)'),
                hintText: tr(context, 'e.g. Ordered by mistake'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Cancel order', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    try {
      final data = await _api.put('/orders/${widget.orderId}/cancel', body: {
        'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
      }) as Map<String, dynamic>;
      reason.dispose();
      if (!mounted) return;
      setState(() => _order = Order.fromJson(data));
      showMessage(context, 'Order cancelled and stock restored.');
    } on ApiException catch (error) {
      reason.dispose();
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _reviewShop() async {
    if (_order == null) return;
    int rating = 5;
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('Rate ${_order!.shop.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFF5A623),
                      size: 30,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: InputDecoration(hintText: tr(context, 'How was your experience?')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Submit review'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      comment.dispose();
      return;
    }
    try {
      await _api.post('/shops/${_order!.shop.id}/reviews', body: {
        'rating': rating,
        'comment': comment.text.trim().isEmpty ? null : comment.text.trim(),
      });
      comment.dispose();
      if (mounted) showMessage(context, 'Thanks for reviewing the shop.');
    } on ApiException catch (error) {
      comment.dispose();
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Order details'),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 820,
          child: _loading
              ? const LoadingView(message: 'Loading your order…')
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _load)
                  : order == null
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Order not found',
                          message: 'This order could not be loaded.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            children: [
                              _headerCard(order),
                              const SizedBox(height: 12),
                              if (order.isAwaitingPayment)
                                _paymentPendingCard(order)
                              else if (order.isCancelled)
                                _terminalStatus(order)
                              else
                                _timelineCard(order),
                              const SizedBox(height: 12),
                              _deliveryCard(order),
                              const SizedBox(height: 12),
                              _itemsCard(order),
                              const SizedBox(height: 12),
                              _paymentCard(order),
                              if (order.customerNote != null) ...[
                                const SizedBox(height: 12),
                                AppCard(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppText('Delivery note',
                                          style: Theme.of(context).textTheme.titleSmall),
                                      const SizedBox(height: 5),
                                      AppText(
                                        order.customerNote!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              if (order.isDelivered)
                                OutlinedButton.icon(
                                  onPressed: _reviewShop,
                                  icon: const Icon(Icons.star_outline_rounded),
                                  label: const AppText('Rate this shop'),
                                ),
                              if (order.canRetryPayment) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _paying ? null : _payNow,
                                    icon: _paying
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.lock_outline_rounded, size: 18),
                                    label: AppText(_paying
                                        ? 'Opening secure checkout…'
                                        : 'Pay ${rupee(order.totalAmount)} now'),
                                  ),
                                ),
                              ],
                              if (order.canCancel) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _cancel,
                                  child: const AppText(
                                    'Cancel order',
                                    style: TextStyle(color: AppColors.red),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _headerCard(Order order) {
    return AppCard(
      padding: const EdgeInsets.all(17),
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'ORDER NUMBER',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(status: order.orderStatus),
            ],
          ),
          const SizedBox(height: 7),
          AppText(
            'Placed ${fullDate(order.createdAt)}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          const Divider(height: 24),
          Row(
            children: [
              AppImage(url: order.shop.imageUrl, width: 46, height: 46, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      order.shop.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      '${order.shoppingMode == 'PRODUCT_CHOICE' ? 'Product Choice' : 'Shop Choice'} · ${order.paymentMethod == 'COD' ? 'Cash on Delivery' : 'Online payment'}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              AppText(
                rupee(order.totalAmount),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentPendingCard(Order order) {
    final failed = order.paymentStatus == 'FAILED';
    return AppCard(
      padding: const EdgeInsets.all(17),
      color: const Color(0xFFFFF8E1),
      borderColor: const Color(0xFFFFE082),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
                color: const Color(0xFFB26A00),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  failed ? 'Payment failed' : 'Payment pending',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8A5200),
                  ),
                ),
              ),
              AppText(
                rupee(order.totalAmount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8A5200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          AppText(
            'Order ${order.orderNumber} is reserved. Complete the payment to confirm it with '
            '${order.shop.name}. Unpaid orders are released automatically after 2 hours.',
            style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF8A5200)),
          ),
          if (order.canRetryPayment) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _paying ? null : _payNow,
                icon: _paying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: AppText(_paying
                    ? 'Opening secure checkout…'
                    : failed
                        ? 'Retry payment · ${rupee(order.totalAmount)}'
                        : 'Pay ${rupee(order.totalAmount)} now'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelineCard(Order order) {
    final currentIndex = _timeline.indexOf(order.orderStatus);
    return AppCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Order progress', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          ...List.generate(_timeline.length, (index) {
            final status = _timeline[index];
            final complete = currentIndex >= index && currentIndex >= 0;
            final current = currentIndex == index;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: complete ? AppColors.green : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: complete ? AppColors.green : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: complete
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      if (index < _timeline.length - 1)
                        Container(
                          width: 2,
                          height: 35,
                          color: currentIndex > index
                              ? AppColors.green
                              : AppColors.border,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        _timelineLabel(status),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                          color: complete ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                      if (current)
                        const AppText(
                          'Current status',
                          style: TextStyle(fontSize: 9.5, color: AppColors.green),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _terminalStatus(Order order) {
    final cancelled = order.orderStatus == 'CANCELLED';
    return AppCard(
      padding: const EdgeInsets.all(17),
      color: AppColors.red.withValues(alpha: 0.05),
      borderColor: AppColors.red.withValues(alpha: 0.16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cancelled ? Icons.cancel_outlined : Icons.remove_shopping_cart_outlined,
            color: AppColors.red,
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  cancelled ? 'Order cancelled' : 'Order rejected',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.red,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  order.cancellationReason ??
                      'This order is no longer active. Any reserved stock has been restored.',
                  style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryCard(Order order) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Delivery details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  order.deliveryAddress,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.muted, size: 18),
              const SizedBox(width: 6),
              AppText(
                order.customerName,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              if (order.customerPhone != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.phone_outlined, color: AppColors.muted, size: 16),
                const SizedBox(width: 4),
                AppText(
                  order.customerPhone!,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(Order order) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  AppImage(url: item.imageUrl, width: 42, height: 42, radius: 8),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${item.unit} × ${item.quantity}',
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  AppText(
                    rupee(item.totalPrice),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          InfoRow(label: 'Subtotal', value: rupee(order.subtotal)),
          InfoRow(
            label: 'Delivery',
            value: order.deliveryCharge == 0 ? 'FREE' : rupee(order.deliveryCharge),
          ),
          InfoRow(label: 'Total', value: rupee(order.totalAmount), bold: true),
        ],
      ),
    );
  }

  Widget _paymentCard(Order order) {
    final online = order.paymentMethod != 'COD';
    final reference = order.paymentReference;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.credit_card_rounded : Icons.payments_outlined,
                color: AppColors.green,
                size: 23,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      online ? 'Online payment' : 'Cash on Delivery',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      online
                          ? 'Secured by ${order.paymentGateway == 'RAZORPAY' ? 'Razorpay' : (order.paymentGateway ?? 'the payment gateway')}'
                          : 'Collected by the delivery partner',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              StatusPill(status: order.paymentStatus),
            ],
          ),
          if (reference != null && reference.isNotEmpty) ...[
            const Divider(height: 22),
            InfoRow(
              label: online ? 'Payment ID' : 'Reference',
              value: reference,
            ),
          ],
          if (online && order.paymentStatus == 'REFUNDED') ...[
            const SizedBox(height: 6),
            const AppText(
              'Your refund has been initiated and usually reaches your account within 5–7 working days.',
              style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _timelineLabel(String status) {
    switch (status) {
      case 'PAYMENT_PENDING':
        return 'Awaiting payment';
      case 'PAYMENT_FAILED':
        return 'Payment failed';
      case 'PENDING':
        return 'Order placed';
      case 'ACCEPTED':
        return 'Accepted by shop';
      case 'PREPARING':
        return 'Being packed';
      case 'READY_FOR_PICKUP':
        return 'Ready for pickup';
      case 'OUT_FOR_DELIVERY':
        return 'Out for delivery';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return statusLabel(status);
    }
  }
}
