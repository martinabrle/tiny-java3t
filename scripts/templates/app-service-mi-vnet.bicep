param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param appInsightsName string

param keyVaultName string
param dbServerName string

param dbServerAADAdminGroupObjectId string
param dbServerAADAdminGroupName string

param dbName string

param bastionName string
param managementVMName string
@secure()
param managementVMAdminName string
@secure()
param managementVMAdminPassword string
param ghRunnerVMName string
@secure()
param ghRunnerVMAdminName string
@secure()
param ghRunnerVMAdminPassword string
// @secure()
// param dbAdminName string
// @secure()
// param dbAdminPassword string
@secure()
param dbUserName string
@secure()
param dbStagingUserName string
@secure()
param appClientId string = ''
@secure()
param stagingAppClientId string = ''

param apiAppServiceName string
param apiAppServicePort string

param webAppServiceName string
param webAppServicePort string

param apiHealthCheckPath string = '/'
param webHealthCheckPath string = '/'

param ghRunnerToken string
param ghOrganization string = 'martinabrle'
param ghRepository string = 'tiny-java3t'
param ghRunnerVersion string = '2.303.0'

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceRG)
}

var vnetAddressPrefix = '10.0.0.0/16'

var webAppSubnetAddressPrefix = '10.0.1.0/24'
var apiAppSubnetAddressPrefix = '10.0.2.0/24'

var dbSubnetAddressPrefix = '10.0.20.0/24'

var bastionSubnetAddressPrefix = '10.0.60.0/24'
var mgmtSubnetAddressPrefix = '10.0.61.0/24'
var ghRunnerSubnetAddressPrefix = '10.0.62.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${apiAppServiceName}-vnet'
  location: location
  tags: tagsArray
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'web'
        properties: {
          addressPrefix: webAppSubnetAddressPrefix
        }
      }
      {
        name: 'api'
        properties: {
          addressPrefix: apiAppSubnetAddressPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'mgmt'
        properties: {
          addressPrefix: mgmtSubnetAddressPrefix
        }
      }
      {
        name: 'ghrunner'
        properties: {
          addressPrefix: ghRunnerSubnetAddressPrefix
        }
      }
      {
        name: 'db'
        properties: {
          addressPrefix: dbSubnetAddressPrefix //'10.0.8.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                'eastus'
                'westus'
                'westus3'
              ]
            }
          ]
          delegations: [
            {
              name: 'dlg-Microsoft.DBforPostgreSQL-flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
  }
}

resource dbSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'db'
}

resource apiSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'api'
}

resource webSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'web'
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'AzureBastionSubnet'
}

resource mgmtSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'mgmt'
}

resource ghRunnerSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: 'ghrunner'
}

resource publicIpAddressForBastion 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: '${bastionName}-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: publicIpAddressForBastion.id
          }
        }
      }
    ]
  }
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
  dependsOn: [
    privateDNSZonePostgresqlServerNetworkLink
  ]
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
      passwordAuth: 'Disabled' // 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    // administratorLogin: dbAdminName
    // administratorLoginPassword: dbAdminPassword
    network: {
      delegatedSubnetResourceId: dbSubnet.id
      privateDnsZoneArmResourceId: privateDNSZonePostgresqlServer.id
    }
  }
}

resource postgreSQLServerAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  parent: postgreSQLServer
  name: dbServerAADAdminGroupObjectId
  properties: {
    principalType: 'Group'
    principalName: dbServerAADAdminGroupName
    tenantId: subscription().tenantId
  }
}

// resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
//   parent: postgreSQLServer
//   name: dbName
//   dependsOn: [
//     postgreSQLServerAdmin
//   ]
//   properties: {
//     charset: 'utf8'
//     collation: 'en_US.utf8'
//   }
// }

//TODO: does the VNET integration create a NIC automatically?
// resource privateEndpointPostgresqlServer 'Microsoft.Network/privateEndpoints@2022-07-01' = {
//   location: location
//   name: '${dbServerName}-private-endpoint'
//   tags: tagsArray
//   properties: {
//     subnet: {
//       id: dbSubnet.id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${dbServerName}-private-endpoint'
//         properties: {
//           privateLinkServiceId: postgreSQLServer.id
//           //todo:review
//           groupIds: [ 'postgresqlFlexibleServer' ]
//         }
//       }
//     ]
//     customNetworkInterfaceName: '${dbServerName}-private-endpoint-nic'
//   }
// }

resource privateEndpointApiAppService 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  location: location
  name: '${apiAppServiceName}-private-endpoint'
  tags: tagsArray
  properties: {
    subnet: {
      id: apiSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: '${apiAppServiceName}-private-endpoint'
        properties: {
          privateLinkServiceId: apiAppService.id
          groupIds: [ 'sites' ]
        }
      }
    ]
    customNetworkInterfaceName: '${apiAppServiceName}-private-endpoint-nic'
  }
}

