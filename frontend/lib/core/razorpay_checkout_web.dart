import 'dart:js_interop';

import 'razorpay_checkout.dart';

@JS('pbStartRazorpay')
external JSPromise<JSObject> _startRazorpay(JSObject options);

bool get isSupported => true;

Future<RazorpayCheckoutResult> open(RazorpayCheckoutOptions options) async {
  try {
    final jsOptions = <String, Object?>{
      'key': options.key,
      'amount': options.amountPaise,
      'currency': options.currency,
      'name': options.name,
      'description': options.description,
      'order_id': options.orderId,
      'prefill': <String, Object?>{
        'name': options.prefillName ?? '',
        'email': options.prefillEmail ?? '',
        'contact': options.prefillContact ?? '',
      },
      'notes': options.notes,
      'theme': <String, Object?>{'color': options.themeColor},
    }.jsify() as JSObject;

    final raw = await _startRazorpay(jsOptions).toDart;
    final decoded = raw.dartify();
    if (decoded is! Map) {
      return RazorpayCheckoutResult.failed(
        'Razorpay returned an unexpected response. Please try again.',
      );
    }
    if (decoded['ok'] == true) {
      return RazorpayCheckoutResult.paid(
        paymentId: '${decoded['razorpay_payment_id'] ?? ''}',
        orderId: '${decoded['razorpay_order_id'] ?? ''}',
        signature: '${decoded['razorpay_signature'] ?? ''}',
      );
    }
    if (decoded['cancelled'] == true) {
      return RazorpayCheckoutResult.cancelled();
    }
    return RazorpayCheckoutResult.failed(
      '${decoded['error'] ?? 'The payment could not be completed.'}',
    );
  } catch (error) {
    return RazorpayCheckoutResult.failed(
      'Could not open Razorpay Checkout. $error',
    );
  }
}
