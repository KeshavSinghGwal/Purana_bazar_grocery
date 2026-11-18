import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/cart_provider.dart';
import '../../state/location_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';
import '../location/addresses_screen.dart';
import 'product_details_screen.dart';
import '../../core/localization.dart';

class ProductChoiceScreen extends StatefulWidget {
  const ProductChoiceScreen({
    super.key,
    this.initialQuery = '',
    this.categoryId,
    this.initialCategoryName,
    this.focusSearch = false,
  });

  final String initialQuery;
  final int? categoryId;
  final String? initialCategoryName;
  final bool focusSearch;

  @override
  State<ProductChoiceScreen> createState() => _ProductChoiceScreenState();
}

class _ProductChoiceScreenState extends State<ProductChoiceScreen> {
  final ApiClient _api = ApiClient.instance;
  late final TextEditingController _search;
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<Category> _categories = const [];
  List<Product> _products = const [];
  int? _categoryId;
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _quoting = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery;
    _categoryId = widget.categoryId;
    _loadCategories();
    _loadProducts();
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _api.get('/categories') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _categories = data
            .whereType<Map>()
            .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } catch (_) {
      // Category filters are optional; the product list still works.
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/marketplace/products', query: {
        'q': _query.trim().isEmpty ? null : _query.trim(),
        'categoryId': _categoryId,
        'page': 0,
        'size': 60,
      }) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _products = content
            .whereType<Map>()
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), _loadProducts);
  }

  Future<void> _add(Product product) async {
    try {
      await context.read<CartProvider>().addProductChoice(product.id);
      if (mounted) showMessage(context, '${product.name} added to cart.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _findShop() async {
    final cart = context.read<CartProvider>().cart;
    if (cart.isEmpty) {
      showMessage(context, 'Add a few products first so we can find a shop.', error: true);
      return;
    }
    if (!cart.isProductChoice) {
      showMessage(
        context,
        'Your cart is using Shop Choice. Clear it before switching to Product Choice.',
        error: true,
      );
      return;
    }
    final location = context.read<LocationProvider>();
    if (location.selected != null) {
      setState(() => _quoting = true);
      try {
        final data = await _api.post('/marketplace/find-shop', body: {
          'addressId': location.selected!.id,
        }) as Map<String, dynamic>;
        if (!mounted) return;
        final quote = ShopQuote.fromJson(data);
        await _showQuote(quote);
      } on ApiException catch (error) {
        if (mounted) showMessage(context, error.message, error: true);
      } finally {
        if (mounted) setState(() => _quoting = false);
      }
    } else {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const AddressesScreen(selectionMode: true),
        ),
      );
      if (result == true) _findShop();
    }
  }

  Future<void> _showQuote(ShopQuote quote) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: quote.found ? AppColors.mint : AppColors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          quote.found ? Icons.auto_awesome_rounded : Icons.search_off_rounded,
                          color: quote.found ? AppColors.green : AppColors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              quote.found ? 'Best shop found' : 'No eligible shop',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            AppText(
                              quote.found
                                  ? 'One shop will fulfil your complete cart'
                                  : 'We never split an order across shops',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (quote.found && quote.selectedShop != null) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.paleMint,
                      borderColor: AppColors.mint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded,
                                  color: AppColors.green, size: 23),
                              const SizedBox(width: 9),
                              Expanded(
                                child: AppText(
                                  quote.selectedShop!.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (quote.distanceKm != null)
                                StatusPill(
                                  status: '${quote.distanceKm!.toStringAsFixed(1)} km',
                                  icon: Icons.near_me_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            quote.selectedShop!.address,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              RatingPill(
                                rating: quote.selectedShop!.rating,
                                count: quote.selectedShop!.reviewCount,
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.delivery_dining_rounded,
                                  size: 15, color: AppColors.green),
                              const SizedBox(width: 3),
                              AppText(
                                '${quote.selectedShop!.estimatedDeliveryMinutes} min',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText('Fulfilment check', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 7),
                    ...quote.items.map(
                      (line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.green, size: 17),
                            const SizedBox(width: 7),
                            Expanded(
                              child: AppText(
                                '${line.name} × ${line.requestedQuantity}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            AppText(
                              rupee(line.lineTotal),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 26),
                    InfoRow(label: 'Subtotal', value: rupee(quote.subtotal)),
                    InfoRow(label: 'Delivery', value: rupee(quote.deliveryCharge)),
                    InfoRow(
                      label: 'Total',
                      value: rupee(quote.totalAmount),
                      bold: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const AppText('Review cart & checkout'),
                      ),
                    ),
                  ] else ...[
                    AppText(
                      quote.message ??
                          'No nearby shop can fulfil the complete cart right now.',
                      style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
                    ),
                    if (quote.unavailableProducts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      AppText('Unavailable products',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...quote.unavailableProducts.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.red, size: 19),
                              const SizedBox(width: 9),
                              Expanded(
                                child: AppText(
                                  '${item.name} — requested ${item.requestedQuantity}, max ${item.maxAvailable}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (quote.consideredShops.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      AppText('Shops considered',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 7),
                      ...quote.consideredShops.take(6).map(
                            (candidate) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Icon(
                                    candidate.eligible
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.cancel_outlined,
                                    size: 16,
                                    color: candidate.eligible
                                        ? AppColors.green
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: AppText(
                                      '${candidate.name} · ${candidate.distanceKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  Flexible(
                                    child: AppText(
                                      candidate.reason ?? (candidate.eligible ? 'Eligible' : 'Not eligible'),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const AppText('Edit cart'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = context.watch<CartProvider>().cart.itemCount;
    return Scaffold(
      appBar: AppBar(
        title: AppText(widget.initialCategoryName ?? 'Product Choice'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: PageWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _loadProducts(),
                      decoration: InputDecoration(
                        hintText: tr(context, 'Search products, brands or categories…'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  _onSearchChanged('');
                                },
                                icon: const Icon(Icons.close_rounded, size: 19),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF1FAF2), Color(0xFFE7F6EA)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.mint),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: AppColors.green, size: 23),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'One cart, one shop',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                                SizedBox(height: 2),
                                AppText(
                                  'We find the nearest shop with every item in stock. Your order is never split.',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.4,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (itemCount > 0)
                            TextButton(
                              onPressed: _quoting ? null : _findShop,
                              child: _quoting
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const AppText('Find shop'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const AppText('All'),
                            selected: _categoryId == null,
                            onSelected: (_) {
                              setState(() => _categoryId = null);
                              _loadProducts();
                            },
                          ),
                          const SizedBox(width: 7),
                          ..._categories.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: AppText(category.name),
                                selected: _categoryId == category.id,
                                onSelected: (_) {
                                  setState(() => _categoryId =
                                      _categoryId == category.id ? null : category.id);
                                  _loadProducts();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_loading && _error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 11, bottom: 2),
                        child: Row(
                          children: [
                            AppText(
                              '${_products.length} products',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.sort_rounded, size: 15, color: AppColors.muted),
                            const SizedBox(width: 4),
                            const AppText(
                              'Best price',
                              style: TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const LoadingView(message: 'Comparing nearby shops…')
                    : _error != null
                        ? ErrorRetry(message: _error!, onRetry: _loadProducts)
                        : _products.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'Nothing matched',
                                message:
                                    'Try a different search term or category. New local products are added often.',
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 40) {
                                    return const SizedBox.shrink();
                                  }
                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                                    itemCount: _products.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 230,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 302,
                                    ),
                                    itemBuilder: (context, index) {
                                      final product = _products[index];
                                      return ProductCard(
                                        product: product,
                                        onAdd: product.available ? () => _add(product) : null,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductDetailsScreen(product: product),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
