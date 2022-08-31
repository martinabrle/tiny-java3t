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
@secure()
param dbUserPassword string

param deploymentClientIPAddress string

param springAppsServiceName string

param appName string
param appPort string
param springDatasourceShowSql string = 'true'
param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
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
  }
}

resource keyVaultSecretSpringDatasourceUserName 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME'
  properties: {
    value: dbUserName
    contentType: 'string'
  }
}
resource keyVaultSecretSpringDatasourceUserPassword 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-PASSWORD'
  properties: {
    value: dbUserPassword
    contentType: 'string'
  }
}

resource keyVaultSecretSpringDataSourceURL 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-URL'
  properties: {
    value: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    contentType: 'string'
  }
}

resource keyVaultSecretAppInsightsKey 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'APPLICATIONINSIGHTS-CONNECTION-STRING'
  properties: {
    value: appInsights.properties.ConnectionString
    contentType: 'string'
  }
}

resource keyVaultSecretAppInsightsInstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'APPINSIGHTS-INSTRUMENTATIONKEY'
  properties: {
    value: appInsights.properties.InstrumentationKey
    contentType: 'string'
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  dependsOn: [
    springAppsAppDeployment
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

resource springAppsApp 'Microsoft.AppPlatform/Spring/apps@2022-05-01-preview' = {
  name: appName
  location: location
  parent: springApps
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: false
    public: true
    fqdn: '${springAppsServiceName}-${appName}.azuremicroservices.io'
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
  dependsOn: [
    rbacKVAppSpringDatasourceURL
    rbacKVAppSpringDatasourceUserName
    rbacKVAppSpringDatasourceUserPassword
    rbacKVAppAppInsightsKey
    rbacKVAppAppInsightsInstrumentationKey
  ]
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
        PORT: appPort
        SPRING_DATASOURCE_URL: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
        SPRING_DATASOURCE_USERNAME: '${dbUserName}@${dbServerName}'
        SPRING_DATASOURCE_PASSWORD: dbUserPassword
        APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
        APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
        SPRING_PROFILES_ACTIVE: 'test'
        SPRING_DATASOURCE_SHOW_SQL: springDatasourceShowSql
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

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

module rbacKVAppSpringDatasourceUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-app-apring-datasource-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApp.id, keyVaultSecretSpringDatasourceUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDatasourceUserName.name
  }
}

module rbacKVAppSpringDatasourceUserPassword './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-app-apring-datasource-user-password'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApp.id, keyVaultSecretSpringDatasourceUserPassword.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDatasourceUserPassword.name
  }
}

module rbacKVAppSpringDatasourceURL './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-app-apring-datasource-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApp.id, keyVaultSecretSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDataSourceURL.name
  }
}

module rbacKVAppAppInsightsKey './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-app-app-insights-key'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApp.id, keyVaultSecretAppInsightsKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretAppInsightsKey.name
  }
}

module rbacKVAppAppInsightsInstrumentationKey './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-app-app-insights-instrumentation-key'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApp.id, keyVaultSecretAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretAppInsightsInstrumentationKey.name
  }
}
