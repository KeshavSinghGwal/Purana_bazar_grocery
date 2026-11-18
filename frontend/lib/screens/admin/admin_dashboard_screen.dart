import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/language_selector.dart';
import '../../core/localization.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiClient _api = ApiClient.instance;
  AdminDashboard? _data;
  List<Shop> _pending = const [];
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
      final results = await Future.wait<dynamic>([
        _api.get('/admin/dashboard'),
        _api.get('/admin/shops/pending'),
      ]);
      if (!mounted) return;
      final dashboard = AdminDashboard.fromJson(
        Map<String, dynamic>.from(results[0] as Map),
      );
      final pending = (results[1] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Shop.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      setState(() {
        _data = dashboard;
        _pending = pending;
      });
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
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Admin console'),
        actions: [
          const LanguageButton(),
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: context.tr('Sign out'),
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 1100,
          child: _loading
              ? const LoadingView(message: 'Loading marketplace health…')
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _load)
                  : data == null
                      ? const EmptyState(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Dashboard unavailable',
                          message: 'The admin dashboard could not be loaded.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
                            children: [
                              _hero(auth.user?.name ?? 'Administrator'),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 900
                                      ? 5
                                      : constraints.maxWidth >= 620
                                          ? 3
                                          : 2;
                                  final width =
                                      (constraints.maxWidth - (columns - 1) * 10) /
                                          columns;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _stat(
                                        width,
                                        'Total sales',
                                        rupee(data.totalSales),
                                        Icons.currency_rupee_rounded,
                                        AppColors.green,
                                      ),
                                      _stat(
                                        width,
                                        'Live shops',
                                        '${data.approvedShops}',
                                        Icons.storefront_rounded,
                                        const Color(0xFF1565C0),
                                      ),
                                      _stat(
                                        width,
                                        'Pending shops',
                                        '${data.pendingShops}',
                                        Icons.hourglass_top_rounded,
                                        AppColors.orange,
                                      ),
                                      _stat(
                                        width,
                                        'Customers',
                                        '${data.totalCustomers}',
                                        Icons.people_outline_rounded,
                                        const Color(0xFF6A1B9A),
                                      ),
                                      _stat(
                                        width,
                                        'Orders',
                                        '${data.totalOrders}',
                                        Icons.receipt_long_outlined,
                                        AppColors.ink,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              SectionHeader(
                                title: 'Approval queue',
                                subtitle: _pending.isEmpty
                                    ? 'No shops are waiting for review'
                                    : '${_pending.length} shop${_pending.length == 1 ? '' : 's'} awaiting approval',
                                actionLabel: 'Review all',
                                onAction: () => widget.onNavigate?.call(1),
                              ),
                              const SizedBox(height: 10),
                              if (_pending.isEmpty)
                                AppCard(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: AppColors.green,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: AppText(
                                          'Everything is reviewed. New shop registrations will appear here.',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._pending.take(4).map(
                                      (shop) => Padding(
                                        padding: const EdgeInsets.only(bottom: 9),
                                        child: AppCard(
                                          padding: const EdgeInsets.all(13),
                                          onTap: () => widget.onNavigate?.call(1),
                                          child: Row(
                                            children: [
                                              AppImage(
                                                url: shop.imageUrl,
                                                width: 46,
                                                height: 46,
                                                radius: 11,
                                                icon: Icons.storefront_rounded,
                                              ),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    AppText(
                                                      shop.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    AppText(
                                                      '${shop.ownerName} · ${shop.address}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: AppColors.muted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const StatusPill(
                                                status: 'PENDING_APPROVAL',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 18),
                              SectionHeader(
                                title: 'Marketplace at a glance',
                                subtitle: 'Live totals across customers and the catalog',
                              ),
                              const SizedBox(height: 10),
                              _overview(data),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _hero(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'MARKETPLACE CONTROL',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  'Welcome, $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  'Approve shops, watch orders and curate the catalog from one place.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    double width,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 33,
              height: 33,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            AppText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            AppText(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview(AdminDashboard data) {
    return AppCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          InfoRow(label: 'Approved shops', value: '${data.approvedShops}'),
          InfoRow(label: 'Suspended shops', value: '${data.suspendedShops}'),
          InfoRow(
            label: 'Active customers',
            value: '${data.activeCustomers} of ${data.totalCustomers}',
          ),
          InfoRow(label: 'Catalog products', value: '${data.totalProducts}'),
          InfoRow(label: 'Active categories', value: '${data.totalCategories}'),
          const Divider(height: 20),
          InfoRow(label: 'Pending orders', value: '${data.pendingOrders}'),
          InfoRow(label: 'Delivered orders', value: '${data.completedOrders}'),
          InfoRow(label: 'Cancelled / rejected', value: '${data.cancelledOrders}'),
        ],
      ),
    );
  }
}
