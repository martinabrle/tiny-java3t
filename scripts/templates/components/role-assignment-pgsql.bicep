param postgreSQLServerName string
param roleAssignmentNameGuid string
param roleDefinitionId string
param principalId string

resource postgreSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2021-06-01-preview' existing = {
  name: postgreSQLServerName
}

resource keyVaultWebAppServiceReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentNameGuid
  scope: postgreSQLServer
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
