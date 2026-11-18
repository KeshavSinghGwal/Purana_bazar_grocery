import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../screens/cart/cart_screen.dart';
import '../state/cart_provider.dart';
import '../core/localization.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((cart) => cart.cart.itemCount);
    return IconButton(
      tooltip: context.tr('Cart'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            color: onDark ? Colors.white : AppColors.ink,
          ),
          if (count > 0)
            Positioned(
              top: -6,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: AppText(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
