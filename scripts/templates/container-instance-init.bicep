param containerInstanceName string
param containerInstanceIdentityName string = '${containerInstanceName}-identity'
param containerAppName string
param containerAppPort string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = {
  name: containerInstanceName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    sku: 'Standard'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: int(containerAppPort)
        }
      ]
      dnsNameLabel: replace(replace(containerInstanceName,'-',''),'_','')
    }
    containers: [
      {
        name: containerAppName
        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'
          environmentVariables: [
            {
              name: 'PORT'
              value: string(containerAppPort)
            }
            {
              name: 'DEBUG_AUTH_TOKEN'
              value: 'true'
            }
          ]
          ports: [
            {
              port: int(containerAppPort)
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
  }
}

// For some weird reason, when I deploy a managed identity before the container instance, deployment fails
// This is why the deployment is split into two separate bicep templates for the same container instance,
// where the params need to be synced manually (between this one and ...instance-service.bicep)
resource containerUserManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: containerInstanceIdentityName
  dependsOn: [
    containerInstance
  ]
  location: location
  tags: tagsArray
}
