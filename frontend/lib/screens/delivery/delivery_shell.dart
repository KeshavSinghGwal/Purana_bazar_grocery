import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/delivery_provider.dart';
import 'delivery_available_screen.dart';
import 'delivery_dashboard_screen.dart';
import 'delivery_orders_screen.dart';

class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int _index = 0;

  static const _pages = [
    DeliveryDashboardScreen(),
    DeliveryAvailableScreen(),
    DeliveryOrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeliveryProvider(),
      child: Builder(
        builder: (context) => Scaffold(
          body: IndexedStack(index: _index, children: _pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) {
              setState(() => _index = index);
              if (index == 0) {
                context.read<DeliveryProvider>().load(silent: true);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Available',
              ),
              NavigationDestination(
                icon: Icon(Icons.delivery_dining_outlined),
                selectedIcon: Icon(Icons.delivery_dining_rounded),
                label: 'Deliveries',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
