import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class DeliveryProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  DeliveryDashboard? _dashboard;
  List<Order> _available = const [];
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;
  int? _busyOrderId;

  DeliveryDashboard? get dashboard => _dashboard;
  List<Order> get available => _available;
  List<Order> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;
  int? get busyOrderId => _busyOrderId;
  bool get hasData => _dashboard != null;

  Future<void> load({bool silent = false}) async {
    if (!silent || _dashboard == null) {
      _loading = true;
    }
    _error = null;
    if (!silent) notifyListeners();
    try {
      final results = await Future.wait([
        _api.get('/delivery/dashboard'),
        _api.get('/delivery/available'),
        _api.get('/delivery/orders'),
      ]);
      _dashboard = DeliveryDashboard.fromJson(results[0] as Map<String, dynamic>);
      _available = _ordersFrom(results[1]);
      _orders = _ordersFrom(results[2]);
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> accept(Order order) async {
    _busyOrderId = order.id;
    notifyListeners();
    try {
      await _api.put('/delivery/orders/${order.id}/accept');
      await load(silent: true);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  Future<String?> advance(Order order) async {
    final next = _nextStatus(order.orderStatus);
    if (next == null) return 'No further updates are available for this delivery.';
    _busyOrderId = order.id;
    notifyListeners();
    try {
      await _api.put('/delivery/orders/${order.id}/status', body: {'status': next});
      await load(silent: true);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  static String? _nextStatus(String current) {
    switch (current) {
      case 'READY_FOR_PICKUP':
        return 'OUT_FOR_DELIVERY';
      case 'OUT_FOR_DELIVERY':
        return 'DELIVERED';
      default:
        return null;
    }
  }

  static List<Order> _ordersFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Order.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
