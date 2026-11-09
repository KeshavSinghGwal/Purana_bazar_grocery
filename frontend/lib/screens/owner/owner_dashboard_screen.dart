import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'owner_inventory_screen.dart';
import 'owner_orders_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ApiClient _api = ApiClient.instance;
  OwnerDashboard? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await _api.get('/shop-owner/dashboard') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _data = OwnerDashboard.fromJson(data));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner dashboard'),
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
          child: _loading
              ? const LoadingView(message: 'Loading your shop…')
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _load)
                  : data == null
                      ? const EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'No shop linked',
                          message: 'No shop is linked to this owner account.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            children: [
                              _shopHero(data),
                              if (data.approvalStatus != 'APPROVED') ...[
                                const SizedBox(height: 12),
                                _approvalBanner(data),
                              ],
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                                  final width =
                                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                                  final cards = [
                                    _stat(
                                      width,
                                      'Total sales',
                                      rupee(data.totalSales),
                                      Icons.currency_rupee_rounded,
                                      AppColors.green,
                                    ),
                                    _stat(
                                      width,
                                      'Pending orders',
                                      '${data.pendingOrders}',
                                      Icons.pending_actions_outlined,
                                      AppColors.orange,
                                    ),
                                    _stat(
                                      width,
                                      'Live listings',
                                      '${data.totalProducts}',
                                      Icons.inventory_2_outlined,
                                      const Color(0xFF1565C0),
                                    ),
                                    _stat(
                                      width,
                                      'Delivered',
                                      '${data.deliveredOrders}',
                                      Icons.check_circle_outline_rounded,
                                      const Color(0xFF6A1B9A),
                                    ),
                                  ];
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: cards,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const OwnerInventoryScreen(),
                                        ),
                                      ),
                                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                                      label: const Text('Manage inventory'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const OwnerOrdersScreen(),
                                        ),
                                      ),
                                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                      label: const Text('Manage orders'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              SectionHeader(
                                title: 'Recent orders',
                                subtitle: data.recentOrders.isEmpty
                                    ? 'New orders will appear here'
                                    : '${data.totalOrders} orders all time',
                              ),
                              const SizedBox(height: 10),
                              if (data.outOfStockProducts > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppColors.red.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AppColors.red.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: AppColors.red, size: 19),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${data.outOfStockProducts} listing${data.outOfStockProducts == 1 ? '' : 's'} out of stock. Update stock to stay visible.',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (data.recentOrders.isEmpty)
                                AppCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long_outlined,
                                          color: AppColors.muted, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'No orders yet. Once a customer checks out, their order will appear here for acceptance.',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...data.recentOrders.map(
                                  (order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _recentOrder(order),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _shopHero(OwnerDashboard data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR SHOP',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.shopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel(data.operationalStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.address,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroChip(
                data.approvalStatus == 'APPROVED' ? Icons.verified_outlined : Icons.hourglass_top_rounded,
                statusLabel(data.approvalStatus),
              ),
              const SizedBox(width: 8),
              _heroChip(Icons.inventory_2_outlined, '${data.totalProducts} listings'),
              const SizedBox(width: 8),
              _heroChip(Icons.shopping_bag_outlined, '${data.totalOrders} orders'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _approvalBanner(OwnerDashboard data) {
    final rejected = data.approvalStatus == 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: rejected
            ? AppColors.red.withValues(alpha: 0.06)
            : const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rejected
              ? AppColors.red.withValues(alpha: 0.16)
              : const Color(0xFFF3E3BC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
            color: rejected ? AppColors.red : const Color(0xFFB26A00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejected ? 'Shop registration rejected' : 'Waiting for admin approval',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: rejected ? AppColors.red : const Color(0xFF8A5900),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rejected
                      ? 'Your shop is hidden from customers. Contact support or register again with corrected details.'
                      : 'Your shop is hidden from customers until an administrator approves it. You can prepare inventory now.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: rejected ? AppColors.red : const Color(0xFF8A5900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(double width, String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 11),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentOrder(Order order) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: () => _showOrder(order),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: statusBackground(order.orderStatus),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 19,
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.customerName} · ${order.items.length} items',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(status: order.orderStatus),
              const SizedBox(height: 3),
              Text(
                rupee(order.totalAmount),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrder(Order order) {
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
              Text(order.deliveryAddress, style: const TextStyle(fontSize: 12)),
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
              if (order.customerNote != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Customer note: ${order.customerNote}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerOrdersScreen()),
                    );
                  },
                  child: const Text('Manage order status'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
