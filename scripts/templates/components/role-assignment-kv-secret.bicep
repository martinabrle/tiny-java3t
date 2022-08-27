param kvName string
param kvSecretName string
param roleAssignmentNameGuid string
param roleDefinitionId string
param principalId string

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' existing = {
  name: '${kvName}/${kvSecretName}'
}

resource keyVaultWebAppServiceReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentNameGuid
  scope: keyVaultSecret
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
