import 'razorpay_checkout_stub.dart'
    if (dart.library.html) 'razorpay_checkout_web.dart' as platform;

/// Everything Razorpay Checkout needs to display the payment sheet.
class RazorpayCheckoutOptions {
  const RazorpayCheckoutOptions({
    required this.key,
    required this.amountPaise,
    required this.currency,
    required this.orderId,
    this.name = 'Purana Bazaar',
    this.description = '',
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
    this.notes = const {},
    this.themeColor = '#0c831f',
  });

  final String key;
  final int amountPaise;
  final String currency;
  final String orderId;
  final String name;
  final String description;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;
  final Map<String, String> notes;
  final String themeColor;
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult._({
    required this.paid,
    required this.cancelled,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
  });

  factory RazorpayCheckoutResult.paid({
    required String paymentId,
    required String orderId,
    required String signature,
  }) =>
      RazorpayCheckoutResult._(
        paid: true,
        cancelled: false,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );

  factory RazorpayCheckoutResult.cancelled() =>
      const RazorpayCheckoutResult._(paid: false, cancelled: true);

  factory RazorpayCheckoutResult.failed(String message) =>
      RazorpayCheckoutResult._(paid: false, cancelled: false, error: message);

  factory RazorpayCheckoutResult.unsupported() => RazorpayCheckoutResult._(
        paid: false,
        cancelled: false,
        error: 'Online payments are available in the Purana Bazaar web app.',
      );

  final bool paid;
  final bool cancelled;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;
}

class RazorpayCheckout {
  RazorpayCheckout._();

  static bool get isSupported => platform.isSupported;

  static Future<RazorpayCheckoutResult> open(RazorpayCheckoutOptions options) =>
      platform.open(options);
}
