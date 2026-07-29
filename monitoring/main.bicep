

// Provisions the monitoring layer for the coffee order demo after the core
// infrastructure has been deployed by infra/main.bicep. This template connects
// the Function App, Service Bus queue, Cosmos DB account, and Storage account to
// Log Analytics/Application Insights with diagnostic settings, then adds an email
// action group, Azure Monitor alerts, and a workbook for the workshop dashboard.
//
// The goal is to make the demo operationally observable: queue backlogs,
// dead-lettering, Function App failures or latency, Cosmos DB latency/RU pressure,
// Storage availability, and application telemetry can all be investigated from a
// single monitoring deployment.

@description('Azure region for alert rule and workbook resources.')
param location string = resourceGroup().location

@description('Resource ID of the Function App from infra/main.bicep outputs.')
param functionAppResourceId string

@description('Name of the Function App from infra/main.bicep outputs.')
param functionAppName string

@description('Resource ID of the Application Insights component from infra/main.bicep outputs.')
param applicationInsightsResourceId string

@description('Resource ID of the Log Analytics workspace from infra/main.bicep outputs.')
param logAnalyticsWorkspaceResourceId string

@description('Name of the Service Bus namespace from infra/main.bicep outputs.')
param serviceBusNamespaceName string

@description('Resource ID of the Service Bus queue from infra/main.bicep outputs.')
param serviceBusQueueResourceId string

@description('Resource ID of the Cosmos DB account from infra/main.bicep outputs.')
param cosmosAccountResourceId string

@description('Resource ID of the Storage Account from infra/main.bicep outputs.')
param storageAccountResourceId string

@description('Name of the Storage Account from infra/main.bicep outputs.')
param storageAccountName string

@description('Resource ID of the Storage blob service from infra/main.bicep outputs.')
param blobServiceResourceId string

@description('Email address that receives demo alert notifications.')
param alertEmail string

@description('Active message count that indicates a Service Bus backlog for this demo.')
param serviceBusActiveMessagesThreshold int = 25

@description('Dead-lettered message count threshold for this demo.')
param serviceBusDeadLettersThreshold int = 0

@description('HTTP 5xx count threshold for the Function App.')
param functionHttp5xxThreshold int = 0

@description('Average Function App response time in seconds before alerting.')
param functionResponseTimeSecondsThreshold int = 5

@description('Cosmos DB server-side latency threshold in milliseconds.')
param cosmosLatencyMsThreshold int = 250

@description('Cosmos DB normalized RU consumption threshold percentage.')
param cosmosNormalizedRuThreshold int = 80

@description('Blob success end-to-end latency threshold in milliseconds.')
param blobLatencyMsThreshold int = 1000

