param name string
param location string = deployment().location
param resourceTags string


targetScope = 'subscription'

var resourceTagsObj = json(resourceTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
  tags: resourceTagsObj
}
