import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../state/delivery_provider.dart';
import '../../widgets/common.dart';
import 'delivery_widgets.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      if (!provider.hasData) provider.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final dashboard = provider.dashboard;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery desk'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 820,
          child: RefreshIndicator(
            onRefresh: () => provider.load(silent: true),
            child: provider.loading && dashboard == null
                ? const LoadingView(message: 'Loading your delivery desk…')
                : provider.error != null && dashboard == null
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 470,
                            child: ErrorRetry(
                              message: provider.error!,
                              onRetry: provider.load,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                        children: [
                          _hero(dashboard),
                          const SizedBox(height: 16),
                          _stats(dashboard),
                          const SizedBox(height: 22),
                          SectionHeader(
                            title: 'Active deliveries',
                            subtitle: dashboard == null || dashboard.activeOrders.isEmpty
                                ? 'Accepted deliveries will appear here.'
                                : '${dashboard.activeDeliveries} in progress right now',
                          ),
                          const SizedBox(height: 11),
                          if (dashboard == null || dashboard.activeOrders.isEmpty)
                            AppCard(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      color: AppColors.mint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delivery_dining_rounded,
                                      color: AppColors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'No active delivery. Accept a pickup from the Available tab to get started.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...dashboard.activeOrders.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: DeliveryOrderCard(
                                  order: order,
                                  busy: provider.busyOrderId == order.id,
                                  onAdvance: () => _advance(provider, order),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Only hand over an order after collecting payment for COD deliveries.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: AppColors.soft),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Future<void> _advance(DeliveryProvider provider, Order order) async {
    final error = await provider.advance(order);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
    } else {
      showMessage(
        context,
        order.orderStatus == 'READY_FOR_PICKUP'
            ? 'Order picked up. Head to the customer.'
            : 'Delivery completed. Payment collected.',
      );
    }
  }

  Widget _hero(DeliveryDashboard? dashboard) {
    final name = dashboard?.partnerName ?? 'Delivery partner';
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final available = dashboard?.availableOrders ?? 0;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'ON DUTY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Hello, $firstName.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  available == 0
                      ? 'No pickups waiting right now. We will keep this desk fresh.'
                      : '$available ${available == 1 ? 'order is' : 'orders are'} waiting for pickup nearby.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(DeliveryDashboard? dashboard) {
    final items = [
      ('Available', '${dashboard?.availableOrders ?? 0}', Icons.storefront_rounded,
          const Color(0xFF1565C0)),
      ('Active', '${dashboard?.activeDeliveries ?? 0}', Icons.delivery_dining_rounded,
          AppColors.orange),
      ('Completed', '${dashboard?.completedDeliveries ?? 0}', Icons.check_circle_rounded,
          AppColors.green),
      ('Fees earned', rupee(dashboard?.totalDeliveryFees ?? 0), Icons.payments_rounded,
          const Color(0xFF6A1B9A)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 40) return const SizedBox.shrink();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return AppCard(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(item.$3, size: 18, color: item.$4),
                      const Spacer(),
                      if (index == 0)
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: item.$4,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    item.$2,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    item.$1,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
