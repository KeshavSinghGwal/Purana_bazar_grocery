import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../state/delivery_provider.dart';
import '../../widgets/common.dart';
import 'delivery_widgets.dart';
import '../../core/localization.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  String _filter = 'Active';

  static const _filters = ['Active', 'Completed', 'All'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      if (!provider.hasData) provider.load();
    });
  }

  List<Order> _filtered(List<Order> orders) {
    switch (_filter) {
      case 'Active':
        return orders
            .where((order) =>
                order.orderStatus == 'READY_FOR_PICKUP' ||
                order.orderStatus == 'OUT_FOR_DELIVERY')
            .toList();
      case 'Completed':
        return orders.where((order) => order.orderStatus == 'DELIVERED').toList();
      default:
        return orders;
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final auth = context.watch<AuthProvider>();
    final filtered = _filtered(provider.orders);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('My deliveries'),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: provider.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: context.tr('Sign out'),
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
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
                      label: AppText(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    );
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.load(silent: true),
                  child: provider.loading && !provider.hasData
                      ? const LoadingView(message: 'Loading your deliveries…')
                      : provider.error != null && !provider.hasData
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: 440,
                                  child: ErrorRetry(
                                    message: provider.error!,
                                    onRetry: provider.load,
                                  ),
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: 440,
                                      child: EmptyState(
                                        icon: Icons.delivery_dining_rounded,
                                        title: _filter == 'Active'
                                            ? 'No active deliveries'
                                            : 'Nothing here yet',
                                        message: _filter == 'Active'
                                            ? 'Accept a pickup from the Available tab and it will appear here.'
                                            : 'Completed deliveries will be listed here once you finish your first trip.',
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final order = filtered[index];
                                    final canAdvance = order.orderStatus == 'READY_FOR_PICKUP' ||
                                        order.orderStatus == 'OUT_FOR_DELIVERY';
                                    return DeliveryOrderCard(
                                      order: order,
                                      busy: provider.busyOrderId == order.id,
                                      onAdvance:
                                          canAdvance ? () => _advance(provider, order) : null,
                                    );
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
}