resource privateEndpointWebAppService 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  location: location
  name: '${webAppServiceName}-private-endpoint'
  tags: tagsArray
  properties: {
    subnet: {
      id: webSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: '${webAppServiceName}-private-endpoint'
        properties: {
          privateLinkServiceId: webAppService.id
          groupIds: [ 'sites' ]
        }
      }
    ]
    customNetworkInterfaceName: '${webAppServiceName}-private-endpoint-nic'
  }
}

resource privateDNSZonePostgresqlServer 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${dbServerName}.private.postgres.database.azure.com'
  location: 'global'
  tags: tagsArray
}

resource privateDNSZoneAppService 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: tagsArray
}

resource privateDNSZonePostgresqlServerNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZonePostgresqlServer
  name: 'gsqra4itxbbtglink'
  location: 'global'
  tags: tagsArray
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateLinkDNSZoneAppService 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZoneAppService
  name: 'link'
  location: 'global'
  tags: tagsArray
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource pvtEndpointDnsGroupApiAppService 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  parent: privateEndpointApiAppService
  //name: '${privateEndpointApiAppService.name}/default'
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'api-privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privateDNSZoneAppService.id
        }
      }
    ]
  }
}

resource pvtEndpointDnsGroupWebAppService 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  parent: privateEndpointWebAppService
  //name: '${privateEndpointWebAppService.name}/default'
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'web-privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privateDNSZoneAppService.id
        }
      }
    ]
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
    //virtualNetworkSubnetId: vnet.properties.subnets[0].id
    httpsOnly: true

    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
      healthCheckPath: apiHealthCheckPath
      vnetRouteAllEnabled: true
      http20Enabled: true
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
    //virtualNetworkSubnetId: vnet.properties.subnets[0].id
    httpsOnly: true

    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
      scmType: 'None'
      healthCheckPath: webHealthCheckPath
      vnetRouteAllEnabled: true
      http20Enabled: true
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

resource kvSecretGHRunnerVMAdminName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'GH-RUNNER-VM-ADMIN-NAME'
  properties: {
    value: ghRunnerVMAdminName
    contentType: 'string'
  }
}

resource kvSecretGHRunnerVMAdminPwd 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'GH-RUNNER-VM-ADMIN-PWD'
  properties: {
    value: ghRunnerVMAdminPassword
    contentType: 'string'
  }
}

resource kvSecretMgmtVMAdminName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'MGMT-VM-ADMIN-NAME'
  properties: {
    value: managementVMAdminName
    contentType: 'string'
  }
}

resource kvSecretMgmtVMAdminPwd 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'MGMT-VM-ADMIN-PWD'
  properties: {
    value: managementVMAdminPassword
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
  dependsOn: [ apiAppServicePARMS ]
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
        value: 'local' // as we do not have an access to the database from the staging slot,
        // here I will only run the tests against the local in-memory storage.
        // If I will ever get to deploying my own GitHub runner into the VNET,
        // than this can be changed again to 'test-mi'
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
  dependsOn: [ webAppServicePARMS ]
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

//Management VM
resource managementVMNIC 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${managementVMName}-nic'
  location: location
  tags: tagsArray
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: mgmtSubnet.id
          }
        }
      }
    ]
  }
}

resource managementVM 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: managementVMName
  location: location
  tags: tagsArray
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS3_v2'
    }
    osProfile: {
      computerName: managementVMName
      windowsConfiguration: {
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'Always'
          }
          enableHotpatching: false
          patchMode: 'AutomaticByPlatform'
        }

      }
      adminUsername: managementVMAdminName
      adminPassword: managementVMAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'ReadOnly'
        diffDiskSettings: {
          option: 'Local'
          placement: 'CacheDisk'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: managementVMNIC.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Server'
  }
}

resource ghRunnerVMNIC 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${ghRunnerVMName}-nic'
  location: location
  tags: tagsArray
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: ghRunnerSubnet.id
          }
        }
      }
    ]
  }
}

var ghRunnerCloudInitCustomData = loadTextContent('./gh-runner-cloud-init.yml')
var ghRunnerFinalCloudInitCustomData = format(ghRunnerCloudInitCustomData, ghRunnerVersion, ghRunnerVMAdminName,'${ghOrganization}/${ghRepository}', ghRunnerToken)

resource ghRunnerVM 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: ghRunnerVMName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B12ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'ReadOnly'
        diffDiskSettings: {
          option: 'Local'
          placement: 'CacheDisk'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: ghRunnerVMName
      adminUsername: ghRunnerVMAdminName
      adminPassword: ghRunnerVMAdminPassword
      customData: base64(ghRunnerFinalCloudInitCustomData)
      linuxConfiguration: {
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'Always'
          }
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: ghRunnerVMNIC.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

output cloudInit string = base64(ghRunnerFinalCloudInitCustomData)
