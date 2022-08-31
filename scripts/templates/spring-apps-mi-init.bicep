param springAppsServiceName string
param apiAppName string
param apiAppPort string
param webAppName string
param webAppPort string
param location string = resourceGroup().location
param tagsArray object = resourceGroup().tags

module springApiAppsInit 'spring-apps-mi-api-service.bicep' = {
  name: 'deployment-spring-apps-api-mi-init'
  params: {
    apiAppClientId: ''
    appInsightsConnectionString: ''
    appInsightsInstrumentationKey: ''
    apiAppName: apiAppName
    apiAppPort: apiAppPort
    springAppsServiceName: springAppsServiceName
    springDatasourceShowSql: 'true'
    springDatasourceUrl: ''
    springDatasourceUserName: ''
    location: location
    tagsArray: tagsArray
  }
}

module springWebAppsInit 'spring-apps-mi-web-service.bicep' = {
  name: 'deployment-spring-apps-web-mi-init'
  params: {
    webAppClientId: ''
    appInsightsConnectionString: ''
    appInsightsInstrumentationKey: ''
    webAppName: webAppName
    webAppPort: webAppPort
    springAppsServiceName: springAppsServiceName
    apiURI: ''
    location: location
    tagsArray: tagsArray
  }
}
