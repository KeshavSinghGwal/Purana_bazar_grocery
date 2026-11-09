import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/models.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocationProvider extends ChangeNotifier {
  LocationProvider(this._api);

  final ApiClient _api;

  List<Address> _addresses = const [];
  Address? _selected;
  bool _loading = false;
  String? _error;

  List<Address> get addresses => _addresses;
  Address? get selected => _selected;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasLocation => _selected != null;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final data = await _api.get('/customers/addresses') as List<dynamic>;
      _addresses = data
          .whereType<Map>()
          .map((item) => Address.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (_addresses.isEmpty) {
        _selected = null;
      } else {
        final selectedId = _selected?.id;
        _selected = _addresses.where((address) => address.id == selectedId).firstOrNull ??
            _addresses.where((address) => address.isDefault).firstOrNull ??
            _addresses.first;
      }
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void select(Address address) {
    _selected = address;
    notifyListeners();
  }

  Future<Address> createAddress(Map<String, dynamic> body) async {
    final data = await _api.post('/customers/addresses', body: body)
        as Map<String, dynamic>;
    final address = Address.fromJson(data);
    await load(silent: true);
    _selected = _addresses.where((item) => item.id == address.id).firstOrNull ??
        address;
    notifyListeners();
    return address;
  }

  Future<Address> updateAddress(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/customers/addresses/$id', body: body)
        as Map<String, dynamic>;
    final address = Address.fromJson(data);
    await load(silent: true);
    return address;
  }

  Future<void> makeDefault(int id) async {
    final data = await _api.put('/customers/addresses/$id/default')
        as Map<String, dynamic>;
    final address = Address.fromJson(data);
    await load(silent: true);
    _selected = _addresses.where((item) => item.id == address.id).firstOrNull ??
        address;
    notifyListeners();
  }

  Future<void> deleteAddress(int id) async {
    await _api.delete('/customers/addresses/$id');
    if (_selected?.id == id) _selected = null;
    await load(silent: true);
  }

  void clear() {
    _addresses = const [];
    _selected = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
