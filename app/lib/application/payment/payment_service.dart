import 'dart:async';
import 'dart:developer' show log;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../domain/entities/order.dart';

/// Result of initiating a Razorpay payment flow.
sealed class PaymentResult {
  const PaymentResult();
}

class PaymentSuccess extends PaymentResult {
  final String razorpayPaymentId;
  const PaymentSuccess(this.razorpayPaymentId);
}

class PaymentFailure extends PaymentResult {
  final String message;
  const PaymentFailure(this.message);
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}

/// Coordinates Razorpay checkout with backend-created orders and verification.
class PaymentService {
  final FirebaseFunctions _functions;
  final Razorpay _razorpay;

  PaymentService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance,
      _razorpay = Razorpay();

  /// Starts the Razorpay checkout for [order] and returns the outcome.
  ///
  /// Throws if the order is not approved or already paid.
  Future<PaymentResult> pay(BuildContext context, Order order) async {
    if (order.status != OrderStatus.approved) {
      return const PaymentFailure(
        'Payment is only allowed after shop approval.',
      );
    }
    if (order.isPaid) {
      return const PaymentFailure('This order is already paid.');
    }

    try {
      final createFn = _functions.httpsCallable('createRazorpayOrder');
      final response = await createFn.call<Map<String, dynamic>>({
        'orderId': order.id,
      });
      final data = response.data;

      final keyId = data['keyId'] as String?;
      final razorpayOrderId = data['razorpayOrderId'] as String?;
      final amount = data['amount'] as int?;
      final currency = data['currency'] as String? ?? 'INR';

      if (keyId == null || razorpayOrderId == null || amount == null) {
        return const PaymentFailure('Payment setup failed. Please try again.');
      }

      final completer = Completer<PaymentResult>();

      void onSuccess(PaymentSuccessResponse response) async {
        final paymentId = response.paymentId;
        final signature = response.signature;
        final returnedOrderId = response.orderId;

        // Even a "success" callback is not trusted directly. If any field is
        // missing, fall back to server-side reconciliation rather than failing
        // outright, in case money was actually captured.
        if (paymentId == null || signature == null || returnedOrderId == null) {
          completer.complete(await _reconcile(order.id));
          return;
        }

        final verifyResult = await _verify(
          orderId: order.id,
          razorpayOrderId: returnedOrderId,
          razorpayPaymentId: paymentId,
          signature: signature,
        );

        completer.complete(verifyResult);
      }

      void onError(PaymentFailureResponse response) async {
        final message = response.message ?? 'Payment failed. Please try again.';
        log('Razorpay error: ${response.code} - $message');
        // A failure/cancel event from the app is NOT authoritative: the payment
        // app may still have debited the customer. Ask the server to reconcile
        // against Razorpay before reporting failure.
        final reconciled = await _reconcile(order.id);
        if (reconciled is PaymentSuccess) {
          completer.complete(reconciled);
        } else {
          completer.complete(PaymentFailure(message));
        }
      }

      void onExternalWallet(ExternalWalletResponse response) {
        log('External wallet selected: ${response.walletName}');
      }

      _razorpay
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, onError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);

      _razorpay.open({
        'key': keyId,
        'amount': amount,
        'currency': currency,
        'order_id': razorpayOrderId,
        'name': 'Tirupati Traders',
        'description': 'Order #${order.id}',
        'method': {
          'upi': true,
          'wallet': true,
          'card': false,
          'netbanking': false,
          'emi': false,
          'paylater': false,
        },
        'prefill': {'contact': order.customerPhone ?? ''},
        'theme': {'color': '#F57C00'},
      });

      return await completer.future;
    } on FirebaseFunctionsException catch (e) {
      log('Cloud function error: ${e.code} - ${e.message}');
      return PaymentFailure(e.message ?? 'Payment setup failed.');
    } catch (e) {
      log('Unexpected payment error: $e');
      return const PaymentFailure('Something went wrong. Please try again.');
    }
  }

  Future<PaymentResult> _verify({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    try {
      final verifyFn = _functions.httpsCallable('verifyPayment');
      await verifyFn.call<Map<String, dynamic>>({
        'orderId': orderId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'signature': signature,
      });
      return PaymentSuccess(razorpayPaymentId);
    } on FirebaseFunctionsException catch (e) {
      log('Payment verification error: ${e.code} - ${e.message}');
      // Verification rejected the payment. Do a final reconciliation to be
      // certain we are not failing a genuinely captured payment.
      final reconciled = await _reconcile(orderId);
      if (reconciled is PaymentSuccess) return reconciled;
      return PaymentFailure(e.message ?? 'Payment verification failed.');
    } catch (e) {
      log('Unexpected verification error: $e');
      final reconciled = await _reconcile(orderId);
      if (reconciled is PaymentSuccess) return reconciled;
      return const PaymentFailure('Payment verification failed.');
    }
  }

  /// Asks the backend to reconcile the order directly against Razorpay. This is
  /// the authoritative check: the order is only marked paid if Razorpay reports
  /// a captured payment for the exact amount. Returns [PaymentSuccess] only when
  /// money has genuinely been captured.
  Future<PaymentResult> _reconcile(String orderId) async {
    try {
      final reconcileFn = _functions.httpsCallable('reconcileOrderPayment');
      final response = await reconcileFn.call<Map<String, dynamic>>({
        'orderId': orderId,
      });
      final data = response.data;
      final paid = data['paid'] == true;
      if (paid) {
        final paymentId = data['razorpayPaymentId'] as String? ?? '';
        return PaymentSuccess(paymentId);
      }
      return const PaymentFailure(
        'Payment was not completed. You have not been charged.',
      );
    } on FirebaseFunctionsException catch (e) {
      log('Reconciliation error: ${e.code} - ${e.message}');
      return const PaymentFailure(
        'Could not confirm payment. If money was debited, it will be '
        'auto-refunded or reflected shortly. Please check "Orders".',
      );
    } catch (e) {
      log('Unexpected reconciliation error: $e');
      return const PaymentFailure(
        'Could not confirm payment. Please check "Orders" in a few minutes.',
      );
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService();
  ref.onDispose(service.dispose);
  return service;
});
