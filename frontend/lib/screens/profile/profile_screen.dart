import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/location_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_button.dart';
import '../../state/notification_provider.dart';
import '../location/addresses_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_history_screen.dart';
import '../wishlist/wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context, AuthProvider auth) async {
    final name = TextEditingController(text: auth.user?.name ?? '');
    final phone = TextEditingController(text: auth.user?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) =>
                    value == null || value.trim().length < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) {
      name.dispose();
      phone.dispose();
      return;
    }
    try {
      await auth.updateProfile(
        name: name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      );
      name.dispose();
      phone.dispose();
      if (context.mounted) showMessage(context, 'Profile updated.');
    } on ApiException catch (error) {
      name.dispose();
      phone.dispose();
      if (context.mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your cart and selected address will be cleared from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<CartProvider>().clearLocal();
    context.read<LocationProvider>().clear();
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifications = context.watch<NotificationProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [
          NotificationButton(),
          CartButton(),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        initials(user?.name ?? 'Purana Bazaar'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Customer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11.5,
                            ),
                          ),
                          if (user?.phone != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              user!.phone!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editProfile(context, auth),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 21),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel(context, 'YOUR ACCOUNT'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tile(
                      icon: Icons.location_on_outlined,
                      title: 'Saved addresses',
                      subtitle: 'Home, office and delivery locations',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddressesScreen()),
                      ),
                    ),
                    const Divider(height: 1, indent: 58),
                    _tile(
                      icon: Icons.receipt_long_outlined,
                      title: 'My orders',
                      subtitle: 'Track, cancel or review past orders',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                      ),
                    ),
                    const Divider(height: 1, indent: 58),
                    _tile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: notifications.unread > 0
                          ? '${notifications.unread} unread update${notifications.unread == 1 ? '' : 's'}'
                          : 'Order updates, payments and alerts',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      ),
                    ),
                    if (notifications.pushConfigured) ...[
                      const Divider(height: 1, indent: 58),
                      _tile(
                        icon: notifications.pushDenied
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active_outlined,
                        title: notifications.pushDenied
                            ? 'Allow push notifications'
                            : 'Push notifications',
                        subtitle: notifications.pushDenied
                            ? 'Blocked in this browser or device'
                            : 'Enabled on this device',
                        onTap: notifications.enablePush,
                      ),
                    ],
                    const Divider(height: 1, indent: 58),
                    _tile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Wishlist',
                      subtitle: 'Products you saved for later',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WishlistScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel(context, 'ABOUT'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tile(
                      icon: Icons.storefront_outlined,
                      title: 'How Purana Bazaar works',
                      subtitle: 'Product Choice and Shop Choice explained',
                      onTap: () => _showAbout(context),
                    ),
                    const Divider(height: 1, indent: 58),
                    _tile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & support',
                      subtitle: 'Delivery, cancellations and stock questions',
                      onTap: () => _showHelp(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                label: const Text('Sign out', style: TextStyle(color: AppColors.red)),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Purana Bazaar · Neighbourhood grocery marketplace',
                  style: TextStyle(fontSize: 10, color: AppColors.soft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: AppColors.muted,
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.paleMint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.green, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }

  void _showAbout(BuildContext context) {
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
            const SizedBox(height: 20),
            const AppLogo(small: true),
            const SizedBox(height: 18),
            Text('Two ways to shop', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const _AboutPoint(
              icon: Icons.auto_awesome_rounded,
              title: 'Product Choice',
              text:
                  'Add products from the marketplace. At checkout the backend evaluates approved, active shops within their delivery radius, checks complete stock, and chooses the nearest shop that can fulfil the entire cart. Orders are never split.',
            ),
            const SizedBox(height: 12),
            const _AboutPoint(
              icon: Icons.storefront_rounded,
              title: 'Shop Choice',
              text:
                  'Pick a shop first. Browsing and checkout use only that shop’s inventory. Your cart is locked to that shop, and mixed-shop carts are rejected.',
            ),
            const SizedBox(height: 12),
            const _AboutPoint(
              icon: Icons.lock_outline_rounded,
              title: 'Server-verified',
              text:
                  'Shop selection, prices, delivery fees, stock validation and stock updates happen on the server inside a transaction. Client prices are never trusted.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & support'),
        content: const Text(
          'For demo support, contact support@puranabazaar.com. You can cancel orders in Pending, Accepted or Preparing states from the order details screen. Delivered orders can be reviewed.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AboutPoint extends StatelessWidget {
  const _AboutPoint({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.paleMint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.green, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
