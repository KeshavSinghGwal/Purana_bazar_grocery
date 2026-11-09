import 'package:flutter_test/flutter_test.dart';
import 'package:purana_bazaar/models/models.dart';

void main() {
  group('User model', () {
    test('parses a customer account', () {
      final user = User.fromJson({
        'id': 7,
        'name': 'Aarav Mehta',
        'email': 'aarav@example.com',
        'phone': '9876543210',
        'role': 'CUSTOMER',
        'active': true,
        'createdAt': '2026-01-15T10:30:00Z',
      });

      expect(user.id, 7);
      expect(user.name, 'Aarav Mehta');
      expect(user.phone, '9876543210');
      expect(user.isCustomer, isTrue);
      expect(user.isOwner, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.active, isTrue);
      expect(user.createdAt, isNotNull);
    });

    test('defaults a missing role to customer', () {
      final user = User.fromJson({'id': 1, 'name': 'Test', 'email': 't@e.com'});
      expect(user.role, 'CUSTOMER');
      expect(user.active, isTrue);
    });
  });

  group('Product model', () {
    test('is available when priced, stocked and sold by a shop', () {
      final product = Product.fromJson({
        'id': 3,
        'name': 'Basmati Rice 5kg',
        'categoryId': 1,
        'categoryName': 'Staples',
        'unit': '5 kg',
        'active': true,
        'bestPrice': 499.5,
        'availableShops': 2,
        'totalStock': 14,
      });

      expect(product.bestPrice, 499.5);
      expect(product.available, isTrue);
    });

    test('is unavailable without a price or stock', () {
      final product = Product.fromJson({
        'id': 4,
        'name': 'Out of stock item',
        'categoryId': 1,
        'categoryName': 'Staples',
        'unit': '1 kg',
        'availableShops': 0,
        'totalStock': 0,
      });

      expect(product.available, isFalse);
    });
  });

  group('ShopQuote model', () {
    test('parses a successful nearest-shop quote', () {
      final quote = ShopQuote.fromJson({
        'found': true,
        'distanceKm': 1.4,
        'selectedShop': {
          'id': 2,
          'ownerId': 9,
          'ownerName': 'Ravi Gupta',
          'name': 'Gupta General Store',
          'address': 'Market Road',
          'latitude': 28.61,
          'longitude': 77.20,
          'deliveryRadius': 5,
          'approvalStatus': 'APPROVED',
          'operationalStatus': 'ACTIVE',
          'openNow': true,
          'deliverable': true,
          'reviewCount': 3,
        },
        'items': [
          {
            'productId': 3,
            'name': 'Basmati Rice 5kg',
            'unit': '5 kg',
            'requestedQuantity': 2,
            'availableQuantity': 8,
            'unitPrice': 499.5,
            'lineTotal': 999,
          }
        ],
        'subtotal': 999,
        'deliveryCharge': 0,
        'totalAmount': 999,
        'unavailableProducts': [],
        'consideredShops': [
          {
            'id': 1,
            'name': 'Sharma Kirana',
            'distanceKm': 0.9,
            'eligible': false,
            'reason': 'Missing 1 product',
          }
        ],
      });

      expect(quote.found, isTrue);
      expect(quote.selectedShop?.name, 'Gupta General Store');
      expect(quote.items.single.lineTotal, 999);
      expect(quote.deliveryCharge, 0);
      expect(quote.consideredShops.single.eligible, isFalse);
      expect(quote.unavailableProducts, isEmpty);
    });

    test('parses unavailable product details when no shop can fulfil', () {
      final quote = ShopQuote.fromJson({
        'found': false,
        'message': 'No nearby shop has the full cart.',
        'items': [],
        'subtotal': 0,
        'deliveryCharge': 0,
        'totalAmount': 0,
        'unavailableProducts': [
          {
            'productId': 3,
            'name': 'Basmati Rice 5kg',
            'requestedQuantity': 2,
            'maxAvailable': 1,
          }
        ],
        'consideredShops': [],
      });

      expect(quote.found, isFalse);
      expect(quote.message, contains('No nearby shop'));
      expect(quote.unavailableProducts.single.maxAvailable, 1);
    });
  });

  group('Cart and Order models', () {
    test('parses Shop Choice cart items with inventory references', () {
      final cart = Cart.fromJson({
        'id': 11,
        'shoppingMode': 'SHOP_CHOICE',
        'selectedShop': {
          'id': 5,
          'ownerId': 2,
          'ownerName': 'Owner',
          'name': 'Corner Store',
          'address': 'Lane 4',
          'latitude': 28.6,
          'longitude': 77.2,
          'deliveryRadius': 4,
          'approvalStatus': 'APPROVED',
          'operationalStatus': 'ACTIVE',
          'reviewCount': 0,
        },
        'items': [
          {
            'id': 21,
            'productId': 8,
            'shopInventoryId': 33,
            'shopId': 5,
            'name': 'Milk',
            'unit': '500 ml',
            'quantity': 2,
            'unitPrice': 28,
            'lineTotal': 56,
            'availableQuantity': 10,
            'available': true,
            'categoryId': 2,
            'categoryName': 'Dairy',
          }
        ],
        'itemCount': 2,
        'subtotal': 56,
        'estimatedDeliveryCharge': 19,
        'estimatedTotal': 75,
        'hasAvailabilityIssues': false,
      });

      expect(cart.isShopChoice, isTrue);
      expect(cart.items.single.shopInventoryId, 33);
      expect(cart.items.single.quantity, 2);
      expect(cart.estimatedTotal, 75);
    });

    test('parses order lifecycle and item snapshots', () {
      final order = Order.fromJson({
        'id': 44,
        'orderNumber': 'PB-100044',
        'shoppingMode': 'PRODUCT_CHOICE',
        'orderStatus': 'OUT_FOR_DELIVERY',
        'paymentStatus': 'PAID',
        'paymentMethod': 'COD',
        'shop': {
          'id': 2,
          'ownerId': 9,
          'ownerName': 'Ravi Gupta',
          'name': 'Gupta General Store',
          'address': 'Market Road',
          'latitude': 28.61,
          'longitude': 77.20,
          'deliveryRadius': 5,
          'approvalStatus': 'APPROVED',
          'operationalStatus': 'ACTIVE',
          'reviewCount': 0,
        },
        'customerName': 'Aarav Mehta',
        'customerPhone': '9876543210',
        'deliveryAddress': '12 Green Park',
        'deliveryLatitude': 28.6,
        'deliveryLongitude': 77.2,
        'subtotal': 999,
        'deliveryCharge': 0,
        'totalAmount': 999,
        'items': [
          {
            'id': 1,
            'productId': 3,
            'productName': 'Basmati Rice 5kg',
            'unit': '5 kg',
            'price': 499.5,
            'quantity': 2,
            'totalPrice': 999,
          }
        ],
        'canCancel': false,
        'createdAt': '2026-02-01T09:15:00Z',
      });

      expect(order.orderNumber, 'PB-100044');
      expect(order.orderStatus, 'OUT_FOR_DELIVERY');
      expect(order.items.single.productName, 'Basmati Rice 5kg');
      expect(order.isDelivered, isFalse);
      expect(order.canCancel, isFalse);
      expect(order.totalAmount, 999);
    });
  });

  group('Admin models', () {
    test('parses dashboard counters', () {
      final dashboard = AdminDashboard.fromJson({
        'totalShops': 6,
        'approvedShops': 4,
        'pendingShops': 1,
        'suspendedShops': 1,
        'totalCustomers': 12,
        'activeCustomers': 11,
        'totalProducts': 25,
        'totalCategories': 6,
        'totalOrders': 31,
        'pendingOrders': 2,
        'completedOrders': 24,
        'cancelledOrders': 5,
        'totalSales': 28450.5,
      });

      expect(dashboard.totalShops, 6);
      expect(dashboard.pendingShops, 1);
      expect(dashboard.totalSales, 28450.5);
    });

    test('parses admin customer rows', () {
      final customer = AdminCustomer.fromJson({
        'id': 3,
        'name': 'Meera Shah',
        'email': 'meera@example.com',
        'phone': '9988776655',
        'active': false,
        'orderCount': 4,
      });

      expect(customer.name, 'Meera Shah');
      expect(customer.active, isFalse);
      expect(customer.orderCount, 4);
    });
  });
}
