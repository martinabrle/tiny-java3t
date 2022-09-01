param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string

param aksClusterName string
param aksAdminGroupObjectId string

param nodeResoureGroup string = resourceGroup().name
param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceRG)
}

resource aks 'Microsoft.ContainerService/managedClusters@2022-06-02-preview' = {
  name: aksClusterName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    dnsPrefix: 'maabaks'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: 0 //pick VMs default 
        count: 3
        enableAutoScaling: true
        minCount: 3
        maxCount: 5
        vmSize: 'Standard_D4s_v3'
        osType: 'Linux'
        #disable-next-line BCP037
        storageProfile: 'ManagedDisks'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableNodePublicIP: false
        tags: tagsArray
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'kubenet'

    }
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      adminGroupObjectIDs: [ aksAdminGroupObjectId ]
      enableAzureRBAC: true
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
          rotationPollInterval: '2m'
        }
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id 
        }
      }
    }
    nodeResourceGroup: nodeResoureGroup
  }
}
