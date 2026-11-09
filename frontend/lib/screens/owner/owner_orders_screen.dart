import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  final ApiClient _api = ApiClient.instance;
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  int? _updatingId;

  static const _filters = ['All', 'Pending', 'In progress', 'Delivered', 'Cancelled'];

  static const _transitions = <String, List<String>>{
    'PENDING': ['ACCEPTED', 'REJECTED', 'CANCELLED'],
    'ACCEPTED': ['PREPARING', 'CANCELLED'],
    'PREPARING': ['READY_FOR_PICKUP', 'CANCELLED'],
    'READY_FOR_PICKUP': ['OUT_FOR_DELIVERY'],
    'OUT_FOR_DELIVERY': ['DELIVERED'],
  };

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
      final data = await _api.get('/shop-owner/orders') as List<dynamic>;
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
            .where((order) => [
                  'ACCEPTED',
                  'PREPARING',
                  'READY_FOR_PICKUP',
                  'OUT_FOR_DELIVERY',
                ].contains(order.orderStatus))
            .toList();
      case 'Delivered':
        return _orders.where((order) => order.orderStatus == 'DELIVERED').toList();
      case 'Cancelled':
        return _orders
            .where((order) =>
                order.orderStatus == 'CANCELLED' || order.orderStatus == 'REJECTED')
            .toList();
      default:
        return _orders;
    }
  }

  Future<void> _manage(Order order) async {
    final targets = _transitions[order.orderStatus] ?? const <String>[];
    if (targets.isEmpty) {
      showMessage(context, 'No further status changes are available for this order.');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Text('Update ${order.orderNumber}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Choose the next status. Stock is restored automatically for rejections or cancellations.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            ...targets.map(
              (target) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: Icon(
                    target == 'REJECTED' || target == 'CANCELLED'
                        ? Icons.cancel_outlined
                        : Icons.arrow_forward_rounded,
                    color: target == 'REJECTED' || target == 'CANCELLED'
                        ? AppColors.red
                        : AppColors.green,
                  ),
                  title: Text(
                    statusLabel(target),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, target),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    String? reason;
    if (selected == 'REJECTED' || selected == 'CANCELLED') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(selected == 'REJECTED' ? 'Reject order?' : 'Cancel order?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reserved stock will be restored for the customer.',
                style: TextStyle(fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. Item unavailable',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        controller.dispose();
        return;
      }
      reason = controller.text.trim().isEmpty ? null : controller.text.trim();
      controller.dispose();
    }

    setState(() => _updatingId = order.id);
    try {
      final data = await _api.put('/shop-owner/orders/${order.id}/status', body: {
        'status': selected,
        'reason': ?reason,
      }) as Map<String, dynamic>;
      final updated = Order.fromJson(data);
      if (!mounted) return;
      setState(() {
        _orders = _orders.map((item) => item.id == updated.id ? updated : item).toList();
      });
      showMessage(context, 'Order marked ${statusLabel(selected)}.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop orders'),
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
          maxWidth: 900,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    return ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    );
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading
                      ? const LoadingView(message: 'Loading shop orders…')
                      : _error != null
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: 470,
                                  child: ErrorRetry(message: _error!, onRetry: _load),
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height: 470,
                                      child: EmptyState(
                                        icon: Icons.receipt_long_outlined,
                                        title: _orders.isEmpty
                                            ? 'No orders yet'
                                            : 'No ${_filter.toLowerCase()} orders',
                                        message: _orders.isEmpty
                                            ? 'When customers place orders, they will appear here for acceptance and fulfilment.'
                                            : 'Orders in this state will appear here.',
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _orderCard(filtered[index]),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Order order) {
    final updating = _updatingId == order.id;
    final canUpdate = _transitions.containsKey(order.orderStatus);
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                      compactDate(order.createdAt),
                      style: const TextStyle(fontSize: 9.5, color: AppColors.soft),
                    ),
                  ],
                ),
              ),
              StatusPill(status: order.orderStatus),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.mint,
                child: Text(
                  initials(order.customerName),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                rupee(order.totalAmount),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.items.map((item) => '${item.productName} × ${item.quantity}').join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, height: 1.45, color: AppColors.muted),
          ),
          if (order.customerNote != null) ...[
            const SizedBox(height: 5),
            Text(
              'Note: ${order.customerNote}',
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              StatusPill(
                status: order.shoppingMode == 'PRODUCT_CHOICE'
                    ? 'PRODUCT CHOICE'
                    : 'SHOP CHOICE',
              ),
              const Spacer(),
              if (canUpdate)
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: updating ? null : () => _manage(order),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(116, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: updating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update status'),
                  ),
                )
              else
                Text(
                  order.orderStatus == 'DELIVERED'
                      ? 'Completed'
                      : statusLabel(order.orderStatus),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
