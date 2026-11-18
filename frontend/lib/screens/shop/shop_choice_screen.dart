import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../state/location_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../location/addresses_screen.dart';
import 'shop_details_screen.dart';
import '../../core/localization.dart';

class ShopChoiceScreen extends StatefulWidget {
  const ShopChoiceScreen({super.key});

  @override
  State<ShopChoiceScreen> createState() => _ShopChoiceScreenState();
}

class _ShopChoiceScreenState extends State<ShopChoiceScreen> {
  final ApiClient _api = ApiClient.instance;
  final TextEditingController _search = TextEditingController();
  List<Shop> _shops = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int _requestId = 0;
  LocationProvider? _location;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationProvider>();
      if (location.addresses.isEmpty && !location.loading) {
        location.load();
      }
      _loadShops();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = context.read<LocationProvider>();
    if (!identical(_location, location)) {
      _location?.removeListener(_onLocationChanged);
      _location = location;
      location.addListener(_onLocationChanged);
    }
  }

  @override
  void dispose() {
    _location?.removeListener(_onLocationChanged);
    _search.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (!mounted || _location?.loading == true) return;
    _loadShops();
  }

  Future<void> _loadShops() async {
    final location = context.read<LocationProvider>();
    if (location.loading) return;
    final address = location.selected;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = address == null ? '/shops' : '/shops/nearby';
      final data = await _api.get(path, query: {
        if (address != null) 'lat': address.latitude,
        if (address != null) 'lng': address.longitude,
        if (address != null) 'limit': 40,
      }) as List<dynamic>;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _shops = data
            .whereType<Map>()
            .map((item) => Shop.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAddress() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddressesScreen(selectionMode: true)),
    );
    if (mounted) _loadShops();
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final address = location.selected;
    final filtered = _shops.where((shop) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return shop.name.toLowerCase().contains(query) ||
          shop.address.toLowerCase().contains(query) ||
          (shop.shopCategory ?? '').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Shop Choice'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: PageWidth(
          child: RefreshIndicator(
            onRefresh: _loadShops,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _chooseAddress,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me_rounded,
                                  color: AppColors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppText(
                                  address == null
                                      ? 'Set a delivery address to see shops'
                                      : 'Delivering to ${address.label} · ${address.formattedAddress}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.swap_horiz_rounded,
                                  size: 18, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Search a shop, area or category…'),
                          prefixIcon: const Icon(Icons.search_rounded, size: 21),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 19),
                                ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9EC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3E3BC)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.storefront_rounded,
                                  color: AppColors.ink, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    'You choose the shop',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  AppText(
                                    'Your cart stays with this shop. We only show distance and delivery eligibility.',
                                    style: TextStyle(
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
                      if (!_loading && _error == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 2),
                          child: Row(
                            children: [
                              AppText(
                                address == null
                                    ? '${filtered.length} approved shops'
                                    : '${filtered.length} shops can deliver here',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.near_me_outlined,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 3),
                              const AppText(
                                'Nearest first',
                                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const LoadingView(message: 'Finding shops around you…')
                      : _error != null
                          ? ErrorRetry(message: _error!, onRetry: _loadShops)
                          : filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(
                                      height: 430,
                                      child: EmptyState(
                                        icon: Icons.store_mall_directory_outlined,
                                        title: 'No shops found here',
                                        message:
                                            'Try another area, or check back soon as more neighbourhood shops join the bazaar.',
                                      ),
                                    ),
                                  ],
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 40) {
                                      return const SizedBox.shrink();
                                    }
                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                                      itemCount: filtered.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 340,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        mainAxisExtent: 246,
                                      ),
                                      itemBuilder: (context, index) {
                                        final shop = filtered[index];
                                        return ShopCard(
                                          shop: shop,
                                          onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ShopDetailsScreen(shop: shop),
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
      ),
    );
  }
}
