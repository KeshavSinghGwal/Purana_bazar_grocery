import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class OwnerShopScreen extends StatefulWidget {
  const OwnerShopScreen({super.key});

  @override
  State<OwnerShopScreen> createState() => _OwnerShopScreenState();
}

class _OwnerShopScreenState extends State<OwnerShopScreen> {
  final ApiClient _api = ApiClient.instance;
  Shop? _shop;
  bool _loading = true;
  bool _toggling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _shop == null;
      _error = null;
    });
    try {
      final data = await _api.get('/shop-owner/shop') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _shop = Shop.fromJson(data));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOpen() async {
    final shop = _shop;
    if (shop == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      final data = await _api.put('/shop-owner/shop/open', body: {
        'open': shop.operationalStatus != 'ACTIVE',
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _shop = Shop.fromJson(data));
      showMessage(
        context,
        _shop!.operationalStatus == 'ACTIVE'
            ? 'Your shop is now open for orders.'
            : 'Your shop is temporarily closed.',
      );
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _editShop() async {
    final shop = _shop;
    if (shop == null) return;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: shop.name);
    final description = TextEditingController(text: shop.description ?? '');
    final address = TextEditingController(text: shop.address);
    final radius = TextEditingController(text: shop.deliveryRadius.toString());
    final eta = TextEditingController(text: '${shop.estimatedDeliveryMinutes}');
    final phone = TextEditingController(text: shop.phone ?? '');
    bool deliveryAvailable = shop.deliveryAvailable;
    bool busy = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Edit shop details'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(labelText: tr(context, 'Shop name')),
                      validator: _required,
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Description'),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: address,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Address'),
                        alignLabelWithHint: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: radius,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: tr(context, 'Radius (km)')),
                            validator: (value) {
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed < 0.5 || parsed > 50) {
                                return AppLocalizations.current.tr('0.5–50 km');
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: eta,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: tr(context, 'ETA (min)')),
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed < 5 || parsed > 240) {
                                return AppLocalizations.current.tr('5–240');
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: phone,
                      decoration: InputDecoration(labelText: tr(context, 'Shop phone')),
                    ),
                    const SizedBox(height: 5),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppColors.green,
                      title: const AppText(
                        'Delivery available',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      value: deliveryAvailable,
                      onChanged: (value) =>
                          setDialogState(() => deliveryAvailable = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        final data = await _api.put('/shop-owner/shop', body: {
                          'name': name.text.trim(),
                          'description': description.text.trim(),
                          'address': address.text.trim(),
                          'deliveryRadius': double.parse(radius.text.trim()),
                          'estimatedDeliveryMinutes': int.parse(eta.text.trim()),
                          'phone': phone.text.trim(),
                          'deliveryAvailable': deliveryAvailable,
                        }) as Map<String, dynamic>;
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                        if (mounted) {
                          setState(() => _shop = Shop.fromJson(data));
                          showMessage(context, 'Shop details updated.');
                        }
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          showMessage(context, error.message, error: true);
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const AppText('Save changes'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    address.dispose();
    radius.dispose();
    eta.dispose();
    phone.dispose();
    if (saved == true && mounted) _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Sign out?'),
        content: const AppText('You will need to sign in again to manage your shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Sign out', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('My shop'),
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
          maxWidth: 760,
          child: _loading
              ? const LoadingView(message: 'Loading your shop…')
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _load)
                  : shop == null
                      ? const EmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'No shop found',
                          message: 'No shop is linked to this owner account.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            children: [
                              AppCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    AppImage(
                                      url: shop.imageUrl,
                                      width: double.infinity,
                                      height: 180,
                                      radius: 18,
                                      icon: Icons.storefront_rounded,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: AppText(
                                                  shop.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall,
                                                ),
                                              ),
                                              StatusPill(status: shop.approvalStatus),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          AppText(
                                            shop.address,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              height: 1.45,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              StatusPill(
                                                status: shop.operationalStatus,
                                                icon: Icons.storefront_outlined,
                                              ),
                                              StatusPill(
                                                status:
                                                    '${shop.estimatedDeliveryMinutes} min',
                                                icon: Icons.delivery_dining_rounded,
                                              ),
                                              StatusPill(
                                                status:
                                                    '${shop.deliveryRadius.toStringAsFixed(1)} km radius',
                                                icon: Icons.radar_rounded,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (shop.approvalStatus != 'APPROVED') ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: shop.approvalStatus == 'REJECTED'
                                        ? AppColors.red.withValues(alpha: 0.06)
                                        : const Color(0xFFFFF9EC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: shop.approvalStatus == 'REJECTED'
                                          ? AppColors.red.withValues(alpha: 0.16)
                                          : const Color(0xFFF3E3BC),
                                    ),
                                  ),
                                  child: AppText(
                                    shop.approvalStatus == 'REJECTED'
                                        ? 'Rejected: ${shop.rejectionReason ?? 'Contact support for details.'}'
                                        : 'Your shop is awaiting approval. It stays hidden from customers until approved.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: shop.approvalStatus == 'REJECTED'
                                          ? AppColors.red
                                          : const Color(0xFF8A5900),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              AppCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.power_settings_new_rounded,
                                            color: AppColors.green, size: 22),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              AppText(
                                                'Accepting orders',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              AppText(
                                                'Close the shop for a short break without losing settings.',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch.adaptive(
                                          activeTrackColor: AppColors.green,
                                          value: shop.operationalStatus == 'ACTIVE',
                                          onChanged: _toggling ? null : (_) => _toggleOpen(),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 22),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule_rounded,
                                            color: AppColors.muted, size: 18),
                                        const SizedBox(width: 7),
                                        AppText(
                                          '${friendlyTime(shop.openingTime)} – ${friendlyTime(shop.closingTime)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _editShop,
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          label: const AppText('Edit shop'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (user != null)
                                AppCard(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 21,
                                        backgroundColor: AppColors.mint,
                                        child: AppText(
                                          initials(user.name),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            AppText(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            AppText(
                                              user.email,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const StatusPill(status: 'SHOP OWNER'),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout_rounded,
                                    size: 18, color: AppColors.red),
                                label: const AppText(
                                  'Sign out',
                                  style: TextStyle(color: AppColors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
}
