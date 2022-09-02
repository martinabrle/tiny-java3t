param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param appInsightsName string
param keyVaultName string
param keyVaultAccessIndentityName string
param dbServerName string
param dbName string
param createDB bool
@secure()
param dbAdminName string
@secure()
param dbAdminPassword string
@secure()
param dbUserName string
@secure()
param dbUserPassword string
param containerRegistryName string
param aksClusterName string
param aksAdminGroupObjectId string
param deploymentClientIPAddress string

param nodeResoureGroup string = resourceGroup().name
param location string = resourceGroup().location
param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceRG)
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  dependsOn: [
    logAnalyticsWorkspace
  ]
  location: location
  kind: 'java'
  tags: tagsArray
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource postgreSQLServer 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: dbServerName
  location: location
  tags: tagsArray
  sku: {
    name: 'B_Gen5_1'
    tier: 'Basic'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    storageProfile: {
      storageMB: 5120
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Disabled'
    }
    createMode: 'Default'
    version: '11'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLSEnforcementDisabled'
    infrastructureEncryption: 'Disabled'
    publicNetworkAccess: 'Enabled'
    administratorLogin: dbAdminName
    administratorLoginPassword: dbAdminPassword
  }
}

resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = if (createDB) {
  parent: postgreSQLServer
  name: dbName
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

resource allowClientIPFirewallRule 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  name: 'AllowDeploymentClientIP'
  parent: postgreSQLServer
  properties: {
    endIpAddress: deploymentClientIPAddress
    startIpAddress: deploymentClientIPAddress
  }
}

resource allowAllIPsFirewallRule 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: postgreSQLServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource postgreSQLServerDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${dbServerName}-logs'
  scope: postgreSQLServer
  properties: {
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
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  tags: tagsArray
  sku: {
    name: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: true
  }
}

module rbacContainerRegistryACRPull './components/role-assignment-container-registry.bicep' = {
  name: 'deployment-rbac-container-registry-acr-pull'
  params: {
    containerRegistryName: containerRegistryName
    roleDefinitionId: acrPullRole.id
    principalId: aksService.properties.identityProfile.kubeletidentity.objectId
    roleAssignmentNameGuid: guid(aksService.properties.identityProfile.kubeletidentity.objectId, containerRegistry.id, acrPullRole.id)
  }
}

//To use system assigned identities, aksService needs to exist before this template runs...
resource aksService 'Microsoft.ContainerService/managedClusters@2022-06-02-preview' existing = {
  name: aksClusterName
}

// resource keyVaultAccessIndentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
//   name: keyVaultAccessIndentityName
// }

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  dependsOn: [
    appInsights
  ]
  location: location
  tags: tagsArray
  properties: {
    createMode: 'default'
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enabledForTemplateDeployment: true
    enabledForDeployment: true
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  dependsOn: [
    aksServiceConfiguration //this would otherwise occasionally fail if not deployed as last
  ]
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource kvSecretSpringDataSourceURL 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-URL'
  properties: {
    value: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    contentType: 'string'
  }
}

resource kvSecretAppClientId 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-APP-CLIENT-ID'
  properties: {
    value: aksService.identity.principalId
    contentType: 'string'
  }
}

resource kvSecretDbUserName 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME'
  properties: {
    value: dbUserName
    contentType: 'string'
  }
}

resource kvSecretDbUserPassword 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-PASSWORD'
  properties: {
    value: dbUserPassword
    contentType: 'string'
  }
}

module rbacKV './components/role-assignment-kv.bicep' = {
   name: 'rbac-kv-aks-service'
    params: {
      kvName: keyVault.name
      roleAssignmentNameGuid: guid(aksService.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.clientId, keyVault.id, keyVaultSecretsUser.id)
      roleDefinitionId: keyVaultSecretsUser.id
      principalId: aksService.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
      //clientId
      //aksService.properties.identityProfile.kubeletidentity.objectId
      //keyVaultAccessIndentity.properties.principalId
    }
}

module aksServiceConfiguration 'aks-mi-service.bicep' = {
  name: 'aks-mi-service'
  dependsOn: [
    rbacContainerRegistryACRPull
    rbacKV
  ]
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

@description('This is the built-in AcrPull role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull')
resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}
