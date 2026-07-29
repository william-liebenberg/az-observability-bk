@description('Azure region for all demo resources. Must support Azure Functions Flex Consumption.')
param location string = resourceGroup().location

@description('Short lowercase prefix used in resource names. Keep under 12 characters.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'coffeeobs'

@description('Maximum number of Flex Consumption instances for the Function App.')
@minValue(1)
@maxValue(1000)
param maximumInstanceCount int = 100

@description('Memory size in MB for each Flex Consumption instance.')
@allowed([
  512
  2048
  4096
])
param instanceMemoryMB int = 2048


var suffix = uniqueString(resourceGroup().id, namePrefix)
var safePrefix = toLower(replace(namePrefix, '-', ''))
var storageName = take('${safePrefix}${suffix}', 24)
var functionAppName = '${namePrefix}-func-${suffix}'
var appServicePlanName = '${namePrefix}-plan-${suffix}'
var serviceBusNamespaceName = '${namePrefix}-sb-${suffix}'
var cosmosAccountName = '${namePrefix}-cosmos-${suffix}'
var workspaceName = '${namePrefix}-law-${suffix}'
var appInsightsName = '${namePrefix}-appi-${suffix}'
var queueName = 'coffee-orders'
var databaseName = 'coffee-shop'
var ordersContainerName = 'orders'
var receiptsContainerName = 'receipts'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(suffix, 7)}'
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
var serviceBusConnectionString = serviceBusAuth.listKeys().primaryConnectionString
var cosmosConnectionString = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource receiptsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: receiptsContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource deploymentPackageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: deploymentStorageContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource serviceBusAuth 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'CoffeeDemoListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

resource orderQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 3
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    enablePartitioning: false
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource ordersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: ordersContainerName
  properties: {
    resource: {
      id: ordersContainerName
      partitionKey: {
        paths: [
          '/orderId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

resource leasesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'leases'
  properties: {
    resource: {
      id: 'leases'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          }
        }
      }
      runtime: {
        name: 'node'
        version: '22'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ServiceBusConnection'
          value: serviceBusConnectionString
        }
        {
          name: 'SERVICEBUS_CONNECTION_STRING'
          value: serviceBusConnectionString
        }
        {
          name: 'SERVICEBUS_QUEUE_NAME'
          value: queueName
        }
        {
          name: 'CosmosDbConnection'
          value: cosmosConnectionString
        }
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: cosmosConnectionString
        }
        {
          name: 'COSMOS_DATABASE_NAME'
          value: databaseName
        }
        {
          name: 'COSMOS_CONTAINER_NAME'
          value: ordersContainerName
        }
        {
          name: 'BlobStorageConnection'
          value: storageConnectionString
        }
        {
          name: 'BLOB_STORAGE_CONNECTION_STRING'
          value: storageConnectionString
        }
        {
          name: 'BLOB_CONTAINER_NAME'
          value: receiptsContainerName
        }
      ]
    }
  }
  dependsOn: [
    receiptsContainer
    deploymentPackageContainer
    orderQueue
    ordersContainer
    leasesContainer
  ]
}

output functionAppName string = functionApp.name
output functionAppResourceId string = functionApp.id
output applicationInsightsResourceId string = appInsights.id
output logAnalyticsWorkspaceResourceId string = workspace.id
output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusNamespaceResourceId string = serviceBusNamespace.id
output serviceBusQueueResourceId string = orderQueue.id
output cosmosAccountResourceId string = cosmosAccount.id
output storageAccountName string = storage.name
output storageAccountResourceId string = storage.id
output blobServiceResourceId string = blobService.id
output queueName string = queueName
output receiptsContainerName string = receiptsContainerName
