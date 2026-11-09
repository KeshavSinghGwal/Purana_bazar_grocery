import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final ApiClient _api = ApiClient.instance;
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  int? _busyId;

  static const _filters = [
    'All',
    'Pending',
    'In progress',
    'Delivered',
    'Cancelled',
  ];

  static const _activeStatuses = [
    'PENDING',
    'ACCEPTED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'OUT_FOR_DELIVERY',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _orders.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/admin/orders') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _orders = data
            .whereType<Map>()
            .map((item) => Order.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Order> get _filtered {
    switch (_filter) {
      case 'Pending':
        return _orders.where((order) => order.orderStatus == 'PENDING').toList();
      case 'In progress':
        return _orders
            .where(
              (order) => _activeStatuses.contains(order.orderStatus) &&
                  order.orderStatus != 'PENDING',
            )
            .toList();
      case 'Delivered':
        return _orders.where((order) => order.orderStatus == 'DELIVERED').toList();
      case 'Cancelled':
        return _orders
            .where(
              (order) =>
                  order.orderStatus == 'CANCELLED' ||
                  order.orderStatus == 'REJECTED',
            )
            .toList();
      default:
        return _orders;
    }
  }

  Future<void> _cancel(Order order) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${order.orderNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The customer will see this order as cancelled and reserved stock will be returned to the shop.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this order being cancelled?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted) return;
    if (reason.isEmpty) {
      showMessage(context, 'Please provide a cancellation reason.', error: true);
      return;
    }
    setState(() => _busyId = order.id);
    try {
      await _api.put(
        '/admin/orders/${order.id}/cancel',
        body: {'reason': reason},
      );
      if (!mounted) return;
      showMessage(context, 'Order cancelled and stock restored.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 1000,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const LoadingView(message: 'Loading orders…')
                : _error != null
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 450,
                            child: ErrorRetry(message: _error!, onRetry: _load),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters
                                  .map(
                                    (filter) => Padding(
                                      padding: const EdgeInsets.only(right: 7),
                                      child: ChoiceChip(
                                        label: Text(filter),
                                        selected: _filter == filter,
                                        onSelected: (_) =>
                                            setState(() => _filter = filter),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 60),
                              child: EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No orders here',
                                message:
                                    'Orders matching this status will appear as customers check out.',
                              ),
                            )
                          else
                            ...filtered.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _orderCard(order),
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Order order) {
    final busy = _busyId == order.id;
    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: () => _showDetails(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusBackground(order.orderStatus),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: statusColor(order.orderStatus),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.customerName} · ${order.shop.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(status: order.orderStatus),
                  const SizedBox(height: 3),
                  Text(
                    rupee(order.totalAmount),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                compactDate(order.createdAt),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_activeStatuses.contains(order.orderStatus))
                TextButton(
                  onPressed: () => _cancel(order),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 11, color: AppColors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetails(Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusPill(status: order.orderStatus),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${order.customerName}${order.customerPhone == null ? '' : ' · ${order.customerPhone}'}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shop.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
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
              const Divider(height: 22),
              InfoRow(label: 'Subtotal', value: rupee(order.subtotal)),
              InfoRow(
                label: 'Delivery',
                value: order.deliveryCharge == 0 ? 'FREE' : rupee(order.deliveryCharge),
              ),
              InfoRow(label: 'Total', value: rupee(order.totalAmount), bold: true),
              const SizedBox(height: 6),
              InfoRow(label: 'Payment', value: statusLabel(order.paymentStatus)),
              InfoRow(label: 'Method', value: statusLabel(order.paymentMethod)),
              InfoRow(label: 'Placed', value: fullDate(order.createdAt)),
              if (order.customerNote != null)
                InfoRow(label: 'Customer note', value: order.customerNote!),
              if (order.cancellationReason != null)
                InfoRow(label: 'Cancellation', value: order.cancellationReason!),
              if (_activeStatuses.contains(order.orderStatus)) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancel(order);
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const Text('Cancel this order'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
