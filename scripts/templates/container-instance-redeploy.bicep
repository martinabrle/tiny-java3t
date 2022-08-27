param appInsightsName string

param keyVaultName string
param dbServerName string
param dbName string

param dbUserName string

param deploymentClientIPAddress string

param containerRegistryName string
param containerInstanceName string
param containerInstanceIdentityName string = '${containerInstanceName}-identity'
param containerAppName string
param containerAppPort string
param containerImageName string

param appSpringProfile string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource containerUserManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: containerInstanceIdentityName
}

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2021-10-01' existing = {
  name: containerInstanceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
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
    value: containerInstance.identity.principalId
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

module rbacKVSpringDataSourceURL './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-app-spring-datasource-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: containerInstance.identity.principalId
    roleAssignmentNameGuid: guid(containerInstance.id, kvSecretSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretSpringDataSourceURL.name
  }
}

module rbacKVSecretAppClientId './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-app-client-id'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: containerInstance.identity.principalId
    roleAssignmentNameGuid: guid(containerInstance.id, kvSecretAppClientId.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretAppClientId.name
  }
}

module rbacKVSecretDbUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-db-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: containerInstance.identity.principalId
    roleAssignmentNameGuid: guid(containerInstance.id, kvSecretDbUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: kvSecretDbUserName.name
  }
}

module containerInstanceConfig 'container-instance-service.bicep' = {
  name: 'deployment-container-instance-core'
  params: {
    containerInstanceName: containerInstanceName
    appClientId: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretAppClientId.name})'
    containerAppName: containerAppName
    containerImage: containerImageName
    containerInstanceIdentityName: containerUserManagedIdentity.name
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    springDatasourceUrl: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretSpringDataSourceURL.name})'
    springDatasourceUserName: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${kvSecretDbUserName.name})'
    springDatasourceShowSql: 'true'
    containerAppPort: containerAppPort
    appSpringProfile: appSpringProfile
    location: location
    tagsArray: tagsArray
  }
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: keyVault
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}
