import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/razorpay_checkout.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../state/cart_provider.dart';
import '../../state/location_provider.dart';
import '../../widgets/common.dart';
import '../location/addresses_screen.dart';
import '../orders/order_details_screen.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ApiClient _api = ApiClient.instance;
  final TextEditingController _note = TextEditingController();
  final String _idempotencyKey =
      'PB-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecond}';
  ShopQuote? _quote;
  bool _validating = true;
  bool _placing = false;
  String _paymentMethod = 'COD';
  String? _error;
  String? _lastAddressId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final location = context.read<LocationProvider>();
      if (location.addresses.isEmpty && !location.loading) {
        try {
          await location.load();
        } catch (_) {
          // _validate below surfaces any remaining problem to the user.
        }
      }
      if (mounted) await _validate();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final location = context.read<LocationProvider>();
    final address = location.selected;
    _lastAddressId = address == null ? null : '$address.id';
    if (address == null) {
      setState(() {
        _validating = false;
        _quote = null;
        _error = 'Add a delivery address to check shop eligibility.';
      });
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      final data = await _api.post('/marketplace/checkout/validate', body: {
        'addressId': address.id,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _quote = ShopQuote.fromJson(data));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _error = 'Could not validate your cart right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _chooseAddress() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddressesScreen(selectionMode: true)),
    );
    if (!mounted) return;
    final currentId = context.read<LocationProvider>().selected?.id.toString();
    if (currentId != _lastAddressId) await _validate();
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    final address = context.read<LocationProvider>().selected;
    final quote = _quote;
    if (address == null) {
      showMessage(context, 'Choose a delivery address first.', error: true);
      return;
    }
    if (quote == null || !quote.found) {
      showMessage(context, 'No eligible shop can fulfil your cart.', error: true);
      return;
    }
    setState(() => _placing = true);
    final cart = context.read<CartProvider>();
    try {
      final data = await _api.post('/orders', body: {
        'addressId': address.id,
        'paymentMethod': _paymentMethod,
        'idempotencyKey': _idempotencyKey,
        'customerNote': _note.text.trim().isEmpty ? null : _note.text.trim(),
      }) as Map<String, dynamic>;
      final order = Order.fromJson(data);
      await cart.load(silent: true);
      if (!mounted) return;

      if (_paymentMethod == 'ONLINE') {
        await _payOnline(order);
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: order)),
        (route) => route.isFirst,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.message, error: true);
      await _validate();
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _payOnline(Order order) async {
    try {
      final paid = await PaymentService.instance.payForOrder(context, order);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: paid)),
        (route) => route.isFirst,
      );
    } on PaymentCancelledException {
      if (!mounted) return;
      showMessage(
        context,
        'Payment cancelled. Your order is saved — you can pay from Orders.',
        error: true,
      );
      _openSavedOrder(order);
    } on PaymentException catch (error) {
      if (!mounted) return;
      showMessage(context, error.message, error: true);
      _openSavedOrder(order);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.message, error: true);
      _openSavedOrder(order);
    }
  }

  void _openSavedOrder(Order order) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>().cart;
    final address = context.watch<LocationProvider>().selected;
    final quote = _quote;
    final canPlace = quote?.found == true && address != null && !_placing && !_validating;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 820,
          child: cart.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Nothing to check out',
                  message: 'Your cart is empty. Add some products before placing an order.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                  children: [
                    _addressCard(address),
                    const SizedBox(height: 12),
                    if (_validating)
                      const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 26),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Validating shop selection, stock and delivery radius…',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_error != null)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        color: AppColors.red.withValues(alpha: 0.05),
                        borderColor: AppColors.red.withValues(alpha: 0.18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.red, size: 21),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.red),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: address == null ? _chooseAddress : _validate,
                              icon: Icon(
                                address == null
                                    ? Icons.add_location_alt_outlined
                                    : Icons.refresh_rounded,
                                size: 17,
                              ),
                              label: Text(address == null
                                  ? 'Add delivery address'
                                  : 'Validate again'),
                            ),
                          ],
                        ),
                      )
                    else if (quote != null)
                      _quoteSection(quote),
                    const SizedBox(height: 12),
                    _paymentSection(),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery instructions',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _note,
                            maxLines: 2,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Ring the bell, leave at the door…',
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (quote != null) ...[
                      const SizedBox(height: 12),
                      _billCard(quote, address),
                    ],
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.muted),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Prices, stock and the selected shop are revalidated on the server when you place the order.',
                            style: TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _placing
                            ? null
                            : canPlace
                                ? _placeOrder
                                : address == null
                                    ? _chooseAddress
                                    : _validating
                                        ? null
                                        : _validate,
                        child: _placing
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                quote?.found == true
                                    ? _paymentMethod == 'ONLINE'
                                        ? 'Pay ${rupee(quote!.totalAmount)} securely'
                                        : 'Place COD order · ${rupee(quote!.totalAmount)}'
                                    : address == null
                                        ? 'Add a delivery address to continue'
                                        : _validating
                                            ? 'Checking nearby shops…'
                                            : 'Retry shop validation',
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _addressCard(Address? address) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.green, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVER TO',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address == null
                      ? 'No delivery address selected'
                      : '${address.label} · ${address.formattedAddress}',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _chooseAddress,
            child: Text(address == null ? 'Add' : 'Change'),
          ),
        ],
      ),
    );
  }

  Widget _quoteSection(ShopQuote quote) {
    if (!quote.found) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        color: AppColors.red.withValues(alpha: 0.05),
        borderColor: AppColors.red.withValues(alpha: 0.18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search_off_rounded, color: AppColors.red, size: 22),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    quote.message ?? 'No nearby shop can fulfil the complete cart.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (quote.unavailableProducts.isNotEmpty) ...[
              const SizedBox(height: 11),
              ...quote.unavailableProducts.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '• ${item.name}: requested ${item.requestedQuantity}, max ${item.maxAvailable}',
                    style: const TextStyle(fontSize: 11, color: AppColors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _validate,
              child: const Text('Check again'),
            ),
          ],
        ),
      );
    }

    final shop = quote.selectedShop!;
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(15),
          color: AppColors.paleMint,
          borderColor: AppColors.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: AppColors.green, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shop.name,
                      style: const TextStyle(
                        fontSize: 15,
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
              Text(
                quote.selectedShop != null
                    ? '${shop.address} · ${shop.estimatedDeliveryMinutes} min'
                    : '',
                style: const TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 15),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      quote.message ??
                          'This shop can fulfil your complete cart without splitting the order.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items being fulfilled',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 9),
              ...quote.items.map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.name} × ${line.requestedQuantity}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentSection() {
    final onlineSupported = RazorpayCheckout.isSupported;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment method', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          _paymentTile(
            value: 'COD',
            icon: Icons.payments_outlined,
            title: 'Cash on Delivery',
            subtitle: 'Pay the delivery partner when your order arrives.',
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: onlineSupported ? 1 : 0.55,
            child: _paymentTile(
              value: 'ONLINE',
              icon: Icons.credit_card_rounded,
              title: 'Pay online',
              subtitle: onlineSupported
                  ? 'UPI, cards, netbanking and wallets · secured by Razorpay'
                  : 'Online payments are available in the Purana Bazaar web app.',
              enabled: onlineSupported,
            ),
          ),
          if (onlineSupported && _paymentMethod == 'ONLINE') ...[
            const SizedBox(height: 9),
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.muted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Razorpay securely processes the payment. Purana Bazaar never stores your card details.',
                    style: TextStyle(fontSize: 10, height: 1.4, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: enabled ? () => setState(() => _paymentMethod = value) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.green : AppColors.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.green : AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(ShopQuote quote, Address? address) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InfoRow(label: 'Item subtotal', value: rupee(quote.subtotal)),
          InfoRow(
            label: 'Delivery charge',
            value: quote.deliveryCharge == 0 ? 'FREE' : rupee(quote.deliveryCharge),
            valueColor: quote.deliveryCharge == 0 ? AppColors.green : null,
          ),
          const Divider(height: 20),
          InfoRow(
            label: _paymentMethod == 'ONLINE' ? 'To pay online' : 'To pay (COD)',
            value: rupee(quote.totalAmount),
            bold: true,
          ),
          if (address != null) ...[
            const SizedBox(height: 8),
            Text(
              'Delivering to ${address.formattedAddress}',
              style: const TextStyle(fontSize: 10, height: 1.4, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
