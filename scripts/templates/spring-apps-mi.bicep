param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param appInsightsName string

param keyVaultName string
param dbServerName string
param dbName string
param createDB bool = true

@secure()
param dbAdminName string
@secure()
param dbAdminPassword string

@secure()
param dbUserName string

param deploymentClientIPAddress string

param springAppsServiceName string

param apiAppName string
param apiAppPort string

param webAppName string
param webAppPort string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceRG)
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'java'
  tags: tagsArray
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
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
  }
}

resource kvSecretApiAppClientId 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-APP-CLIENT-ID'
  properties: {
    value: springAppsApiApp.identity.principalId
    contentType: 'string'
  }
}

resource kvSecretSpringDsApiUserName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME'
  properties: {
    value: dbUserName
    contentType: 'string'
  }
}

resource kvSecretSpringDsURL 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-URL'
  properties: {
    value: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    contentType: 'string'
  }
}

resource kvSecretWebAppClientId 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'WEB-APP-CLIENT-ID'
  properties: {
    value: springAppsApiApp.identity.principalId
    contentType: 'string'
  }
}

resource kvSecretWebApiURI 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-URI'
  properties: {
    value: endsWith(springAppsApiApp.properties.url,'/') ? '${springAppsApiApp.properties.url}api/todos/' :  '${springAppsApiApp.properties.url}/api/todos/'
    contentType: 'string'
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  dependsOn: [
    springAppsApiConfig
    springAppsWebConfig
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
  name: 'allowClientIP'
  parent: postgreSQLServer
  properties: {
    endIpAddress: deploymentClientIPAddress
    startIpAddress: deploymentClientIPAddress
  }
}
resource allowAllIPsFirewallRule 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  name: 'allowAllIps'
  parent: postgreSQLServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource postgreSQLServerDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${dbServerName}-db-logs'
  scope: postgreSQLServer
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      // {
      //   categoryGroup: 'audit'
      //   enabled: true
      // }
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

resource springApps 'Microsoft.AppPlatform/Spring@2022-11-01-preview' existing = {
  name: springAppsServiceName
}

resource springAppsDiagnosticsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${springAppsServiceName}-logs'
  scope: springApps
  properties: {
    logs: [
      {
        category: 'ApplicationConsole'
        enabled: true
      }
      {
        category: 'SystemLogs'
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

resource springAppsApiApp 'Microsoft.AppPlatform/Spring/apps@2022-11-01-preview' existing = {
  name: apiAppName
  parent: springApps
}

resource springAppsWebApp 'Microsoft.AppPlatform/Spring/apps@2022-11-01-preview' existing = {
  name: webAppName
  parent: springApps
}

module springAppsApiConfig 'spring-apps-mi-api-service.bicep' = {
  name: 'deployment-spring-apps-mi-api-service'
  dependsOn: [
    springAppsApiApp
    rbacKVSecretApiSpringDsURL
    rbacKVSecretApiSpringDsUserName
    rbacKVSecretApiAppClientId
  ]
  params: {
    apiAppClientId: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretApiAppClientId.name})'
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    apiAppName: apiAppName
    apiAppPort: apiAppPort
    springAppsServiceName: springAppsServiceName
    springDatasourceShowSql: 'true'
    springDatasourceUrl: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDsURL.name})'
    springDatasourceUserName: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDsApiUserName.name})'
    location: location
    tagsArray: tagsArray
  }
}

module springAppsWebConfig 'spring-apps-mi-web-service.bicep' = {
  name: 'deployment-spring-apps-mi-web-service'
  dependsOn: [
    springAppsWebApp
    springAppsApiConfig
    rbacKVSecretWebAppClientId
    rbacKVSecretWebApiURI
  ]
  params: {
    webAppClientId: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretWebAppClientId.name})'
    apiURI: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretWebApiURI.name})'
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    webAppName: webAppName
    webAppPort: webAppPort
    springAppsServiceName: springAppsServiceName
    location: location
    tagsArray: tagsArray
  }
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

module rbacKVSecretApiSpringDsUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-api-spring-ds-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApiApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApiApp.id, kvSecretSpringDsApiUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretSpringDsApiUserName.name
  }
}

module rbacKVSecretApiAppClientId './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-api-app-client-id'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApiApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApiApp.id, kvSecretApiAppClientId.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretApiAppClientId.name
  }
}

module rbacKVSecretApiSpringDsURL './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-api-spring-ds-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApiApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApiApp.id, kvSecretSpringDsURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretSpringDsURL.name
  }
}

module rbacKVSecretWebAppClientId './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-web-app-client-id'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsWebApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsWebApp.id, kvSecretWebAppClientId.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretWebAppClientId.name
  }
}

module rbacKVSecretWebApiURI './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-web-api-uri'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsWebApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsWebApp.id, kvSecretWebApiURI.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretWebApiURI.name
  }
}
