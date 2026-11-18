import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../state/delivery_provider.dart';
import '../../widgets/common.dart';
import 'delivery_widgets.dart';
import '../../core/localization.dart';

class DeliveryAvailableScreen extends StatefulWidget {
  const DeliveryAvailableScreen({super.key});

  @override
  State<DeliveryAvailableScreen> createState() => _DeliveryAvailableScreenState();
}

class _DeliveryAvailableScreenState extends State<DeliveryAvailableScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      if (!provider.hasData) provider.load();
    });
  }

  Future<void> _accept(DeliveryProvider provider, Order order) async {
    final error = await provider.accept(order);
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error, error: true);
    } else {
      showMessage(context, '${order.orderNumber} is now yours. Pick it up from ${order.shop.name}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Available pickups'),
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
          child: RefreshIndicator(
            onRefresh: () => provider.load(silent: true),
            child: provider.loading && !provider.hasData
                ? const LoadingView(message: 'Finding ready orders…')
                : provider.error != null && !provider.hasData
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
                    : provider.available.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(
                                height: 470,
                                child: EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'No pickups waiting',
                                  message:
                                      'Orders appear here as soon as a shop marks them ready for pickup. Pull down to refresh.',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            itemCount: provider.available.length + 1,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        size: 17,
                                        color: AppColors.green,
                                      ),
                                      const SizedBox(width: 5),
                                      AppText(
                                        '${provider.available.length} ready ${provider.available.length == 1 ? 'order' : 'orders'} nearby',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final order = provider.available[index - 1];
                              return DeliveryOrderCard(
                                order: order,
                                busy: provider.busyOrderId == order.id,
                                onAccept: () => _accept(provider, order),
                              );
                            },
                          ),
          ),
        ),
      ),
    );
  }
}
