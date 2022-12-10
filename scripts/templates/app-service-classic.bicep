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
@secure()
param dbStagingUserName string
@secure()
param dbStagingUserPassword string

param apiAppServiceName string
param apiAppServicePort string

param webAppServiceName string
param webAppServicePort string

param deploymentClientIPAddress string

param apiHealthCheckPath string = '/'
param webHealthCheckPath string = '/'

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
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

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${apiAppServiceName}-plan'
  location: location
  tags: tagsArray
  properties: {
    reserved: true
  }
  sku: {
    name: 'S2'
  }
  kind: 'linux'
}

resource apiAppService 'Microsoft.Web/sites@2021-03-01' = {
  name: apiAppServiceName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
      healthCheckPath: apiHealthCheckPath
    }
  }
}

resource apiAppServiceStaging 'Microsoft.Web/sites/slots@2021-03-01' = {
  parent: apiAppService
  name: 'staging'
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
    }
  }
}

resource webAppService 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppServiceName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
      healthCheckPath: webHealthCheckPath
    }
  }
}

resource webAppServiceStaging 'Microsoft.Web/sites/slots@2021-03-01' = {
  parent: webAppService
  name: 'staging'
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
    }
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

resource kvApplicationInsightsConnectionString 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'APPLICATIONINSIGHTS-CONNECTION-STRING'
  properties: {
    value: appInsights.properties.ConnectionString
    contentType: 'string'
  }
}

resource kvAppInsightsInstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'APPINSIGHTS-INSTRUMENTATIONKEY'
  properties: {
    value: appInsights.properties.InstrumentationKey
    contentType: 'string'
  }
}

resource kvSpringDataSourceURL 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-URL'
  properties: {
    value: 'jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}'
    contentType: 'string'
  }
}

resource kvDbUserName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME'
  properties: {
    value: dbUserName
    contentType: 'string'
  }
}

resource kvDbUserNameStaging 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-USERNAME-STAGING'
  properties: {
    value: dbStagingUserName
    contentType: 'string'
  }
}

resource kvDbUserPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-PASSWORD'
  properties: {
    value: dbUserPassword
    contentType: 'string'
  }
}

resource kvDbUserPasswordStaging 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-PASSWORD-STAGING'
  properties: {
    value: dbStagingUserPassword
    contentType: 'string'
  }
}

resource kvApiUri 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-URI'
  properties: {
    value: 'https://${apiAppServiceName}.azurewebservices.net/api/'
    contentType: 'string'
  }
}

resource kvApiUriStaging 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-URI-STAGING'
  properties: {
    value: 'https://${apiAppServiceName}-staging.azurewebservices.net/api/'
    contentType: 'string'
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  dependsOn: [
    apiAppService
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

resource apiAppServiceDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${apiAppServiceName}-app-logs'
  scope: apiAppService
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

resource webAppServiceDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppServiceName}-app-logs'
  scope: webAppService
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

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

module rbacKVApplicationInsightsConnectionString './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-con-str'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvApplicationInsightsConnectionString.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApplicationInsightsConnectionString.name
  }
}

module rbacKVAppInsightsInstrKey './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-instr'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppInsightsInstrumentationKey.name
  }
}

module rbacKVSpringDataSourceURL './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-spring-datasource-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSpringDataSourceURL.name
  }
}

module rbacKVDbUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-db-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvDbUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvDbUserName.name
  }
}

module rbacKVDbUserNameStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-db-user-name-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(apiAppServiceStaging.id, kvDbUserNameStaging.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvDbUserNameStaging.name
  }
}

module rbacKVDbUserPassword './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-db-user-password'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvDbUserPassword.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvDbUserPassword.name
  }
}

module rbacKVDbUserPasswordStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-db-user-password-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvDbUserPasswordStaging.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvDbUserPasswordStaging.name
  }
}

module rbacKVApplicationInsightsConnectionStringStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-con-str-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(apiAppServiceStaging.id, kvApplicationInsightsConnectionString.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApplicationInsightsConnectionString.name
  }
}

module rbacKVAppInsightsInstrKeyStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-instr-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(apiAppServiceStaging.id, kvAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppInsightsInstrumentationKey.name
  }
}

module rbacKVSpringDataSourceURLStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-spring-datasource-url-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(apiAppServiceStaging.id, kvSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSpringDataSourceURL.name
  }
}

module rbacKVWebApplicationInsightsConnectionString './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-con-str-web'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppService.identity.principalId
    roleAssignmentNameGuid: guid(webAppService.id, kvApplicationInsightsConnectionString.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApplicationInsightsConnectionString.name
  }
}

module rbacKVWebAppInsightsInstrKey './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-instr-web'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppService.identity.principalId
    roleAssignmentNameGuid: guid(webAppService.id, kvAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppInsightsInstrumentationKey.name
  }
}

module rbacKVWebApiUri './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-api-uri-web'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppService.identity.principalId
    roleAssignmentNameGuid: guid(webAppService.id, kvApiUri.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApiUri.name
  }
}

