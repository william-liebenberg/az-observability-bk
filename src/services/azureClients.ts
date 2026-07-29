import { BlobServiceClient, ContainerClient } from "@azure/storage-blob";
import { Container, CosmosClient } from "@azure/cosmos";
import { ServiceBusClient, ServiceBusSender } from "@azure/service-bus";
import { getConfig } from "../shared/config";

let cosmosContainer: Container | undefined;
let blobContainer: ContainerClient | undefined;
let serviceBusClient: ServiceBusClient | undefined;
let sender: ServiceBusSender | undefined;

export function getCosmosContainer(): Container {
  if (!cosmosContainer) {
    const config = getConfig();
    const client = new CosmosClient(config.cosmosConnectionString);
    cosmosContainer = client.database(config.cosmosDatabaseName).container(config.cosmosContainerName);
  }

  return cosmosContainer;
}

export function getBlobContainer(): ContainerClient {
  if (!blobContainer) {
    const config = getConfig();
    const client = BlobServiceClient.fromConnectionString(config.blobConnectionString);
    blobContainer = client.getContainerClient(config.blobContainerName);
  }

  return blobContainer;
}

export function getServiceBusSender(): ServiceBusSender {
  if (!sender) {
    const config = getConfig();
    serviceBusClient = new ServiceBusClient(config.serviceBusConnectionString);
    sender = serviceBusClient.createSender(config.serviceBusQueueName);
  }

  return sender;
}
