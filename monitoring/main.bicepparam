using './main.bicep'

// If you run scripts/deploy-monitoring.ps1 after scripts/deploy-infra.ps1,
// the script reads the infra deployment outputs and overrides the resource IDs/names below.
// Edit these values only when deploying monitoring manually or against an existing environment.
param location = 'australiaeast'
param alertEmail = 'awliebenberg@outlook.com'

param applicationInsightsResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.Insights/components/coffeeobs-appi-45hsfjth6qdyi'
param blobServiceResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.Storage/storageAccounts/coffeeobs45hsfjth6qdyi/blobServices/default'
param cosmosAccountResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.DocumentDB/databaseAccounts/coffeeobs-cosmos-45hsfjth6qdyi'
param functionAppName = 'coffeeobs-func-45hsfjth6qdyi'
param functionAppResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.Web/sites/coffeeobs-func-45hsfjth6qdyi'
param logAnalyticsWorkspaceResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.OperationalInsights/workspaces/coffeeobs-law-45hsfjth6qdyi'
//param queueName = 'coffee-orders'
//param receiptsContainerName = 'receipts' 
param serviceBusNamespaceName = 'coffeeobs-sb-45hsfjth6qdyi'
//param serviceBusNamespaceResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.ServiceBus/namespaces/coffeeobs-sb-45hsfjth6qdyi'
param serviceBusQueueResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.ServiceBus/namespaces/coffeeobs-sb-45hsfjth6qdyi/queues/coffee-orders'
param storageAccountName = 'coffeeobs45hsfjth6qdyi'
param storageAccountResourceId = '/subscriptions/43b7a2aa-b2f7-408e-a4ad-26dd069437df/resourceGroups/rg-coffee-observability/providers/Microsoft.Storage/storageAccounts/coffeeobs45hsfjth6qdyi'





// param functionAppResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.Web/sites/coffeeobs-func-example'
// param functionAppName = 'coffeeobs-func-example'
// param applicationInsightsResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.Insights/components/coffeeobs-appi-example'
// param logAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.OperationalInsights/workspaces/coffeeobs-law-example'
// param serviceBusNamespaceName = 'coffeeobs-sb-example'
// param serviceBusQueueResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.ServiceBus/namespaces/coffeeobs-sb-example/queues/coffee-orders'
// param cosmosAccountResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.DocumentDB/databaseAccounts/coffeeobs-cosmos-example'
// param storageAccountResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.Storage/storageAccounts/coffeeobsexample'
// param storageAccountName = 'coffeeobsexample'
// param blobServiceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-coffee-observability/providers/Microsoft.Storage/storageAccounts/coffeeobsexample/blobServices/default'

// Classroom-friendly thresholds. Raise these for production or busier test environments.
param serviceBusActiveMessagesThreshold = 25
param serviceBusDeadLettersThreshold = 0
param functionHttp5xxThreshold = 0
param functionResponseTimeSecondsThreshold = 5
param cosmosLatencyMsThreshold = 250
param cosmosNormalizedRuThreshold = 80
param blobLatencyMsThreshold = 1000
