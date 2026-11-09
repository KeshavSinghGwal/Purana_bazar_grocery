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
import '../product/product_details_screen.dart';

class ShopDetailsScreen extends StatefulWidget {
  const ShopDetailsScreen({super.key, required this.shop});

  final Shop shop;

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final ApiClient _api = ApiClient.instance;
  late Shop _shop;
  List<InventoryItem> _inventory = const [];
  List<Review> _reviews = const [];
  int? _categoryId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = _inventory.isEmpty;
      _error = null;
    });
    final address = context.read<LocationProvider>().selected;
    try {
      final shopData = await _api.get('/shops/${widget.shop.id}', query: {
        'lat': address?.latitude,
        'lng': address?.longitude,
      }) as Map<String, dynamic>;
      final inventoryData = await _api.get('/shops/${widget.shop.id}/inventory')
          as List<dynamic>;
      final reviewData = await _api.get('/shops/${widget.shop.id}/reviews')
          as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _shop = Shop.fromJson(shopData);
        _inventory = inventoryData
            .whereType<Map>()
            .map((item) => InventoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _reviews = reviewData
            .whereType<Map>()
            .map((item) => Review.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(InventoryItem inventory) async {
    try {
      await context.read<CartProvider>().addShopChoice(inventory.id);
      if (mounted) showMessage(context, '${inventory.productName} added to cart.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _writeReview() async {
    int rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this shop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFF5A623),
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Share your experience (optional)',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can review a shop only after a delivered order from it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      comment.dispose();
      return;
    }
    try {
      await _api.post('/shops/${_shop.id}/reviews', body: {
        'rating': rating,
        'comment': comment.text.trim().isEmpty ? null : comment.text.trim(),
      });
      comment.dispose();
      if (!mounted) return;
      showMessage(context, 'Thanks for reviewing ${_shop.name}.');
      await _load();
    } on ApiException catch (error) {
      comment.dispose();
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  List<Category> get _inventoryCategories {
    final map = <int, Category>{};
    for (final item in _inventory) {
      map[item.categoryId] = Category(
        id: item.categoryId,
        name: item.categoryName,
        active: true,
        displayOrder: 0,
      );
    }
    return map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<InventoryItem> get _filteredInventory => _categoryId == null
      ? _inventory
      : _inventory.where((item) => item.categoryId == _categoryId).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInventory;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop details'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: PageWidth(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
              children: [
                Stack(
                  children: [
                    AppImage(
                      url: _shop.imageUrl,
                      width: double.infinity,
                      height: 210,
                      radius: 24,
                      icon: Icons.storefront_rounded,
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _shop.name,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ),
                                      if (_shop.rating != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.green,
                                            borderRadius: BorderRadius.circular(7),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                _shop.rating!.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              const Icon(Icons.star_rounded,
                                                  color: Colors.white, size: 12),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_shop.shopCategory ?? 'Neighbourhood store'} · ${_shop.address}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.4,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(status: _shop.openNow ? 'ACTIVE' : 'TEMPORARILY_CLOSED'),
                    if (_shop.distanceKm != null)
                      StatusPill(
                        status: '${_shop.distanceKm!.toStringAsFixed(1)} km',
                        icon: Icons.near_me_rounded,
                      ),
                    StatusPill(
                      status: '${_shop.estimatedDeliveryMinutes} min',
                      icon: Icons.delivery_dining_rounded,
                    ),
                    StatusPill(
                      status: _shop.deliveryAvailable ? 'Delivery available' : 'Pickup only',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
                if (!_shop.deliverable) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.16)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'This shop is outside its delivery radius for your current address. Checkout will be blocked.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Shop inventory',
                  subtitle: '${_inventory.length} live listings · prices and stock from this shop',
                ),
                const SizedBox(height: 10),
                if (_inventoryCategories.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('All items'),
                          selected: _categoryId == null,
                          onSelected: (_) => setState(() => _categoryId = null),
                        ),
                        const SizedBox(width: 7),
                        ..._inventoryCategories.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(category.name),
                              selected: _categoryId == category.id,
                              onSelected: (_) => setState(() =>
                                  _categoryId =
                                      _categoryId == category.id ? null : category.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: LoadingView(message: 'Loading shop inventory…'),
                  )
                else if (_error != null)
                  SizedBox(
                    height: 260,
                    child: ErrorRetry(message: _error!, onRetry: _load),
                  )
                else if (filtered.isEmpty)
                  const SizedBox(
                    height: 260,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products in this category',
                      message: 'Try another category, or check back after the shop updates its stock.',
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 40) {
                        return const SizedBox.shrink();
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 302,
                        ),
                        itemBuilder: (context, index) {
                          final inventory = filtered[index];
                          final product = Product(
                            id: inventory.productId,
                            name: inventory.productName,
                            brand: inventory.brand,
                            categoryId: inventory.categoryId,
                            categoryName: inventory.categoryName,
                            imageUrl: inventory.imageUrl,
                            unit: inventory.unit,
                            active: inventory.active,
                            bestPrice: inventory.price,
                            availableShops: 1,
                            totalStock: inventory.availableQuantity,
                          );
                          return ProductCard(
                            product: product,
                            onAdd: inventory.availableQuantity > 0
                                ? () => _add(inventory)
                                : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailsScreen(
                                  product: product,
                                  shop: _shop,
                                  inventory: inventory,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Customer reviews',
                  subtitle: _reviews.isEmpty
                      ? 'No reviews yet'
                      : '${_reviews.length} verified customer review${_reviews.length == 1 ? '' : 's'}',
                  actionLabel: 'Rate shop',
                  onAction: _writeReview,
                ),
                const SizedBox(height: 10),
                if (_reviews.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.rate_review_outlined,
                            color: AppColors.muted, size: 24),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Be the first to review this shop after a delivered order.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._reviews.take(4).map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppColors.mint,
                                      child: Text(
                                        initials(review.customerName),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        review.customerName,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => Icon(
                                          index < review.rating
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          size: 14,
                                          color: const Color(0xFFF5A623),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (review.comment != null) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    review.comment!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Text(
                                  compactDate(review.createdAt),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.soft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
