import { randomUUID } from "node:crypto";
import { getBlobContainer, getCosmosContainer, getServiceBusSender } from "./azureClients";
import { trackEvent, trackMetric } from "../shared/telemetry";

export type CoffeeSize = "small" | "medium" | "large";

export interface CoffeeOrderRequest {
  customerName?: string;
  drink?: string;
  size?: CoffeeSize;
  milk?: string;
  extras?: string[];
  brewDelayMs?: number;
}

export interface CoffeeOrder {
  id: string;
  orderId: string;
  customerName: string;
  drink: string;
  size: CoffeeSize;
  milk?: string;
  extras: string[];
  status: "accepted" | "brewing" | "ready" | "failed";
  acceptedAt: string;
  updatedAt: string;
  brewDelayMs?: number;
}

export function validateOrder(input: CoffeeOrderRequest): Required<Pick<CoffeeOrderRequest, "customerName" | "drink" | "size">> & CoffeeOrderRequest {
  const customerName = input.customerName?.trim();
  const drink = input.drink?.trim();
  const size = input.size ?? "medium";

  if (!customerName) {
    throw new Error("customerName is required");
  }

  if (!drink) {
    throw new Error("drink is required");
  }

  if (!["small", "medium", "large"].includes(size)) {
    throw new Error("size must be one of: small, medium, large");
  }

  return { ...input, customerName, drink, size };
}

export async function createOrder(input: CoffeeOrderRequest): Promise<CoffeeOrder> {
  const validated = validateOrder(input);
  const now = new Date().toISOString();
  const id = randomUUID();

  const order: CoffeeOrder = {
    id,
    orderId: id,
    customerName: validated.customerName,
    drink: validated.drink,
    size: validated.size,
    milk: validated.milk,
    extras: validated.extras ?? [],
    status: "accepted",
    acceptedAt: now,
    updatedAt: now,
    brewDelayMs: validated.brewDelayMs
  };

  await getCosmosContainer().items.create(order);
  await getServiceBusSender().sendMessages({
    body: {
      orderId: order.orderId,
      acceptedAt: order.acceptedAt,
      brewDelayMs: order.brewDelayMs
    },
    contentType: "application/json",
    subject: "CoffeeOrderAccepted",
    messageId: order.orderId,
    correlationId: order.orderId,
    applicationProperties: {
      drink: order.drink,
      size: order.size,
      demoScenario: "normal-order"
    }
  });

  trackEvent("CoffeeOrderAccepted", { orderId: order.orderId, drink: order.drink, size: order.size });
  trackMetric("CoffeeOrdersAccepted", 1, { drink: order.drink, size: order.size });

  return order;
}

export async function getOrder(orderId: string): Promise<CoffeeOrder | undefined> {
  const { resource } = await getCosmosContainer().item(orderId, orderId).read<CoffeeOrder>();
  return resource;
}

export async function markOrderBrewing(orderId: string): Promise<CoffeeOrder> {
  const order = await getOrder(orderId);
  if (!order) {
    throw new Error(`Order ${orderId} was not found`);
  }

  const updated: CoffeeOrder = {
    ...order,
    status: "brewing",
    updatedAt: new Date().toISOString()
  };

  await getCosmosContainer().item(orderId, orderId).replace(updated);
  return updated;
}

export async function markOrderReady(orderId: string): Promise<CoffeeOrder> {
  const order = await getOrder(orderId);
  if (!order) {
    throw new Error(`Order ${orderId} was not found`);
  }

  const updated: CoffeeOrder = {
    ...order,
    status: "ready",
    updatedAt: new Date().toISOString()
  };

  await getCosmosContainer().item(orderId, orderId).replace(updated);
  return updated;
}

export async function writeReceipt(order: CoffeeOrder): Promise<string> {
  const receiptName = `${order.orderId}.json`;
  const receipt = {
    orderId: order.orderId,
    customerName: order.customerName,
    drink: order.drink,
    size: order.size,
    milk: order.milk,
    extras: order.extras,
    completedAt: new Date().toISOString()
  };
  const body = JSON.stringify(receipt, null, 2);
  const blockBlob = getBlobContainer().getBlockBlobClient(receiptName);

  await blockBlob.upload(body, Buffer.byteLength(body), {
    blobHTTPHeaders: { blobContentType: "application/json" },
    metadata: { orderId: order.orderId }
  });

  return receiptName;
}

export async function sendPoisonMessage(reason = "demo-poison-message"): Promise<string> {
  const messageId = `poison-${Date.now()}`;
  await getServiceBusSender().sendMessages({
    body: { poison: true, reason },
    contentType: "application/json",
    subject: "CoffeeOrderPoisonDemo",
    messageId,
    applicationProperties: { demoScenario: "dead-letter" }
  });

  trackEvent("CoffeePoisonMessageSent", { messageId, reason });
  return messageId;
}
