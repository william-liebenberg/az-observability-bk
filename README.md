# Azure Observability Coffee Shop Demo

This repository contains a small Azure Functions TypeScript demo for an online coffee ordering shop. It is designed for an Azure observability overview aimed at teams who already know AWS CloudWatch/CloudTrail and are learning Azure Monitor, Log Analytics, Application Insights, and diagnostic settings.

## What the demo includes

- HTTP API for accepting and reading coffee orders.
- Service Bus queue trigger that brews orders asynchronously and can intentionally dead-letter poison messages.
- Cosmos DB NoSQL storage for order state, plus a change-feed trigger for observability scenarios.
- Blob Storage receipt writes, plus a blob trigger that emits custom telemetry.
- Application Insights SDK setup with custom events, metrics, dependencies, exceptions, and live metrics.
- Bicep IaC for the demo resources in `infra/main.bicep`.
- Bicep IaC for diagnostic settings, action groups, metric alerts, a log alert, and a workbook dashboard in `monitoring/main.bicep`.
- Discussion-ready observability tables in `docs/observability-metrics-and-alerts.md`.

## Azure-to-AWS mental model

| Azure concept | Closest AWS mental model | Demo use |
| --- | --- | --- |
| Azure Monitor metrics | CloudWatch Metrics | Resource-level metrics for Function App, Service Bus, Cosmos DB, and Storage. |
| Log Analytics workspace | CloudWatch Logs Logs Insights | Central query workspace used by workspace-based Application Insights. |
| Application Insights | CloudWatch Application Signals / X-Ray / application logs | Request, dependency, exception, custom event, and custom metric telemetry from the Function app. |
| Diagnostic settings | CloudWatch log/metric publishing configuration | Route resource logs and platform metrics into Log Analytics or storage for deeper analysis. |
| Metric alerts and scheduled query rules | CloudWatch Alarms | Threshold-based alerts for resource and application symptoms. |
| Workbooks | CloudWatch Dashboards | Interactive dashboard for exploring app and dependency telemetry. |

## Local development

1. Install Node.js 22 and Azure Functions Core Tools v4.
2. Copy `local.settings.example.json` to `local.settings.json` and fill in real connection strings, or deploy `infra/main.bicep` and copy the generated Function App settings.
3. Install dependencies and build:

   ```bash
   npm install
   npm run build
   ```

4. Start locally:

   ```bash
   npm start
   ```

## API endpoints

All endpoints except health use Function-level auth when hosted in Azure.

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/api/health` | Health check and simple Application Insights custom event. |
| `POST` | `/api/orders` | Accept a coffee order, write it to Cosmos DB, and enqueue a Service Bus message. |
| `GET` | `/api/orders/{orderId}` | Read an order document from Cosmos DB. |
| `POST` | `/api/demo/servicebus/poison` | Send a poison Service Bus message that retries and eventually dead-letters. |
| `POST` | `/api/demo/failure` | Generate latency and optional exception telemetry for Application Insights exercises. |

Example order request:

```json
{
  "customerName": "Ada",
  "drink": "flat white",
  "size": "medium",
  "milk": "oat",
  "extras": ["extra shot"],
  "brewDelayMs": 750
}
```

Example failure request:

```json
{
  "kind": "exception",
  "delayMs": 1500
}
```

## Deploy resources

Edit the parameter defaults first if needed:

- `infra/main.bicepparam` for a Flex Consumption-supported location, resource name prefix, maximum instance count, and instance memory size.
- `monitoring/main.bicepparam` for alert email, resource IDs/names, and alert thresholds.

Deploy the app infrastructure with PowerShell:

```powershell
./scripts/deploy-infra.ps1
```

Deploy monitoring after the infra deployment. By default, this reads the `coffee-infra` deployment outputs and overrides the placeholder resource IDs/names in `monitoring/main.bicepparam`:

```powershell
./scripts/deploy-monitoring.ps1 -AlertEmail ops@example.com
```

To preview either deployment, add `-WhatIf`. To deploy monitoring only from the parameter file values, add `-SkipInfraOutputOverrides`.

Build, zip, and publish the Function app to the demo Function App:

```powershell
./scripts/publish-functionapp.ps1
```

The publish script defaults to Function App `coffeeobs-func-45hsfjth6qdyi` in resource group `rg-coffee-observability`. It runs `npm ci`, `npm run build`, creates a zip package in `.artifacts/`, installs production dependencies into the package, uploads the package to container `app-package-coffeeobs-func-45hsfjth6qdyi-45hsfjt` in storage account `coffeeobs45hsfjth6qdyi`, and publishes with Azure Functions package deployment. Flex Consumption doesn't support in-place migration from Linux Consumption; for an existing deployed app, deploy to a new Function App/plan (for example with a new resource group or `namePrefix`) and republish the package.

## Deep dive flow

1. Create several normal orders with `POST /api/orders`.
2. Watch Application Insights requests, dependencies, custom events, and custom metrics.
3. Watch Service Bus queue metrics while the queue trigger drains orders.
4. Send `POST /api/demo/servicebus/poison` to demonstrate retries, errors, and dead-letter growth.
5. Use `POST /api/demo/failure` to generate failed requests and exception telemetry.
6. Inspect Cosmos DB account metrics for latency/RU symptoms and Blob Storage metrics for receipt write availability/latency.

See `docs/observability-metrics-and-alerts.md` for facilitator tables and practical “good observability” guidance.
