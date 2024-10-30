@description('Environment of the web app')
param environment string = 'dev'

@description('Location of services')
param location string = resourceGroup().location

var logAnalyticsName = '${uniqueString(resourceGroup().id)}-mpnp-la'
var appInsightsName = '${uniqueString(resourceGroup().id)}-mpnp-ai'
var appServicePlanName = '${uniqueString(resourceGroup().id)}-mpnp-asp'
var sku = 'S1'
var webAppName = '${uniqueString(resourceGroup().id)}-${environment}'
var registryName = '${uniqueString(resourceGroup().id)}mpnpreg'
var registrySku = 'Standard'
var imageName = 'techexcel/dotnetcoreapp'
var startupCommand = ''

// Create a log analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

// Create an application insights and connect it with the log analytics workspace
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Create a container registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: registrySku
  }
}

// Create a app service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: sku
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
}

// Create a web app and connect it with app insights and container registry
resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${uniqueString(resourceGroup().id)}/${imageName}'
      http20Enabled: true
      minTlsVersion: '1.2'
      appCommandLine: startupCommand
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
      ]
    }
  }
}

// Assign the identity of the web app to the container registry
resource webAppIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: '${webAppName}roleassignment'
  scope: containerRegistry
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
}

output application_name string = webApp.name
output application_url string = webApp.properties.hostNames[0]
output container_registry_name string = containerRegistry.name
