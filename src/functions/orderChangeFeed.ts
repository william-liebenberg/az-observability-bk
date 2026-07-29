import { app, InvocationContext } from "@azure/functions";
import { trackEvent, trackMetric } from "../shared/telemetry";
import { CoffeeOrder } from "../services/orders";

app.cosmosDB("orderChangeFeed", {
  connection: "CosmosDbConnection",
  databaseName: "%COSMOS_DATABASE_NAME%",
  containerName: "%COSMOS_CONTAINER_NAME%",
  leaseContainerName: "leases",
  createLeaseContainerIfNotExists: true,
  handler: async (documents: CoffeeOrder[], context: InvocationContext): Promise<void> => {
    const count = documents.length;
    context.log(`Cosmos DB change feed observed ${count} order document change(s)`);

    trackMetric("CoffeeOrderCosmosChangeFeedDocuments", count);
    for (const document of documents) {
      trackEvent("CoffeeOrderDocumentChanged", {
        orderId: document.orderId,
        status: document.status
      });
    }
  }
});
