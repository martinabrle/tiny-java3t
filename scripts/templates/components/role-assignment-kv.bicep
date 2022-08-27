param kvName string
param roleAssignmentNameGuid string
param roleDefinitionId string
param principalId string

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: kvName
}

resource keyVaultWebAppServiceReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentNameGuid
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
