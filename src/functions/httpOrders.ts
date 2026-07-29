import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
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

app.http("hello", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "",
  handler: async (): Promise<HttpResponseInit> => ({
    status: 200,
    body: "hello"
  })
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

