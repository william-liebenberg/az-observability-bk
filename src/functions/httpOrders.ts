import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { CoffeeOrderRequest, createOrder, getOrder, sendPoisonMessage } from "../services/orders";
import { trackException, trackEvent, trackMetric } from "../shared/telemetry";

function json(status: number, body: unknown): HttpResponseInit {
  return {
    status,
    jsonBody: body,
    headers: { "content-type": "application/json" }
  };
}

async function readJson<T>(request: HttpRequest): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    return {} as T;
  }
}

app.http("createCoffeeOrder", {
  methods: ["POST"],
  authLevel: "function",
  route: "orders",
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    const started = Date.now();
    try {
      const payload = await readJson<CoffeeOrderRequest>(request);
      const order = await createOrder(payload);
      const durationMs = Date.now() - started;

      context.log(`Accepted coffee order ${order.orderId}`);
      trackMetric("CreateCoffeeOrderDurationMs", durationMs, { status: "success" });

      return json(202, {
        orderId: order.orderId,
        status: order.status,
        links: {
          self: `/api/orders/${order.orderId}`
        }
      });
    } catch (error) {
      context.error("Failed to create coffee order", error);
      trackException(error, { operation: "createCoffeeOrder" });
      trackMetric("CreateCoffeeOrderDurationMs", Date.now() - started, { status: "failure" });
      return json(400, { error: error instanceof Error ? error.message : "Invalid order" });
    }
  }
});

app.http("getCoffeeOrder", {
  methods: ["GET"],
  authLevel: "function",
  route: "orders/{orderId}",
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    const orderId = request.params.orderId;
    const order = await getOrder(orderId);

    if (!order) {
      context.warn(`Order ${orderId} was not found`);
      return json(404, { error: "Order not found" });
    }

    return json(200, order);
  }
});

app.http("health", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "health",
  handler: async (): Promise<HttpResponseInit> => {
    trackEvent("CoffeeHealthCheck");
    return json(200, {
      service: "coffee-orders",
      status: "ok",
      timestamp: new Date().toISOString()
    });
  }
});

app.http("sendPoisonCoffeeOrder", {
  methods: ["POST"],
  authLevel: "function",
  route: "demo/servicebus/poison",
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    const body = await readJson<{ reason?: string }>(request);
    const messageId = await sendPoisonMessage(body.reason);

    context.warn(`Sent poison Service Bus demo message ${messageId}`);
    return json(202, {
      messageId,
      expectedObservation: "The queue trigger will retry and eventually move this message to the dead-letter queue. Watch delivery count, errors, and DeadletteredMessages."
    });
  }
});

app.http("generateDemoFailure", {
  methods: ["POST"],
  authLevel: "function",
  route: "demo/failure",
  handler: async (request: HttpRequest): Promise<HttpResponseInit> => {
    const body = await readJson<{ kind?: string; delayMs?: number }>(request);

    if (body.delayMs && body.delayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, Math.min(body.delayMs ?? 0, 10000)));
      trackMetric("DemoArtificialLatencyMs", Math.min(body.delayMs, 10000));
    }

    if (body.kind === "exception") {
      const error = new Error("Demo exception requested for Application Insights exercise");
      trackException(error, { operation: "generateDemoFailure" });
      throw error;
    }

    trackEvent("DemoFailureEndpointCalled", { kind: body.kind ?? "latency-only" });
    return json(200, {
      message: "Demo telemetry generated",
      kind: body.kind ?? "latency-only"
    });
  }
});
