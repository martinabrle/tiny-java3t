param springAppsServiceName string
param webAppClientId string
param webAppName string
param appInsightsConnectionString string
param appInsightsInstrumentationKey string
param webAppPort string
param apiURI string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource springApps 'Microsoft.AppPlatform/Spring@2022-05-01-preview' = {
  name: springAppsServiceName
  location: location
  tags: tagsArray
  sku: {
    capacity: 1
    name: 'S0'
    tier: 'Standard'
  }
  properties: {
    zoneRedundant: false
  }
}

resource springAppsApp 'Microsoft.AppPlatform/Spring/apps@2022-05-01-preview' = {
  name: webAppName
  location: location
  parent: springApps
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: false
    public: true
    fqdn: '${springAppsServiceName}-${webAppName}.azuremicroservices.io'
    temporaryDisk: {
      sizeInGB: 5
      mountPath: '/tmp'
    }
    persistentDisk: {
      sizeInGB: 0
      mountPath: '/persistent'
    }
    enableEndToEndTLS: false
  }
}

resource springAppsAppDeployment 'Microsoft.AppPlatform/Spring/apps/deployments@2022-05-01-preview' = {
  name: 'default'
  parent: springAppsApp
  sku: {
    name: 'S0'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    deploymentSettings: {
      resourceRequests: {
        cpu: '1'
        memory: '1Gi'
      }
      environmentVariables: {
        PORT: webAppPort
        APP_CLIENT_ID: webAppClientId
        API_URI: apiURI
        APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
        APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
      }

    }
    source: any({
      type: 'Jar'
      relativePath: '<default>'
      runtimeVersion: 'Java_11'
      version: 'Java_11'
    })
    active: true
  }
}
