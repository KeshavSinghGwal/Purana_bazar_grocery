import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final ApiClient _api = ApiClient.instance;
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  static const _filters = ['All', 'Active', 'Delivered', 'Cancelled'];

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
      final data = await _api.get('/orders') as List<dynamic>;
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
      case 'Active':
        return _orders
            .where((order) =>
                !order.isDelivered && !order.isCancelled && order.orderStatus != 'PAYMENT_FAILED')
            .toList();
      case 'Delivered':
        return _orders.where((order) => order.isDelivered).toList();
      case 'Cancelled':
        return _orders
            .where((order) => order.isCancelled || order.orderStatus == 'PAYMENT_FAILED')
            .toList();
      default:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 820,
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
                      ? const LoadingView(message: 'Loading your orders…')
                      : _error != null
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: 480,
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
                                            ? 'Your first local grocery order is just a few taps away.'
                                            : 'Orders in this state will appear here.',
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final order = filtered[index];
                                    return _orderCard(order);
                                  },
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
    return AppCard(
      padding: const EdgeInsets.all(15),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id)),
        );
        if (mounted) _load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              StatusPill(status: order.orderStatus),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppImage(url: order.shop.imageUrl, width: 48, height: 48, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderItemSummary(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      compactDate(order.createdAt),
                      style: const TextStyle(fontSize: 9.5, color: AppColors.soft),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupee(order.totalAmount),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              StatusPill(
                status: order.shoppingMode == 'PRODUCT_CHOICE' ? 'PRODUCT CHOICE' : 'SHOP CHOICE',
              ),
              const Spacer(),
              const Text(
                'View details',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.green),
            ],
          ),
        ],
      ),
    );
  }
}
