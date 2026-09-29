import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString, defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import Razorpay from "razorpay";
import crypto from "crypto";

initializeApp();
const db = getFirestore();

const razorpayKeyId = defineString("RAZORPAY_KEY_ID", {
  description: "Razorpay API Key ID",
});

const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

function getRazorpayInstance() {
  const keyId = razorpayKeyId.value();
  const keySecret = razorpayKeySecret.value();

  if (!keyId || !keySecret) {
    throw new HttpsError(
      "failed-precondition",
      "Razorpay keys are not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET secrets.",
    );
  }

  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

interface CartItemData {
  product: {
    price: number;
    isLoose?: boolean;
    stepInGrams?: number;
  };
  quantity: number;
  unitPriceOverride?: number;
}

function computeOrderTotal(orderData: Record<string, unknown>): number {
  const items = (orderData.items ?? []) as CartItemData[];
  return items.reduce((sum, item) => {
    const unitPrice = item.unitPriceOverride ?? item.product.price;
    if (item.product.isLoose) {
      const step = item.product.stepInGrams ?? 250;
      return sum + (unitPrice * item.quantity * step) / 1000;
    }
    return sum + unitPrice * item.quantity;
  }, 0);
}

/**
 * Creates a Razorpay order for an approved Tirupati Traders order.
 * Called by the customer app when tapping "Pay via UPI".
 */
export const createRazorpayOrder = onCall(
  { secrets: [razorpayKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to make a payment.",
      );
    }

    const { orderId } = request.data as { orderId?: string };
    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const orderData = orderDoc.data()!;

    if (orderData.status !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        "Payment is only allowed after the shop approves the order.",
      );
    }

    if (orderData.isPaid === true) {
      throw new HttpsError(
        "failed-precondition",
        "This order is already paid.",
      );
    }

    const storedTotal =
      typeof orderData.totalAmount === "number" ? orderData.totalAmount : null;
    const totalAmount = storedTotal ?? computeOrderTotal(orderData);
    const amountPaise = Math.round(totalAmount * 100);
    if (amountPaise <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Order amount must be greater than zero.",
      );
    }

    const receipt = `${orderId}_${Date.now()}`;

    try {
      const razorpay = getRazorpayInstance();
      const razorpayOrder = await razorpay.orders.create({
        amount: amountPaise,
        currency: "INR",
        receipt,
        notes: {
          tirupatiOrderId: orderId,
          customerPhone: orderData.customerPhone ?? "",
        },
      });

      // Persist the Razorpay order id so verification can reconcile it.
      await orderDoc.ref.update({ razorpayOrderId: razorpayOrder.id });

      return {
        keyId: razorpayKeyId.value(),
        razorpayOrderId: razorpayOrder.id,
        amount: amountPaise,
        currency: "INR",
        orderId,
      };
    } catch (error) {
      logger.error("Failed to create Razorpay order", { orderId, error });
      throw new HttpsError(
        "internal",
        "Could not create payment order. Please try again.",
      );
    }
  },
);

/**
 * Verifies a Razorpay payment signature and marks the Firestore order as paid.
 * Called by the customer app after the Razorpay checkout succeeds.
 */
export const verifyPayment = onCall(
  { secrets: [razorpayKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to verify a payment.",
      );
    }

    const { orderId, razorpayPaymentId, razorpayOrderId, signature } =
      request.data as {
        orderId?: string;
        razorpayPaymentId?: string;
        razorpayOrderId?: string;
        signature?: string;
      };

    if (!orderId || !razorpayPaymentId || !razorpayOrderId || !signature) {
      throw new HttpsError(
        "invalid-argument",
        "orderId, razorpayPaymentId, razorpayOrderId and signature are required.",
      );
    }

    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const orderData = orderDoc.data()!;

    if (orderData.isPaid === true) {
      return { success: true, alreadyPaid: true };
    }

    // Reconcile Razorpay order id to prevent tampering with the client payload.
    if (
      orderData.razorpayOrderId &&
      orderData.razorpayOrderId !== razorpayOrderId
    ) {
      throw new HttpsError("permission-denied", "Payment order mismatch.");
    }

    const keySecret = razorpayKeySecret.value();
    if (!keySecret) {
      throw new HttpsError(
        "failed-precondition",
        "Razorpay secret is not configured.",
      );
    }
    const payload = `${razorpayOrderId}|${razorpayPaymentId}`;
    const expectedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(payload)
      .digest("hex");

    const isAuthentic = crypto.timingSafeEqual(
      Buffer.from(expectedSignature, "hex"),
      Buffer.from(signature, "hex"),
    );

    if (!isAuthentic) {
      logger.warn("Invalid Razorpay signature", { orderId, razorpayOrderId });
      throw new HttpsError("permission-denied", "Payment verification failed.");
    }

    // A valid signature only proves the response was not tampered with. It does
    // NOT prove money was actually captured. Independently confirm the payment
    // status, amount and order with Razorpay before marking the order paid.
    const expectedPaise = expectedAmountPaise(orderData);
    const captured = await confirmCapturedPayment(
      razorpayPaymentId,
      razorpayOrderId,
      expectedPaise,
      orderId,
    );

    if (!captured) {
      throw new HttpsError(
        "failed-precondition",
        "Payment was not completed. No money has been captured.",
      );
    }

    try {
      await orderDoc.ref.update({
        isPaid: true,
        paymentMethod: "upi",
        razorpayPaymentId,
        razorpayOrderId,
      });
      await recordTransaction(
        orderData,
        orderId,
        razorpayPaymentId,
        razorpayOrderId,
        expectedPaise,
      );

      return { success: true, alreadyPaid: false };
    } catch (error) {
      logger.error("Failed to update order after verified payment", {
        orderId,
        error,
      });
      throw new HttpsError(
        "internal",
        "Payment verified but order update failed.",
      );
    }
  },
);

