import { app, InvocationContext } from "@azure/functions";
import { markOrderBrewing, markOrderReady, writeReceipt } from "../services/orders";
import { trackEvent, trackException, trackMetric } from "../shared/telemetry";

interface CoffeeOrderMessage {
  orderId?: string;
  acceptedAt?: string;
  brewDelayMs?: number;
  poison?: boolean;
  reason?: string;
}

function asMessage(input: unknown): CoffeeOrderMessage {
  if (typeof input === "string") {
    return JSON.parse(input) as CoffeeOrderMessage;
  }

  return input as CoffeeOrderMessage;
}

app.serviceBusQueue("processCoffeeOrders", {
  connection: "ServiceBusConnection",
  queueName: "%SERVICEBUS_QUEUE_NAME%",
  handler: async (message: unknown, context: InvocationContext): Promise<void> => {
    const deliveryCount = String(context.triggerMetadata?.deliveryCount ?? "unknown");
    const messageId = String(context.triggerMetadata?.messageId ?? "unknown");

    try {
      const orderMessage = asMessage(message);
      if (orderMessage.poison) {
        throw new Error(`Poison message requested for observability demo: ${orderMessage.reason ?? "no reason"}`);
      }

      if (!orderMessage.orderId) {
        throw new Error("Service Bus message is missing orderId");
      }

      context.log(`Brewing coffee order ${orderMessage.orderId}; Service Bus delivery count ${deliveryCount}`);
      trackEvent("CoffeeOrderDequeued", { orderId: orderMessage.orderId, messageId, deliveryCount });

      const brewingOrder = await markOrderBrewing(orderMessage.orderId);
      if (orderMessage.brewDelayMs && orderMessage.brewDelayMs > 0) {
        const delay = Math.min(orderMessage.brewDelayMs, 30000);
        await new Promise((resolve) => setTimeout(resolve, delay));
        trackMetric("CoffeeBrewArtificialDelayMs", delay, { orderId: orderMessage.orderId });
      }

      const readyOrder = await markOrderReady(brewingOrder.orderId);
      const receiptName = await writeReceipt(readyOrder);

      if (orderMessage.acceptedAt) {
        const endToEndLatencyMs = Date.now() - Date.parse(orderMessage.acceptedAt);
        trackMetric("CoffeeOrderEndToEndLatencyMs", endToEndLatencyMs, { orderId: readyOrder.orderId });
      }

      trackEvent("CoffeeOrderReady", { orderId: readyOrder.orderId, receiptName });
      context.log(`Coffee order ${readyOrder.orderId} is ready; receipt ${receiptName} written`);
    } catch (error) {
      context.error("Failed to process Service Bus coffee order", error);
      trackException(error, { operation: "processCoffeeOrders", messageId, deliveryCount });
      throw error;
    }
  }
});
