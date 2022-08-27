param keyVaultName string
param dbServerName string
param dbName string

@secure()
param dbAdminName string
@secure()
param dbAdminPassword string

@secure()
param dbUserName string
@secure()
param dbUserPassword string

param clientIPAddress string
param appServiceName string
param appServicePort string

param location string = resourceGroup().location
param tagsArray object = resourceGroup().tags

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
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

resource postgreSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2021-06-01-preview' = {
  name: dbServerName
  location: location
  tags: tagsArray
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: dbAdminName
    administratorLoginPassword: dbAdminPassword
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
      standbyAvailabilityZone: ''
    }
    network: {
      delegatedSubnetResourceId: ''
      privateDnsZoneArmResourceId: ''
    }
    storage: {
      storageSizeGB: 32
    }
    version: '13'
  }
}

resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2021-06-01' = {
  name: dbName
  parent: postgreSQLServer
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

resource allowClientIPFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2021-06-01' = {
  name: 'allowClientIP'
  parent: postgreSQLServer
  properties: {
    endIpAddress: clientIPAddress
    startIpAddress: clientIPAddress
  }
}

resource allowAllIPsFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2021-06-01' = {
  name: 'allowAllIps'
  parent: postgreSQLServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource apiServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${appServiceName}-plan'
  location: location
  tags: tagsArray
  properties: {
    reserved: true
  }
  sku: {
    name: 'S1'
  }
  kind: 'linux'
}

resource apiService 'Microsoft.Web/sites@2021-03-01' = {
  name: appServiceName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: apiServicePlan.id
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      healthCheckPath: '/health'
      scmType: 'None'
    }
  }
}

resource apiServicePARMS 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'web'
  parent: apiService
  dependsOn: [
    rbacKVSecretApiSpringDataSourceURL
    rbacKVSecretApiSpringDatasourceUserName
    rbacKVSecretApiSpringDatasourceUserPassword
  ]
  kind: 'string'
  properties: {
    appSettings: [
      {
        name: 'PORT'
        value: appServicePort
      }
      {
        name: 'SPRING_DATASOURCE_URL'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=SPRING-DATASOURCE-URL)'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=SPRING-DATASOURCE-USERNAME)'
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=SPRING-DATASOURCE-PASSWORD)'
      }
      {
        name: 'SPRING_DATASOURCE_SHOW_SQL'
        value: 'true'
      }
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'test-mi'
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

module rbacKVSecretApiSpringDatasourceUserName './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-api-spring-datasource-user-name'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiService.identity.principalId
    roleAssignmentNameGuid: guid(apiService.id, keyVaultSecretSpringDatasourceUserName.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDatasourceUserName.name
  }
}

module rbacKVSecretApiSpringDatasourceUserPassword './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-api-spring-datasource-user-password'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiService.identity.principalId
    roleAssignmentNameGuid: guid(apiService.id, keyVaultSecretSpringDatasourceUserPassword.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDatasourceUserPassword.name
  }
}

module rbacKVSecretApiSpringDataSourceURL './components/role-assignment-kv-secret.bicep' = {
  name: 'deployment-rbac-kv-secret-api-spring-datasource-url'
  params: {
    roleDefinitionId: keyVaultSecretsUser.id
    principalId: apiService.identity.principalId
    roleAssignmentNameGuid: guid(apiService.id, keyVaultSecretSpringDataSourceURL.id, keyVaultSecretsUser.id)
    kvName: keyVault.name
    kvSecretName: keyVaultSecretSpringDataSourceURL.name
  }
}
