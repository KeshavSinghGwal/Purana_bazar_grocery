import 'razorpay_checkout.dart';

bool get isSupported => false;

Future<RazorpayCheckoutResult> open(RazorpayCheckoutOptions options) async =>
    RazorpayCheckoutResult.unsupported();
