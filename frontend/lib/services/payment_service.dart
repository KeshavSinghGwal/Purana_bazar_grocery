import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/razorpay_checkout.dart';
import '../models/models.dart';
import '../core/localization.dart';

class PaymentCancelledException implements Exception {
  const PaymentCancelledException();
}

class PaymentException implements Exception {
  const PaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PaymentSession {
  const PaymentSession({
    required this.orderId,
    required this.orderNumber,
    required this.gateway,
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amountPaise,
    required this.amount,
    required this.currency,
    required this.mock,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.description,
    this.themeColor,
  });

  final int orderId;
  final String orderNumber;
  final String gateway;
  final String razorpayOrderId;
  final String razorpayKeyId;
  final int amountPaise;
  final double amount;
  final String currency;
  final bool mock;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? description;
  final String? themeColor;

  factory PaymentSession.fromJson(Map<String, dynamic> json) => PaymentSession(
        orderId: (json['orderId'] as num?)?.toInt() ?? 0,
        orderNumber: '${json['orderNumber'] ?? ''}',
        gateway: '${json['gateway'] ?? 'RAZORPAY'}',
        razorpayOrderId: '${json['razorpayOrderId'] ?? ''}',
        razorpayKeyId: '${json['razorpayKeyId'] ?? ''}',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: '${json['currency'] ?? 'INR'}',
        mock: json['mock'] == true,
        customerName: json['customerName'] as String?,
        customerEmail: json['customerEmail'] as String?,
        customerPhone: json['customerPhone'] as String?,
        description: json['description'] as String?,
        themeColor: json['themeColor'] as String?,
      );
}

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final ApiClient _api = ApiClient.instance;

  Future<PaymentSession> createSession(int orderId) async {
    final data = await _api.post('/payments/razorpay/order', body: {
      'orderId': orderId,
    }) as Map<String, dynamic>;
    return PaymentSession.fromJson(data);
  }

  /// Opens Razorpay Checkout, verifies the signature on the server and returns
  /// the updated order. Throws [PaymentCancelledException] if the customer
  /// closes the sheet without paying.
  Future<Order> payForOrder(BuildContext context, Order order) async {
    final session = await createSession(order.id);
    if (session.mock) {
      if (!context.mounted) throw const PaymentCancelledException();
      final confirmed = await _confirmMockPayment(context, session);
      if (confirmed != true) throw const PaymentCancelledException();
      return _verify(
        orderId: session.orderId,
        razorpayOrderId: session.razorpayOrderId,
        razorpayPaymentId:
            'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
        razorpaySignature: 'mock',
      );
    }
    if (!RazorpayCheckout.isSupported) {
      throw const PaymentException(
        'Online payments are available in the Purana Bazaar web app. '
        'Your order is saved — open the web app to complete the payment.',
      );
    }
    final result = await RazorpayCheckout.open(
      RazorpayCheckoutOptions(
        key: session.razorpayKeyId,
        amountPaise: session.amountPaise,
        currency: session.currency,
        orderId: session.razorpayOrderId,
        description: session.description ?? 'Order ${session.orderNumber}',
        prefillName: session.customerName,
        prefillEmail: session.customerEmail,
        prefillContact: session.customerPhone,
        notes: {
          'orderId': '${session.orderId}',
          'orderNumber': session.orderNumber,
        },
        themeColor: session.themeColor ?? '#0c831f',
      ),
    );
    if (result.cancelled) throw const PaymentCancelledException();
    if (!result.paid) {
      throw PaymentException(
        result.error ?? 'The payment could not be completed. Please try again.',
      );
    }
    return _verify(
      orderId: session.orderId,
      razorpayOrderId: result.orderId ?? session.razorpayOrderId,
      razorpayPaymentId: result.paymentId ?? '',
      razorpaySignature: result.signature ?? '',
    );
  }

  Future<Order> _verify({
    required int orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final data = await _api.post('/payments/razorpay/verify', body: {
      'orderId': orderId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    }) as Map<String, dynamic>;
    return Order.fromJson(data);
  }

  Future<bool?> _confirmMockPayment(
    BuildContext context,
    PaymentSession session,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Razorpay test checkout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_outlined, color: AppColors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'Razorpay keys are not configured, so this payment is simulated.',
                      style: TextStyle(fontSize: 11, color: AppColors.darkGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppText(
              'Pay ₹${session.amount.toStringAsFixed(0)} for order ${session.orderNumber}?',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 6),
            const AppText(
              'No money is charged in test mode.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Simulate payment'),
          ),
        ],
      ),
    );
  }
}
