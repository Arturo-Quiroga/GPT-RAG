param appName string
param keyVaultName string = ''
param storageAccountName string
param appServicePlanId string
param appSettings array
param appInsightsConnectionString string
param appInsightsInstrumentationKey string
param tags object = {}
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param clientAffinityEnabled bool = false
param kind string = 'functionapp,linux'
param functionAppScaleLimit int = -1
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param runtimeName string =  'python'
param runtimeVersion string = '3.10'
param use32BitWorkerProcess bool = false
param healthCheckPath string = ''
var runtimeNameAndVersion = '${runtimeName}|${runtimeVersion}'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'python'
])
param runtime string = 'python'

var functionAppName = appName
var functionWorkerRuntime = runtime

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: kind
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    // serverFarmId: hostingPlan.id
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: runtimeNameAndVersion      
      alwaysOn: alwaysOn
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers
      minimumElasticInstanceCount: minimumElasticInstanceCount
      use32BitWorkerProcess: use32BitWorkerProcess      
      functionAppScaleLimit: functionAppScaleLimit
      healthCheckPath: healthCheckPath
      appSettings: concat(appSettings,[
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'AZURE_KEY_VAULT_ENDPOINT'
          value: keyVault.properties.vaultUri
        }
        // {
        //   name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
        //   value: string(scmDoBuildDuringDeployment)
        // }
        // {
        //   name: 'ENABLE_ORYX_BUILD'
        //   value: string(enableOryxBuild)
        // }        
      ])
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }      
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
 name: keyVaultName
}

// param waitSeconds int =  240
// module delayDeployment 'br/public:deployment-scripts/wait:1.1.1' = {
//   name: 'delayDeployment'
//   params: {
//     waitSeconds: waitSeconds
//     location: location
//   }
// }

// output hostKey string = functionAppHost.listKeys().functionKeys.default

output identityPrincipalId string = functionApp.identity.principalId
output name string = functionApp.name
output uri string = 'https://${functionApp.properties.defaultHostName}'
output location string = functionApp.location
// output hostKey string = listKeys('${functionApp.id}/host/default', functionApp.apiVersion).functionKeys.default
output id string = functionApp.id
