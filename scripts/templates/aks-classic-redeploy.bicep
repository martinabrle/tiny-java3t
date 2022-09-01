param appInsightsName string

param dbServerName string
param dbName string

param dbUserName string
@secure()
param dbUserPassword string

param containerInstanceName string
param containerAppName string
param containerAppPort string
param containerImageName string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

module containerInstanceConfig 'container-instance-classic-service.bicep' = {
  name: 'deployment-container-instance-core'
  params: {
    containerInstanceName: containerInstanceName
    containerAppName: containerAppName
    containerImage: containerImageName
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    springDatasourceUrl: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    springDatasourceUserName: dbUserName
    springDatasourcePassword: dbUserPassword
    springDatasourceShowSql: 'true'
    containerAppPort: containerAppPort
    location: location
    tagsArray: tagsArray
  }
}