/** Expected order amount in paise, using the stored total or computed items. */
function expectedAmountPaise(orderData: Record<string, unknown>): number {
  const storedTotal =
    typeof orderData.totalAmount === "number" ? orderData.totalAmount : null;
  const total = storedTotal ?? computeOrderTotal(orderData);
  return Math.round(total * 100);
}

/**
 * Writes an audit record of a confirmed payment to the "transactions"
 * collection. Keyed by the Razorpay payment id so verify + reconcile never
 * create duplicates. Failures are logged but do not block marking the order
 * paid, since the order document remains the source of truth for fulfilment.
 */
async function recordTransaction(
  orderData: Record<string, unknown>,
  orderId: string,
  razorpayPaymentId: string,
  razorpayOrderId: string,
  amountPaise: number,
): Promise<void> {
  try {
    await db
      .collection("transactions")
      .doc(razorpayPaymentId)
      .set(
        {
          orderId,
          customerId: orderData.customerId ?? null,
          customerName: orderData.customerName ?? "Customer",
          customerPhone: orderData.customerPhone ?? null,
          amount: amountPaise,
          method: "upi",
          status: "captured",
          razorpayPaymentId,
          razorpayOrderId,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  } catch (error) {
    logger.error("Failed to record transaction", { orderId, error });
  }
}

/**
 * Fetches a single payment from Razorpay and confirms it truly succeeded for
 * the given order and amount. Captures it if it is only authorized. Returns
 * true only when the payment is in the "captured" state for the exact amount.
 */
async function confirmCapturedPayment(
  razorpayPaymentId: string,
  razorpayOrderId: string,
  expectedPaise: number,
  orderId: string,
): Promise<boolean> {
  const razorpay = getRazorpayInstance();

  let payment;
  try {
    payment = await razorpay.payments.fetch(razorpayPaymentId);
  } catch (error) {
    logger.error("Failed to fetch payment from Razorpay", { orderId, error });
    throw new HttpsError("internal", "Could not confirm payment status.");
  }

  if (payment.order_id !== razorpayOrderId) {
    logger.warn("Payment order mismatch", {
      orderId,
      razorpayOrderId,
      paymentOrderId: payment.order_id,
    });
    return false;
  }

  if (Number(payment.amount) !== expectedPaise) {
    logger.warn("Payment amount mismatch", {
      orderId,
      expectedPaise,
      actual: payment.amount,
    });
    return false;
  }

  if (payment.status === "authorized") {
    try {
      payment = await razorpay.payments.capture(
        razorpayPaymentId,
        expectedPaise,
        "INR",
      );
    } catch (error) {
      logger.error("Failed to capture authorized payment", { orderId, error });
      return false;
    }
  }

  if (payment.status !== "captured") {
    logger.warn("Payment not captured", {
      orderId,
      status: payment.status,
    });
    return false;
  }

  return true;
}

/**
 * Independently reconciles an order against Razorpay. Used when the app did not
 * receive a clean success callback (crash, app closed, network drop, or a
 * failure event) so a genuinely captured payment is never lost, and a failed
 * one is never wrongly marked paid. Safe to call multiple times.
 */
export const reconcileOrderPayment = onCall(
  { secrets: [razorpayKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to verify a payment.",
      );
    }

    const { orderId } = request.data as { orderId?: string };
    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const orderData = orderDoc.data()!;

    if (orderData.isPaid === true) {
      return { paid: true, alreadyPaid: true };
    }

    const razorpayOrderId =
      typeof orderData.razorpayOrderId === "string"
        ? orderData.razorpayOrderId
        : null;
    if (!razorpayOrderId) {
      // No Razorpay order was ever created for this order; nothing to reconcile.
      return { paid: false };
    }

    const expectedPaise = expectedAmountPaise(orderData);
    const razorpay = getRazorpayInstance();

    let payments;
    try {
      payments = await razorpay.orders.fetchPayments(razorpayOrderId);
    } catch (error) {
      logger.error("Failed to fetch payments for order", { orderId, error });
      throw new HttpsError("internal", "Could not confirm payment status.");
    }

    const items = (payments.items ?? []) as Array<{
      id: string;
      status: string;
      amount: number | string;
    }>;

    // Find a payment we can confirm as captured for the exact amount.
    for (const item of items) {
      if (Number(item.amount) !== expectedPaise) continue;
      if (item.status !== "captured" && item.status !== "authorized") continue;

      const captured = await confirmCapturedPayment(
        item.id,
        razorpayOrderId,
        expectedPaise,
        orderId,
      );
      if (!captured) continue;

      try {
        await orderDoc.ref.update({
          isPaid: true,
          paymentMethod: "upi",
          razorpayPaymentId: item.id,
          razorpayOrderId,
        });
        await recordTransaction(
          orderData,
          orderId,
          item.id,
          razorpayOrderId,
          expectedPaise,
        );
      } catch (error) {
        logger.error("Failed to update order during reconciliation", {
          orderId,
          error,
        });
        throw new HttpsError(
          "internal",
          "Payment confirmed but order update failed.",
        );
      }
      return { paid: true, alreadyPaid: false, razorpayPaymentId: item.id };
    }

    return { paid: false };
  },
);
