param containerInstanceName string
param containerInstanceIdentityName string
param appClientId string
param containerAppName string
param containerImage string
param appInsightsConnectionString string
param appInsightsInstrumentationKey string
param springDatasourceUrl string
param springDatasourceUserName string
param springDatasourceShowSql string
param containerAppPort string
param appSpringProfile string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = {
  name: containerInstanceName
  location: location
  tags: tagsArray
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/microsoft.managedidentity/userassignedidentities/${containerInstanceIdentityName}': {}
    }
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
          image: containerImage
          livenessProbe: {
            httpGet: {
              port: 80
              path: contains(containerImage, 'aci-helloworld') ? '/' : '/health' //initial deployment has an aci-helloworld from mcr deployed
            }
            initialDelaySeconds: 50
            periodSeconds: 3
            failureThreshold: 3
            successThreshold: 2
            timeoutSeconds: 3
          }
          readinessProbe: {
            httpGet: {
              port: 80
              path: contains(containerImage, 'aci-helloworld') ? '/' : '/health/warmup' //initial deployment has an aci-helloworld from mcr deployed
            }
            initialDelaySeconds: 50
            periodSeconds: 3
            failureThreshold: 3
            successThreshold: 2
            timeoutSeconds: 3
          }
          environmentVariables: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsightsInstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'SPRING_DATASOURCE_URL'
              value: springDatasourceUrl
            }
            {
              name: 'SPRING_DATASOURCE_APP_CLIENT_ID'
              value: appClientId
            }
            {
              name: 'SPRING_DATASOURCE_USERNAME'
              value: springDatasourceUserName
            }
            {
              name: 'SPRING_PROFILES_ACTIVE'
              value: appSpringProfile
            }
            {
              name: 'PORT'
              value: string(containerAppPort)
            }
            {
              name: 'SPRING_DATASOURCE_SHOW_SQL'
              value: springDatasourceShowSql
            }
            {
              name: 'DEBUG_AUTH_TOKEN'
              value: 'true'
            }
            {
              name: 'TEST_KEYVAULT_REFERENCE'
              value: springDatasourceUserName
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
