param appInsightsName string
param keyVaultName string
param dbServerName string
param dbName string

param appServiceName string
@secure()
param dbUserName string
@secure()
param dbUserPassword string
param appServicePort string

param appSpringProfile string

resource appService 'Microsoft.Web/sites@2021-03-01' existing = {
  name: appServiceName
  scope: resourceGroup()
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup()
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

resource kvApplicationInsightsConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'APPLICATIONINSIGHTS-CONNECTION-STRING'
  properties: {
    value: appInsights.properties.ConnectionString
    contentType: 'string'
  }
}

resource kvSecretAppInsightsInstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'APPINSIGHTS-INSTRUMENTATIONKEY'
  properties: {
    value: appInsights.properties.InstrumentationKey
    contentType: 'string'
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

resource kvSecretApiURI 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'API-URI'
  properties: {
    value: 'https://${appServiceName}.azurewebsites.net/todos/'
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


resource appServicePARMS 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'web'
  parent: appService
  dependsOn: [
    rbacKVSpringDataSourceURL
    rbacKVApplicationInsightsConnectionString
    rbacKVAppInsightsInstrKey
    rbacKVSecretDbUserName
    rbacKVSecretDbUserPassword
  ]
  kind: 'string'
  properties: {
    appSettings: [
      {
        name: 'PORT'
        value: appServicePort
      }
      {
        name: replace(kvSecretSpringDataSourceURL.name,'-','_')
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDataSourceURL.name})'
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'false'
      }
      {
        name: replace(kvSecretDbUserName.name, '-', '_')
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretDbUserName.name})'
      }
      {
        name: replace(kvSecretDbUserPassword.name, '-', '_')
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretDbUserPassword.name})'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: appSpringProfile
      }
      {
        name: replace(kvApplicationInsightsConnectionString.name,'-','_')
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvApplicationInsightsConnectionString.name})'
      }
      {
        name: replace(kvSecretAppInsightsInstrumentationKey.name,'-','_')
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretAppInsightsInstrumentationKey.name})'
      }
      {
        name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
        value: 'false'
      }
    ]
  }
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}


module rbacKVApplicationInsightsConnectionString './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-app-insights-con-str'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: appService.identity.principalId
    roleAssignmentNameGuid: guid(appService.id, kvApplicationInsightsConnectionString.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvApplicationInsightsConnectionString.name
  }
}

module rbacKVAppInsightsInstrKey './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-app-insights-instr'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: appService.identity.principalId
    roleAssignmentNameGuid: guid(appService.id, kvSecretAppInsightsInstrumentationKey.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretAppInsightsInstrumentationKey.name
  }
}

module rbacKVSpringDataSourceURL './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-app-spring-datasource-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: appService.identity.principalId
    roleAssignmentNameGuid: guid(appService.id, kvSecretSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretSpringDataSourceURL.name
  }
}

module rbacKVSecretDbUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-db-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: appService.identity.principalId
    roleAssignmentNameGuid: guid(appService.id, kvSecretDbUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretDbUserName.name
  }
}

module rbacKVSecretDbUserPassword './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-db-user-password'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: appService.identity.principalId
    roleAssignmentNameGuid: guid(appService.id, kvSecretDbUserPassword.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretDbUserPassword.name
  }
}
