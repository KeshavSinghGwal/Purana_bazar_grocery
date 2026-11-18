import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  final ApiClient _api = ApiClient.instance;
  List<Shop> _shops = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  String _query = '';
  int? _busyId;

  static const _filters = [
    'All',
    'Pending',
    'Approved',
    'Suspended',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _shops.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/admin/shops') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _shops = data
            .whereType<Map>()
            .map((item) => Shop.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Shop> get _filtered {
    final term = _query.trim().toLowerCase();
    return _shops.where((shop) {
      final matchesFilter = switch (_filter) {
        'Pending' => shop.approvalStatus == 'PENDING_APPROVAL',
        'Approved' => shop.approvalStatus == 'APPROVED',
        'Suspended' => shop.approvalStatus == 'SUSPENDED',
        'Rejected' => shop.approvalStatus == 'REJECTED',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (term.isEmpty) return true;
      return shop.name.toLowerCase().contains(term) ||
          shop.ownerName.toLowerCase().contains(term) ||
          shop.address.toLowerCase().contains(term);
    }).toList();
  }

  Future<void> _approve(Shop shop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Approve this shop?'),
        content: AppText(
          '${shop.name} will become visible to customers and can start receiving orders immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(shop.id, () => _api.put('/admin/shops/${shop.id}/approve'), 'Shop approved.');
  }

  Future<void> _reasonAction(
    Shop shop, {
    required String action,
    required String title,
    required String hint,
    required String success,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr(context, 'Reason'), hintText: tr(context, hint)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: AppText(
              action,
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted) return;
    if (reason.isEmpty) {
      showMessage(context, 'Please provide a reason.', error: true);
      return;
    }
    await _run(
      shop.id,
      () => _api.put(
        '/admin/shops/${shop.id}/${action == 'Suspend' ? 'suspend' : 'reject'}',
        body: {'reason': reason},
      ),
      success,
    );
  }

  Future<void> _reactivate(Shop shop) async {
    await _run(
      shop.id,
      () => _api.put('/admin/shops/${shop.id}/reactivate'),
      'Shop reactivated.',
    );
  }

  Future<void> _run(int shopId, Future<dynamic> Function() action, String message) async {
    setState(() => _busyId = shopId);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, message);
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
        title: const AppText('Shop approvals'),
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
          maxWidth: 1000,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const LoadingView(message: 'Loading shops…')
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
                          TextField(
                            onChanged: (value) => setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: tr(context, 'Search shops, owners or addresses…'),
                              prefixIcon: Icon(Icons.search_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters
                                  .map(
                                    (filter) => Padding(
                                      padding: const EdgeInsets.only(right: 7),
                                      child: ChoiceChip(
                                        label: AppText(filter),
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
                                icon: Icons.storefront_outlined,
                                title: 'No shops found',
                                message: _filter == 'Pending'
                                    ? 'No registrations are waiting for approval.'
                                    : 'Try a different filter or search term.',
                              ),
                            )
                          else
                            ...filtered.map(
                              (shop) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _shopCard(shop),
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _shopCard(Shop shop) {
    final busy = _busyId == shop.id;
    final pending = shop.approvalStatus == 'PENDING_APPROVAL';
    final suspended = shop.approvalStatus == 'SUSPENDED';
    final rejected = shop.approvalStatus == 'REJECTED';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: shop.imageUrl,
                width: 58,
                height: 58,
                radius: 12,
                icon: Icons.storefront_rounded,
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
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(status: shop.approvalStatus),
                      ],
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      '${shop.ownerName} · ${shop.shopCategory ?? 'Neighbourhood store'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      shop.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _meta(Icons.place_outlined, '${shop.deliveryRadius.toStringAsFixed(1)} km radius'),
              _meta(Icons.schedule_rounded, '${friendlyTime(shop.openingTime)} – ${friendlyTime(shop.closingTime)}'),
              if (shop.phone != null) _meta(Icons.call_outlined, shop.phone!),
            ],
          ),
          if (shop.rejectionReason != null &&
              (suspended || rejected || pending)) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
              ),
              child: AppText(
                'Reason: ${shop.rejectionReason}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.red),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : () => _showDetails(shop),
                child: const AppText('Details'),
              ),
              const SizedBox(width: 4),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (pending) ...[
                TextButton(
                  onPressed: () => _reasonAction(
                    shop,
                    action: 'Reject',
                    title: 'Reject shop registration?',
                    hint: 'Let the owner know what needs fixing',
                    success: 'Shop rejected.',
                  ),
                  child: const AppText(
                    'Reject',
                    style: TextStyle(color: AppColors.red),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _approve(shop),
                  child: const AppText('Approve'),
                ),
              ] else if (shop.approvalStatus == 'APPROVED') ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: AppColors.red,
                  ),
                  onPressed: () => _reasonAction(
                    shop,
                    action: 'Suspend',
                    title: 'Suspend this shop?',
                    hint: 'The shop will be hidden from customers',
                    success: 'Shop suspended.',
                  ),
                  child: const AppText('Suspend'),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _reactivate(shop),
                  child: const AppText('Reactivate'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.paleMint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.green),
          const SizedBox(width: 4),
          AppText(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(Shop shop) {
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
                    child: AppText(
                      shop.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusPill(status: shop.approvalStatus),
                ],
              ),
              const SizedBox(height: 5),
              AppText(
                'Owned by ${shop.ownerName}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              AppImage(
                url: shop.imageUrl,
                width: double.infinity,
                height: 150,
                radius: 14,
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 14),
              InfoRow(label: 'Shop ID', value: '#${shop.id}'),
              InfoRow(label: 'Owner ID', value: '#${shop.ownerId}'),
              InfoRow(label: 'Category', value: shop.shopCategory ?? '—'),
              InfoRow(label: 'Phone', value: shop.phone ?? '—'),
              InfoRow(label: 'Address', value: shop.address),
              InfoRow(
                label: 'Delivery radius',
                value: '${shop.deliveryRadius.toStringAsFixed(1)} km',
              ),
              InfoRow(
                label: 'Opening hours',
                value:
                    '${friendlyTime(shop.openingTime)} – ${friendlyTime(shop.closingTime)}',
              ),
              InfoRow(
                label: 'Estimated delivery',
                value: '${shop.estimatedDeliveryMinutes} min',
              ),
              InfoRow(
                label: 'Operational status',
                value: statusLabel(shop.operationalStatus),
              ),
              if (shop.rejectionReason != null)
                InfoRow(label: 'Admin note', value: shop.rejectionReason!),
              InfoRow(
                label: 'Registered',
                value: fullDate(shop.createdAt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
