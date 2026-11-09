import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  CartProvider(this._api);

  final ApiClient _api;

  Cart _cart = Cart.empty;
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  Cart get cart => _cart;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final data = await _api.get('/cart') as Map<String, dynamic>;
      _cart = Cart.fromJson(data);
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addProductChoice(int productId, {int quantity = 1}) async {
    await _mutate(() => _api.post('/cart/items', body: {
          'shoppingMode': 'PRODUCT_CHOICE',
          'productId': productId,
          'quantity': quantity,
        }));
  }

  Future<void> addShopChoice(int shopInventoryId, {int quantity = 1}) async {
    await _mutate(() => _api.post('/cart/items', body: {
          'shoppingMode': 'SHOP_CHOICE',
          'shopInventoryId': shopInventoryId,
          'quantity': quantity,
        }));
  }

  Future<void> updateQuantity(int itemId, int quantity) async {
    await _mutate(() => _api.put('/cart/items/$itemId',
        body: {'quantity': quantity}));
  }

  Future<void> removeItem(int itemId) async {
    await _mutate(() => _api.delete('/cart/items/$itemId'));
  }

  Future<void> clear() async {
    await _mutate(() => _api.delete('/cart'));
  }

  Future<void> _mutate(Future<dynamic> Function() request) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      final data = await request() as Map<String, dynamic>;
      _cart = Cart.fromJson(data);
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    _cart = Cart.empty;
    _error = null;
    notifyListeners();
  }
}
