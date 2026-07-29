export interface AppConfig {
  serviceBusConnectionString: string;
  serviceBusQueueName: string;
  cosmosConnectionString: string;
  cosmosDatabaseName: string;
  cosmosContainerName: string;
  blobConnectionString: string;
  blobContainerName: string;
}

function requireSetting(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required app setting: ${name}`);
  }

  return value;
}

export function getConfig(): AppConfig {
  return {
    serviceBusConnectionString: requireSetting("SERVICEBUS_CONNECTION_STRING"),
    serviceBusQueueName: process.env.SERVICEBUS_QUEUE_NAME ?? "coffee-orders",
    cosmosConnectionString: requireSetting("COSMOS_CONNECTION_STRING"),
    cosmosDatabaseName: process.env.COSMOS_DATABASE_NAME ?? "coffee-shop",
    cosmosContainerName: process.env.COSMOS_CONTAINER_NAME ?? "orders",
    blobConnectionString: requireSetting("BLOB_STORAGE_CONNECTION_STRING"),
    blobContainerName: process.env.BLOB_CONTAINER_NAME ?? "receipts"
  };
}
