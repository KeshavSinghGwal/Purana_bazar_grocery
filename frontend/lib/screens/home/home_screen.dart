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
import '../../widgets/language_selector.dart';
import '../../widgets/notification_button.dart';
import '../location/addresses_screen.dart';
import '../product/product_choice_screen.dart';
import '../product/product_details_screen.dart';
import '../shop/shop_choice_screen.dart';
import '../shop/shop_details_screen.dart';
import '../../core/localization.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient.instance;
  HomeData? _data;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  bool _started = false;
  LocationProvider? _location;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = context.read<LocationProvider>();
    if (!identical(_location, location)) {
      _location?.removeListener(_onLocationChanged);
      _location = location;
      location.addListener(_onLocationChanged);
    }
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (location.addresses.isEmpty && !location.loading) {
          await location.load();
        }
        if (mounted) await _loadHome();
      });
    }
  }

  @override
  void dispose() {
    _location?.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (!mounted || _location?.loading == true) return;
    _loadHome();
  }

  Future<void> _loadHome() async {
    final location = context.read<LocationProvider>();
    if (location.loading) return;
    final address = location.selected;
    final requestId = ++_requestId;
    if (_data == null) setState(() => _loading = true);
    try {
      final data = await _api.get('/marketplace/home', query: {
        'lat': address?.latitude,
        'lng': address?.longitude,
      }) as Map<String, dynamic>;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = HomeData.fromJson(data);
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct(Product product) async {
    try {
      await context.read<CartProvider>().addProductChoice(product.id);
      if (mounted) showMessage(context, '${product.name} added to cart.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _chooseAddress() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddressesScreen(selectionMode: true)),
    );
    if (mounted) _loadHome();
  }

  @override
  Widget build(BuildContext context) {
    final address = context.watch<LocationProvider>().selected;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: PageWidth(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
              children: [
                Row(
                  children: [
                    const Expanded(child: AppLogo(small: true)),
                    const LanguageButton(),
                    const NotificationButton(),
                    const CartButton(),
                    const SizedBox(width: 2),
                  ],
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: _chooseAddress,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.near_me_rounded,
                              color: AppColors.green, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText(
                                'DELIVERING TO',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                address == null
                                    ? 'Set your delivery location'
                                    : '${address.label} · ${address.addressLine}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _searchBar(),
                const SizedBox(height: 18),
                _heroCard(context),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'How do you want to shop?',
                  subtitle: 'Both modes are powered by real shop inventory.',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 700;
                    final cards = [
                      _modeCard(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        eyebrow: 'PRODUCT CHOICE',
                        title: 'Best nearby shop for your full cart',
                        description:
                            'We compare nearby shops, stock and prices, then pick one shop that can fulfil everything.',
                        color: AppColors.green,
                        background: const Color(0xFFF1FAF2),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProductChoiceScreen()),
                        ),
                      ),
                      _modeCard(
                        context,
                        icon: Icons.storefront_rounded,
                        eyebrow: 'SHOP CHOICE',
                        title: 'Shop from your favourite store',
                        description:
                            'Browse verified neighbourhood shops, see live stock and order directly from the one you choose.',
                        color: const Color(0xFF9B5B00),
                        background: const Color(0xFFFFF9EC),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShopChoiceScreen()),
                        ),
                      ),
                    ];
                    if (wide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_loading && _data == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: LoadingView(message: 'Gathering nearby shops…'),
                  )
                else if (_error != null && _data == null)
                  SizedBox(
                    height: 260,
                    child: ErrorRetry(message: _error!, onRetry: _loadHome),
                  )
                else if (_data != null) ...[
                  if (_data!.categories.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Shop by category',
                      actionLabel: 'Explore all',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductChoiceScreen()),
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _data!.categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 9),
                        itemBuilder: (context, index) {
                          final category = _data!.categories[index];
                          return CategoryTile(
                            category: category,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductChoiceScreen(
                                  categoryId: category.id,
                                  initialCategoryName: category.name,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_data!.featuredProducts.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Fresh picks near you',
                      subtitle: 'Live prices from approved local shops',
                      actionLabel: 'See products',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductChoiceScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _productGrid(_data!.featuredProducts.take(10).toList()),
                    const SizedBox(height: 24),
                  ],
                  if (_data!.nearbyShops.isNotEmpty) ...[
                    SectionHeader(
                      title: address == null ? 'Popular shops' : 'Shops around you',
                      subtitle: address == null
                          ? 'Set a location to see delivery distance'
                          : 'Nearest first · delivery radius checked',
                      actionLabel: 'Shop Choice',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShopChoiceScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 236,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _data!.nearbyShops.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final shop = _data!.nearbyShops[index];
                          return ShopCard(
                            shop: shop,
                            width: 270,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShopDetailsScreen(shop: shop),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _deliveryBanner(),
                  const SizedBox(height: 22),
                  const Center(
                    child: AppText(
                      'Locally sourced · Shop-verified stock · Delivery radius enforced',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.soft),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      radius: 14,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProductChoiceScreen(focusSearch: true),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.muted, size: 22),
          SizedBox(width: 9),
          Expanded(
            child: AppText(
              'Search milk, atta, fruits and more…',
              style: TextStyle(fontSize: 13, color: AppColors.soft),
            ),
          ),
          Icon(Icons.tune_rounded, color: AppColors.muted, size: 19),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final address = context.watch<LocationProvider>().selected;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -42,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: -24,
            child: Icon(
              Icons.shopping_basket_rounded,
              size: 108,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const AppText(
                  'NEIGHBOURHOOD GROCERY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppText(
                address == null
                    ? 'Groceries from shops\njust around the corner.'
                    : 'Delivered from a shop\n${address.label == 'Home' ? 'near your home' : 'near you'}.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 9),
              AppText(
                '${_data?.totalShops ?? 0} approved shops · ${_data?.totalProducts ?? 0} in-stock products',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill(Icons.bolt_rounded, 'Fast local delivery'),
                  _heroPill(Icons.inventory_2_outlined, 'Live shop stock'),
                  _heroPill(Icons.verified_outlined, 'Verified shops'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            AppText(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _modeCard(
    BuildContext context, {
    required IconData icon,
    required String eyebrow,
    required String title,
    required String description,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: background,
      borderColor: color.withValues(alpha: 0.16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 13),
          AppText(
            eyebrow,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productGrid(List<Product> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 40) return const SizedBox.shrink();
        final columns = constraints.maxWidth >= 980
            ? 5
            : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 500
                    ? 3
                    : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 302,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onAdd: product.available ? () => _addProduct(product) : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(product: product),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _deliveryBanner() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3E3BC)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining_rounded,
                color: AppColors.ink, size: 23),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Free delivery above ₹199',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 3),
                AppText(
                  'A flat ₹19 delivery fee applies to smaller orders. The nearest eligible shop is chosen at checkout.',
                  style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
