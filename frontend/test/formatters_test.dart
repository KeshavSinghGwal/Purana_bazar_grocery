import 'package:flutter_test/flutter_test.dart';
import 'package:purana_bazaar/core/formatters.dart';
import 'package:purana_bazaar/models/models.dart';

void main() {
  test('money keeps whole rupees compact and shows paise when needed', () {
    expect(money(19), '19');
    expect(money(19.5), '19.50');
    expect(rupee(199), '₹199');
    expect(rupee(19.5), '₹19.50');
  });

  test('statusLabel turns enum values into readable labels', () {
    expect(statusLabel('PENDING_APPROVAL'), 'Pending Approval');
    expect(statusLabel('OUT_FOR_DELIVERY'), 'Out For Delivery');
    expect(statusLabel('ACTIVE'), 'Active');
  });

  test('orderItemSummary shows the first item plus a remainder count', () {
    Order order(List<String> names) => Order(
          id: 1,
          orderNumber: 'PB-1',
          shoppingMode: 'PRODUCT_CHOICE',
          orderStatus: 'PENDING',
          paymentStatus: 'PAID',
          paymentMethod: 'COD',
          shop: const Shop(
            id: 1,
            ownerId: 1,
            ownerName: 'Owner',
            name: 'Shop',
            address: 'Address',
            latitude: 0,
            longitude: 0,
            openingTime: '06:00:00',
            closingTime: '23:59:00',
            deliveryRadius: 5,
            deliveryAvailable: true,
            estimatedDeliveryMinutes: 20,
            approvalStatus: 'APPROVED',
            operationalStatus: 'ACTIVE',
            deliverable: true,
            openNow: true,
            reviewCount: 0,
          ),
          customerName: 'Customer',
          deliveryAddress: 'Address',
          deliveryLatitude: 0,
          deliveryLongitude: 0,
          subtotal: 100,
          deliveryCharge: 0,
          totalAmount: 100,
          items: [
            for (var index = 0; index < names.length; index++)
              OrderItem(
                id: index,
                productId: index,
                productName: names[index],
                unit: '1 kg',
                price: 100,
                quantity: 1,
                totalPrice: 100,
              ),
          ],
          canCancel: true,
        );

    expect(orderItemSummary(order([])), 'No items');
    expect(orderItemSummary(order(['Milk'])), 'Milk');
    expect(orderItemSummary(order(['Milk', 'Rice', 'Atta'])), 'Milk + 2 more');
  });

  test('initials handles single and multiple names', () {
    expect(initials('Aarav Mehta'), 'AM');
    expect(initials('Meera'), 'M');
    expect(initials('  '), 'PB');
  });

  test('friendlyTime formats backend LocalTime values', () {
    expect(friendlyTime('06:00:00'), '6:00 AM');
    expect(friendlyTime('18:45:00'), '6:45 PM');
    expect(friendlyTime('noon'), 'noon');
  });
}