var actionGroupName = 'coffee-observability-ag'
var workbookName = guid(resourceGroup().id, 'coffee-observability-workbook')
var cosmosAccountName = last(split(cosmosAccountResourceId, '/'))
var serviceBusQueueName = last(split(serviceBusQueueResourceId, '/'))
var workbookData = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Coffee shop observability dashboard\nUse this workbook during the deep dives to correlate resource metrics with Application Insights request, dependency, exception, and custom-event telemetry.'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'requests | summarize requests=count(), failures=countif(success == false), p95_duration_ms=percentile(duration, 95) by bin(timestamp, 5m) | order by timestamp asc'
        size: 0
        title: 'Function API requests and failures'
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'dependencies | summarize calls=count(), failures=countif(success == false), p95_duration_ms=percentile(duration, 95) by target, type, bin(timestamp, 5m) | order by timestamp asc'
        size: 0
        title: 'Dependencies: Service Bus, Cosmos DB, and Storage'
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'customEvents | where name startswith "Coffee" | summarize count() by name, bin(timestamp, 5m) | order by timestamp asc'
        size: 0
        title: 'Coffee demo business and trigger events'
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'exceptions | summarize count() by problemId, outerMessage, bin(timestamp, 5m) | order by timestamp desc'
        size: 0
        title: 'Exceptions'
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
  ]
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource functionDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: 'coffee-function-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: serviceBusNamespace
  name: 'coffee-servicebus-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource cosmosDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cosmosAccount
  name: 'coffee-cosmos-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: 'coffee-blob-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'coffeeobs'
    emailReceivers: [
      {
        name: 'demo-operators'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource serviceBusBacklogAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-servicebus-active-messages-high'
  location: 'global'
  properties: {
    description: 'Service Bus queue backlog is growing. Investigate Function trigger health, downstream Cosmos/Storage failures, and consumer scale-out.'
    severity: 2
    enabled: true
    scopes: [
      serviceBusNamespace.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ActiveMessagesHigh'
          metricName: 'ActiveMessages'
          metricNamespace: 'Microsoft.ServiceBus/namespaces'
          dimensions: [
            {
              name: 'EntityName'
              operator: 'Include'
              values: [
                serviceBusQueueName
              ]
            }
          ]
          operator: 'GreaterThan'
          threshold: serviceBusActiveMessagesThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource serviceBusDeadLetterAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-servicebus-deadletters-present'
  location: 'global'
  properties: {
    description: 'Messages are reaching the Service Bus dead-letter queue. Inspect trigger exceptions and message schema/poison payloads.'
    severity: 1
    enabled: true
    scopes: [
      serviceBusNamespace.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DeadletteredMessagesPresent'
          metricName: 'DeadletteredMessages'
          metricNamespace: 'Microsoft.ServiceBus/namespaces'
          dimensions: [
            {
              name: 'EntityName'
              operator: 'Include'
              values: [
                serviceBusQueueName
              ]
            }
          ]
          operator: 'GreaterThan'
          threshold: serviceBusDeadLettersThreshold
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource functionHttp5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-function-http-5xx'
  location: 'global'
  properties: {
    description: 'The Function App is returning HTTP 5xx responses.'
    severity: 2
    enabled: true
    scopes: [
      functionAppResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxHigh'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: functionHttp5xxThreshold
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource functionResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-function-response-time-high'
  location: 'global'
  properties: {
    description: 'Function App average response time is high. Use Application Insights request/dependency breakdown for the root cause.'
    severity: 3
    enabled: true
    scopes: [
      functionAppResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AverageResponseTimeHigh'
          metricName: 'AverageResponseTime'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: functionResponseTimeSecondsThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource appInsightsFailureAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'coffee-appinsights-request-failures'
  location: location
  properties: {
    displayName: 'Coffee API failed requests or exceptions'
    description: 'Application Insights observed failed requests or exceptions in the Function app.'
    severity: 2
    enabled: true
    scopes: [
      applicationInsightsResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'requests | where success == false | union (exceptions | project timestamp) | summarize Count=count()'
          timeAggregation: 'Total'
          metricMeasureColumn: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

resource cosmosLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-cosmos-server-latency-high'
  location: 'global'
  properties: {
    description: 'Cosmos DB server-side latency is above the demo threshold.'
    severity: 3
    enabled: true
    scopes: [
      cosmosAccountResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ServerSideLatencyHigh'
          metricName: 'ServerSideLatency'
          metricNamespace: 'Microsoft.DocumentDB/databaseAccounts'
          operator: 'GreaterThan'
          threshold: cosmosLatencyMsThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource cosmosRuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-cosmos-normalized-ru-high'
  location: 'global'
  properties: {
    description: 'Cosmos DB normalized RU consumption is high, which can lead to 429 throttling.'
    severity: 2
    enabled: true
    scopes: [
      cosmosAccountResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NormalizedRuHigh'
          metricName: 'NormalizedRUConsumption'
          metricNamespace: 'Microsoft.DocumentDB/databaseAccounts'
          operator: 'GreaterThan'
          threshold: cosmosNormalizedRuThreshold
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource storageAvailabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-storage-availability-low'
  location: 'global'
  properties: {
    description: 'Storage availability dropped below 99 percent.'
    severity: 2
    enabled: true
    scopes: [
      storageAccountResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AvailabilityLow'
          metricName: 'Availability'
          metricNamespace: 'Microsoft.Storage/storageAccounts'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource blobLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'coffee-blob-latency-high'
  location: 'global'
  properties: {
    description: 'Blob service end-to-end latency is high. Inspect receipt writes and Storage account health.'
    severity: 3
    enabled: true
    scopes: [
      blobServiceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'BlobSuccessE2ELatencyHigh'
          metricName: 'SuccessE2ELatency'
          metricNamespace: 'Microsoft.Storage/storageAccounts/blobServices'
          operator: 'GreaterThan'
          threshold: blobLatencyMsThreshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: workbookName
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Coffee Shop Azure Observability'
    category: 'workbook'
    sourceId: applicationInsightsResourceId
    serializedData: string(workbookData)
    version: '1.0'
  }
}

output actionGroupResourceId string = actionGroup.id
output workbookResourceId string = workbook.id
