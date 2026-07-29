import * as appInsights from "applicationinsights";

let configured = false;

export function configureTelemetry(): void {
  if (configured) {
    return;
  }

  const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;
  if (!connectionString) {
    configured = true;
    return;
  }

  appInsights
    .setup(connectionString)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true, true)
    .setSendLiveMetrics(true)
    .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C)
    .start();

  const client = appInsights.defaultClient;
  if (client) {
    client.context.tags[client.context.keys.cloudRole] = "coffee-orders-functions";
  }

  configured = true;
}

export function trackEvent(name: string, properties?: Record<string, string>, measurements?: Record<string, number>): void {
  appInsights.defaultClient?.trackEvent({ name, properties, measurements });
}

export function trackMetric(name: string, value: number, properties?: Record<string, string>): void {
  appInsights.defaultClient?.trackMetric({ name, value, properties });
}

export function trackException(error: unknown, properties?: Record<string, string>): void {
  const exception = error instanceof Error ? error : new Error(String(error));
  appInsights.defaultClient?.trackException({ exception, properties });
}