module rbacKVWebApplicationInsightsConnectionStringStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-con-str-web-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(webAppServiceStaging.id, kvApplicationInsightsConnectionString.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApplicationInsightsConnectionString.name
  }
}

module rbacKVWebAppInsightsInstrKeyStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-insights-instr-web-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(webAppServiceStaging.id, kvAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppInsightsInstrumentationKey.name
  }
}

module rbacKVWebApiUriStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-api-uri-web-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: webAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(webAppServiceStaging.id, kvApiUri.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApiUri.name
  }
}

resource apiAppServiceSlotConfigNames 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'slotConfigNames'
  kind: 'string'
  parent: apiAppService
  dependsOn: [apiAppServicePARMS]
  properties: {
    appSettingNames: [
      'SPRING_DATASOURCE_URL', 'SPRING_DATASOURCE_USERNAME', 'SPRING_DATASOURCE_APP_CLIENT_ID', 'APPLICATIONINSIGHTS_CONNECTION_STRING', 'APPINSIGHTS_INSTRUMENTATIONKEY', 'SPRING_PROFILES_ACTIVE', 'PORT', 'SPRING_DATASOURCE_SHOW_SQL', 'DEBUG_AUTH_TOKEN'
    ]
  }
}

resource apiAppServicePARMS 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'web'
  parent: apiAppService
  kind: 'string'
  dependsOn: [
    rbacKVAppInsightsInstrKey
    rbacKVApplicationInsightsConnectionString
    rbacKVDbUserName
    rbacKVDbUserPassword
    rbacKVSpringDataSourceURL
  ]
  properties: {
    appSettings: [
      {
        name: 'SPRING_DATASOURCE_URL'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSpringDataSourceURL.name})'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvDbUserName.name})'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvDbUserPassword.name})'
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApplicationInsightsConnectionString.name})'
      }
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppInsightsInstrumentationKey.name})'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'test'
      }
      {
        name: 'PORT'
        value: apiAppServicePort
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'true'
      }
    ]
  }
}

resource apiAppServiceStagingPARMS 'Microsoft.Web/sites/slots/config@2022-03-01' = {
  name: 'web'
  parent: apiAppServiceStaging
  dependsOn: [
    apiAppServiceSlotConfigNames
    rbacKVAppInsightsInstrKeyStaging
    rbacKVApplicationInsightsConnectionStringStaging
    rbacKVDbUserNameStaging
    rbacKVDbUserPasswordStaging
    rbacKVSpringDataSourceURLStaging
  ]
  kind: 'string'
  properties: {
    appSettings: [
      {
        name: 'SPRING_DATASOURCE_URL'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSpringDataSourceURL.name})'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvDbUserNameStaging.name})'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvDbUserPasswordStaging.name})'
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApplicationInsightsConnectionString.name})'
      }
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppInsightsInstrumentationKey.name})'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'test'
      }
      {
        name: 'PORT'
        value: apiAppServicePort
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'true'
      }
    ]
  }
}

resource webAppServiceSlotConfigNames 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'slotConfigNames'
  kind: 'string'
  parent: webAppService
  dependsOn: [webAppServicePARMS]
  properties: {
    appSettingNames: [
      'APPLICATIONINSIGHTS_CONNECTION_STRING', 'APPINSIGHTS_INSTRUMENTATIONKEY', 'API_URI', 'SPRING_PROFILES_ACTIVE', 'PORT', 'DEBUG_AUTH_TOKEN'
    ]
  }
}

resource webAppServicePARMS 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'web'
  parent: webAppService
  dependsOn: [
    rbacKVWebAppInsightsInstrKey
    rbacKVWebApplicationInsightsConnectionString
    rbacKVWebApiUri
  ]
  kind: 'string'
  properties: {
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApplicationInsightsConnectionString.name})'
      }
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppInsightsInstrumentationKey.name})'
      }
      {
        name: 'API_URI'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApiUriStaging.name})'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'test-mi'
      }
      {
        name: 'PORT'
        value: apiAppServicePort
      }
      {
        name: 'DEBUG_AUTH_TOKEN'
        value: 'true'
      }
    ]
  }
}

resource webAppServiceStagingPARMS 'Microsoft.Web/sites/slots/config@2021-03-01' = {
  name: 'web'
  parent: webAppServiceStaging
  dependsOn: [
    webAppServiceSlotConfigNames
    rbacKVWebAppInsightsInstrKeyStaging
    rbacKVWebApplicationInsightsConnectionStringStaging
    rbacKVWebApiUriStaging
  ]
  kind: 'string'
  properties: {
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApplicationInsightsConnectionString.name})'
      }
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppInsightsInstrumentationKey.name})'
      }
      {
        name: 'API_URI'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApiUriStaging.name})'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'test-mi'
      }
      {
        name: 'PORT'
        value: webAppServicePort
      }
      {
        name: 'DEBUG_AUTH_TOKEN'
        value: 'true'
      }
    ]
  }
}
