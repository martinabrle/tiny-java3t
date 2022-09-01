param containerInstanceName string
param containerAppName string
param containerImage string
param appInsightsConnectionString string
param appInsightsInstrumentationKey string
param springDatasourceUrl string
param springDatasourceUserName string
@secure()
param springDatasourcePassword string
param springDatasourceShowSql string = 'true'
param containerAppPort string

param location string = resourceGroup().location

param tagsArray object = resourceGroup().tags

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = {
  name: containerInstanceName
  location: location
  tags: tagsArray
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
      dnsNameLabel: replace(replace(containerInstanceName, '-', ''), '_', '')
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
              name: 'SPRING_DATASOURCE_USERNAME'
              value: springDatasourceUserName
            }
            {
              name: 'SPRING_DATASOURCE_PASSWORD'
              value: springDatasourcePassword
            }
            {
              name: 'SPRING_PROFILES_ACTIVE'
              value: 'test'
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
