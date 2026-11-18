import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/cart_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../product/product_details_screen.dart';
import '../../core/localization.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ApiClient _api = ApiClient.instance;
  List<WishlistItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/wishlist') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = data
            .whereType<Map>()
            .map((item) => WishlistItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(WishlistItem item) async {
    try {
      await _api.delete('/wishlist/${item.product.id}');
      if (!mounted) return;
      setState(() => _items = _items.where((entry) => entry.id != item.id).toList());
      showMessage(context, 'Removed from wishlist.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _add(WishlistItem item) async {
    try {
      await context.read<CartProvider>().addProductChoice(item.product.id);
      if (mounted) showMessage(context, '${item.product.name} added to cart.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Wishlist'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 820,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const LoadingView(message: 'Loading your saved products…')
                : _error != null
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 480,
                            child: ErrorRetry(message: _error!, onRetry: _load),
                          ),
                        ],
                      )
                    : _items.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 520,
                                child: EmptyState(
                                  icon: Icons.favorite_border_rounded,
                                  title: 'Save what you love',
                                  message:
                                      'Tap the heart on any product to keep it here for later. Availability and best prices refresh automatically.',
                                  actionLabel: 'Browse products',
                                  onAction: () => Navigator.of(context).popUntil(
                                    (route) => route.isFirst,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _wishlistCard(item);
                            },
                          ),
          ),
        ),
      ),
    );
  }

  Widget _wishlistCard(WishlistItem item) {
    final product = item.product;
    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
        );
        if (mounted) _load();
      },
      child: Row(
        children: [
          AppImage(url: product.imageUrl, width: 78, height: 78, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.brand != null)
                  AppText(
                    product.brand!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.muted,
                    ),
                  ),
                AppText(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                AppText(
                  '${product.unit} · ${product.categoryName}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppText(
                      product.bestPrice == null ? 'Unavailable' : rupee(product.bestPrice!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: product.bestPrice == null ? AppColors.red : AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: product.available ? () => _add(item) : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(64, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const AppText('ADD'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.tr('Remove'),
            onPressed: () => _remove(item),
            icon: const Icon(Icons.favorite_rounded, color: AppColors.red, size: 20),
          ),
        ],
      ),
    );
  }
}
