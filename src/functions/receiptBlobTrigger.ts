import { app, InvocationContext } from "@azure/functions";
import { trackEvent, trackMetric } from "../shared/telemetry";

app.storageBlob("receiptBlobCreated", {
  connection: "BlobStorageConnection",
  path: "%BLOB_CONTAINER_NAME%/{name}",
  handler: async (blob: Buffer, context: InvocationContext): Promise<void> => {
    const name = String(context.triggerMetadata?.name ?? "unknown");
    context.log(`Receipt blob observed: ${name} (${blob.length} bytes)`);

    trackEvent("CoffeeReceiptBlobObserved", { blobName: name });
    trackMetric("CoffeeReceiptBlobBytes", blob.length, { blobName: name });
  }
});
