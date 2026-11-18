import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../state/notification_provider.dart';
import '../../widgets/common.dart';
import '../orders/order_details_screen.dart';
import '../../core/localization.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  Future<void> _open(AppNotificationItem item) async {
    final provider = context.read<NotificationProvider>();
    final auth = context.read<AuthProvider>();
    await provider.markRead(item);
    if (!mounted) return;
    if (item.orderId != null && auth.user?.role == 'CUSTOMER') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: item.orderId!),
        ),
      );
      if (mounted) await provider.load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Notifications'),
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const AppText('Mark all read'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 760,
          child: RefreshIndicator(
            onRefresh: () => provider.load(),
            child: provider.loading && provider.items.isEmpty
                ? const LoadingView(message: 'Loading notifications…')
                : provider.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 40),
                          EmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'No notifications yet',
                            message: provider.pushConfigured
                                ? 'Order updates, payment receipts and shop alerts will appear here.'
                                : 'Order updates and payment receipts will appear here.',
                          ),
                          if (provider.pushConfigured) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: provider.enablePush,
                                icon: const Icon(Icons.notifications_active_outlined,
                                    size: 18),
                                label: AppText(provider.pushDenied
                                    ? 'Allow push notifications'
                                    : 'Enable push notifications'),
                              ),
                            ),
                          ],
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        itemCount: provider.items.length +
                            (provider.pushConfigured ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          if (provider.pushConfigured && index == 0) {
                            return _pushCard(provider);
                          }
                          final item = provider.items[
                              provider.pushConfigured ? index - 1 : index];
                          return _notificationCard(item);
                        },
                      ),
          ),
        ),
      ),
    );
  }

  Widget _pushCard(NotificationProvider provider) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      color: AppColors.paleMint,
      borderColor: AppColors.mint,
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              provider.pushDenied
                  ? 'Push notifications are blocked in this browser. Enable them in site settings to get order alerts.'
                  : 'Push notifications keep you updated even when the app is closed.',
              style: const TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.darkGreen),
            ),
          ),
          if (provider.pushDenied)
            TextButton(
              onPressed: provider.enablePush,
              child: const AppText('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _notificationCard(AppNotificationItem item) {
    final icon = switch (item.type) {
      'PAYMENT' => Icons.payments_outlined,
      'DELIVERY' => Icons.delivery_dining_outlined,
      'SHOP' => Icons.storefront_outlined,
      'ACCOUNT' => Icons.person_outline_rounded,
      _ => Icons.receipt_long_outlined,
    };
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.read ? AppColors.background : AppColors.mint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: item.read ? AppColors.muted : AppColors.green,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            item.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      item.body,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        AppText(
                          compactDate(item.createdAt),
                          style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                        ),
                        if (item.orderNumber != null) ...[
                          const SizedBox(width: 8),
                          AppText(
                            item.orderNumber!,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
