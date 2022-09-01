param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string

param aksClusterName string
param aksAdminGroupObjectId string

param nodeResoureGroup string = resourceGroup().name

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

module aksInit 'aks-mi-service.bicep' = {
  name: 'aks-mi-service'
  params: {
    aksClusterName: aksClusterName
    aksAdminGroupObjectId: aksAdminGroupObjectId
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRG: logAnalyticsWorkspaceRG
    nodeResoureGroup: nodeResoureGroup
    location: location
    tagsArray: tagsArray
  }
}
