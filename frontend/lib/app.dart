import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer_shell.dart';
import 'screens/delivery/delivery_shell.dart';
import 'screens/owner/owner_shell.dart';
import 'screens/splash_screen.dart';
import 'state/auth_provider.dart';
import 'widgets/common.dart';

/// Used by foreground FCM handlers to show a snackbar from outside the widget tree.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class PuranaBazaarApp extends StatelessWidget {
  const PuranaBazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purana Bazaar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: appMessengerKey,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) return const SplashScreen();
    if (!auth.isSignedIn) return const LoginScreen();

    switch (auth.user!.role) {
      case 'CUSTOMER':
        return const CustomerShell();
      case 'SHOP_OWNER':
        return const OwnerShell();
      case 'ADMIN':
        return const AdminShell();
      case 'DELIVERY_PARTNER':
        return const DeliveryShell();
      default:
        return const _UnsupportedRoleScreen();
    }
  }
}

class _UnsupportedRoleScreen extends StatelessWidget {
  const _UnsupportedRoleScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          maxWidth: 520,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(),
              const SizedBox(height: 24),
              const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Role not supported',
                message:
                    'This account has a role that this app version does not recognise. Please contact an administrator.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: auth.logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
