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
@secure()
param dbStagingUserName string
param appClientId string = ''
param stagingAppClientId string = ''

param apiAppServiceName string
param apiAppServicePort string

param webAppServiceName string
param webAppServicePort string

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
  name: '20de3c04-d6a6-483d-a88e-edf44e6c437d'
  properties: {
    principalType:  'Group'
    principalName: dbServerAADAdminGroupName
    tenantId: tenant().tenantId
  }
}

resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgreSQLServer
  name: dbName
  dependsOn: [
    postgreSQLServerAdmin
  ]
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
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

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
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

resource apiAppService 'Microsoft.Web/sites@2022-03-01' = {
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

resource apiAppServiceStaging 'Microsoft.Web/sites/slots@2022-03-01' = {
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

resource webAppService 'Microsoft.Web/sites@2022-03-01' = {
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

resource webAppServiceStaging 'Microsoft.Web/sites/slots@2022-03-01' = {
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

resource kvSecretDbAdminPassword 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'DB-ADMIN-PASSWORD'
  properties: {
    value: dbAdminPassword
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

resource kvAppClientId 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-APP-CLIENT-ID'
  properties: {
    value: appClientId
    contentType: 'string'
  }
}

resource kvAppClientIdStaging 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SPRING-DATASOURCE-APP-CLIENT-ID-STAGING'
  properties: {
    value: stagingAppClientId
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

resource kvApiUri 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-URI'
  properties: {
    value: 'https://${apiAppServiceName}.azurewebsites.net/api/todos/'
    contentType: 'string'
  }
}

resource kvApiUriStaging 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'API-URI-STAGING'
  properties: {
    value: 'https://${apiAppServiceName}-staging.azurewebsites.net/api/todos/'
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

module rbacKVAppClientId './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-client-id'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppService.identity.principalId
    roleAssignmentNameGuid: guid(apiAppService.id, kvAppClientId.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppClientId.name
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

module rbacKVAppClientIdStaging './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-app-client-id-stg'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiAppServiceStaging.identity.principalId
    roleAssignmentNameGuid: guid(apiAppServiceStaging.id, kvAppClientIdStaging.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvAppClientIdStaging.name
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
    roleAssignmentNameGuid: guid(webAppServiceStaging.id, kvApiUriStaging.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApiUriStaging.name
  }
}

resource apiAppServiceSlotConfigNames 'Microsoft.Web/sites/config@2022-03-01' = {
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
    rbacKVAppClientId
    rbacKVDbUserName
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
        name: 'SPRING_DATASOURCE_APP_CLIENT_ID'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppClientId.name})'
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
        value: 'test-mi'
      }
      {
        name: 'PORT'
        value: apiAppServicePort
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'true'
      }
      {
        name: 'DEBUG_AUTH_TOKEN'
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
    rbacKVAppClientIdStaging
    rbacKVDbUserNameStaging
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
        name: 'SPRING_DATASOURCE_APP_CLIENT_ID'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvAppClientIdStaging.name})'
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
        value: 'test-mi'
      }
      {
        name: 'PORT'
        value: apiAppServicePort
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'true'
      }
      {
        name: 'DEBUG_AUTH_TOKEN'
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
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApiUri.name})'
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
