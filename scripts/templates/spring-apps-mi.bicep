param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param appInsightsName string

param keyVaultName string
param dbServerName string

param dbServerAADAdminGroupObjectId string
param dbServerAADAdminGroupName string

param dbName string

@secure()
param dbAdminName string
@secure()
param dbAdminPassword string
@secure()
param dbUserName string
param apiAppClientId string = ''
param webAppClientId string = ''
@secure()
param dbUserPassword string

param springAppsServiceName string

param apiAppName string
param apiAppPort string

param webAppName string
param webAppPort string

param deploymentClientIPAddress string

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
resource postgreSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: dbServerName
  location: location
  tags: tagsArray
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    version: '14'
    storage: {
      storageSizeGB: 32
    }

    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    administratorLogin: dbAdminName
    administratorLoginPassword: dbAdminPassword
  }
}

resource postgreSQLServerAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  parent: postgreSQLServer
  name: dbServerAADAdminGroupObjectId
  dependsOn: [
    postgreSQLDatabase
    postgreSQLServerDiagnotsicsLogs
  ]
  properties: {
    principalType: 'Group'
    principalName: dbServerAADAdminGroupName
    tenantId: subscription().tenantId
  }
}

resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgreSQLServer
  name: dbName
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

resource allowClientIPFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  name: 'AllowDeploymentClientIP'
  parent: postgreSQLServer
  properties: {
    endIpAddress: deploymentClientIPAddress
    startIpAddress: deploymentClientIPAddress
  }
}

resource allowAllIPsFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: postgreSQLServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
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

resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
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

resource kvSecretApiAppClientId 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'API-APP-CLIENT-ID'
  properties: {
    value: apiAppClientId
    contentType: 'string'
  }
}

resource kvSecretWebAppClientId 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'WEB-APP-CLIENT-ID'
  properties: {
    value: webAppClientId
    contentType: 'string'
  }
}

resource kvSecretSpringDsApiUserName 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME'
  properties: {
    value: dbUserName
    contentType: 'string'
  }
}

resource kvSecretSpringDsApiUserPassword 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-PASSWORD'
  properties: {
    value: dbUserPassword
    contentType: 'string'
  }
}

resource kvSecretSpringDsURL 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-URL'
  properties: {
    value: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    contentType: 'string'
  }
}

resource kvSecretWebApiURI 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  parent: keyVault
  name: 'API-URI'
  properties: {
    value: endsWith(springAppsApiApp.properties.url, '/') ? '${springAppsApiApp.properties.url}api/todos/' : '${springAppsApiApp.properties.url}/api/todos/'
    contentType: 'string'
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  dependsOn: [
    springAppsApiAppDeployment
    springAppsWebAppDeployment
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

resource springApps 'Microsoft.AppPlatform/Spring@2023-01-01-preview' = {
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

resource springAppsApiApp 'Microsoft.AppPlatform/Spring/apps@2023-01-01-preview' = {
  name: apiAppName
  location: location
  parent: springApps
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: false
    public: true
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

resource springAppsWebApp 'Microsoft.AppPlatform/Spring/apps@2023-01-01-preview' = {
  name: webAppName
  location: location
  parent: springApps
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: false
    public: true
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

resource springAppsWebAppDeployment 'Microsoft.AppPlatform/Spring/apps/deployments@2023-01-01-preview' = {
  name: 'default'
  parent: springAppsWebApp
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
        APP_CLIENT_ID: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretWebAppClientId.name})'
        API_URI: 'http://${springAppsApiApp.properties.fqdn}/'
        APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
        APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
      }
    }
    // source: any({
    //   type: 'Jar'
    //   relativePath: '<default>'
    //   runtimeVersion: 'Java_11'
    //   version: 'Java_11'
    // })
    source: {
      type: 'Jar'
      runtimeVersion: 'Java_11'
      version: 'Java_11'
    }
    active: true
  }
}

resource springAppsApiAppDeployment 'Microsoft.AppPlatform/Spring/apps/deployments@2023-01-01-preview' = {
  name: 'default'
  parent: springAppsApiApp
  dependsOn: [
    rbacKVSecretApiSpringDsURL
    rbacKVSecretApiSpringDsUserName
    rbacKVSecretApiAppClientId
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
        PORT: apiAppPort
        APP_CLIENT_ID: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretApiAppClientId.name})'
        APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
        APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
        SPRING_DATASOURCE_URL: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDsURL.name})'
        SPRING_DATASOURCE_USERNAME: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDsApiUserName.name})'
        SPRING_PROFILES_ACTIVE: 'test-mi'
        SPRING_DATASOURCE_SHOW_SQL: 'true'
      }

    }
    // source: any({
    //   type: 'Jar'
    //   relativePath: '<default>'
    //   runtimeVersion: 'Java_11'
    //   version: 'Java_11'
    // })
    source: {
      type: 'Jar'
      runtimeVersion: 'Java_11'
      version: 'Java_11'
    }
    active: true
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

module rbacKVSecretApiSpringDsUserPassword './components/role-assignment-kv-secret.bicep' = {
  name: 'rbac-kv-secret-api-spring-ds-user-password'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: springAppsApiApp.identity.principalId
    roleAssignmentNameGuid: guid(springAppsApiApp.id, kvSecretSpringDsApiUserPassword.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretSpringDsApiUserPassword.name
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
