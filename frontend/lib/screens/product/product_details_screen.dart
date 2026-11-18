import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/cart_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.shop,
    this.inventory,
  });

  final Product product;
  final Shop? shop;
  final InventoryItem? inventory;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ApiClient _api = ApiClient.instance;
  bool _wishlisted = false;
  bool _wishlistBusy = false;
  bool _addBusy = false;

  Product get product => widget.product;
  InventoryItem? get inventory => widget.inventory;
  double? get price => inventory?.price ?? product.bestPrice;
  int get stock => inventory?.availableQuantity ?? product.totalStock;
  bool get available => price != null && stock > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWishlistState());
  }

  Future<void> _loadWishlistState() async {
    try {
      final data = await _api.get('/wishlist') as List<dynamic>;
      final wl = data.whereType<Map>().map((item) => WishlistItem.fromJson(
            Map<String, dynamic>.from(item),
          ));
      if (mounted) {
        setState(() => _wishlisted = wl.any((item) => item.product.id == product.id));
      }
    } catch (_) {
      // Wishlist state is non-critical for the product page.
    }
  }

  Future<void> _toggleWishlist() async {
    if (_wishlistBusy) return;
    setState(() => _wishlistBusy = true);
    try {
      if (_wishlisted) {
        await _api.delete('/wishlist/${product.id}');
      } else {
        await _api.post('/wishlist/${product.id}');
      }
      if (!mounted) return;
      setState(() => _wishlisted = !_wishlisted);
      showMessage(context, _wishlisted ? 'Saved to wishlist.' : 'Removed from wishlist.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _wishlistBusy = false);
    }
  }

  Future<void> _add() async {
    if (_addBusy || !available) return;
    setState(() => _addBusy = true);
    try {
      final cart = context.read<CartProvider>();
      if (inventory != null) {
        await cart.addShopChoice(inventory!.id);
      } else {
        await cart.addProductChoice(product.id);
      }
      if (mounted) showMessage(context, '${product.name} added to cart.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _addBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Product details'),
        actions: [
          IconButton(
            tooltip: _wishlisted ? 'Remove from wishlist' : 'Save to wishlist',
            onPressed: _wishlistBusy ? null : _toggleWishlist,
            icon: Icon(
              _wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _wishlisted ? AppColors.red : AppColors.ink,
            ),
          ),
          const CartButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    url: product.imageUrl,
                    width: double.infinity,
                    height: 300,
                    radius: 24,
                  ),
                  const SizedBox(height: 20),
                  if (product.brand != null)
                    AppText(
                      product.brand!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.green,
                      ),
                    ),
                  const SizedBox(height: 4),
                  AppText(product.name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  AppText(
                    '${product.unit} · ${product.categoryName}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(
                        price == null ? 'Unavailable' : rupee(price!),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: price == null ? AppColors.red : AppColors.ink,
                        ),
                      ),
                      if (price != null) ...[
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: AppText(
                            'inclusive of all taxes',
                            style: TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoPill(
                        available ? Icons.check_circle_rounded : Icons.cancel_outlined,
                        available ? '$stock in stock' : 'Out of stock',
                        available ? AppColors.green : AppColors.red,
                      ),
                      _infoPill(
                        Icons.storefront_rounded,
                        inventory != null
                            ? 'From ${widget.shop?.name ?? 'selected shop'}'
                            : '${product.availableShops} shops can deliver',
                        AppColors.muted,
                      ),
                      _infoPill(
                        Icons.bolt_rounded,
                        inventory != null
                            ? 'Shop Choice'
                            : 'Nearest eligible shop at checkout',
                        AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('About this product', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        AppText(
                          product.description ??
                              'A quality-checked everyday essential, fulfilled by a verified neighbourhood shop.',
                          style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    color: AppColors.paleMint,
                    borderColor: AppColors.mint,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              inventory == null ? Icons.auto_awesome_rounded : Icons.storefront_rounded,
                              color: AppColors.green,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            AppText(
                              inventory == null ? 'Product Choice' : 'Shop Choice',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        AppText(
                          inventory == null
                              ? 'The backend compares every nearby eligible shop and assigns the complete cart to one shop. Stock and the final price are revalidated when you checkout.'
                              : 'This item is added using the inventory of ${widget.shop?.name ?? 'the selected shop'}. Your cart will stay locked to this shop.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          price == null ? 'Currently unavailable' : rupee(price!),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: price == null ? AppColors.red : AppColors.ink,
                          ),
                        ),
                        AppText(
                          available ? 'Ready from local stock' : 'Try another nearby product',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 176,
                    child: ElevatedButton.icon(
                      onPressed: available && !_addBusy ? _add : null,
                      icon: _addBusy
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: AppText(available ? 'Add to cart' : 'Unavailable'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          AppText(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
