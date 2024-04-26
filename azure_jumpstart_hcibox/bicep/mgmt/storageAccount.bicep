@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Name of the VNet')
param HCIInstanceName string = '01'

@description('Location for all resources.')
param location string = resourceGroup().location

var storageAccountName = '${HCIInstanceName}${uniqueString(resourceGroup().id)}'
var modifiedStorageAccountName = replace(replace(storageAccountName, '-', ''), '_', '')
var modifiedStorageAccountNameLowerCase = toLower(modifiedStorageAccountName)
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: modifiedStorageAccountNameLowerCase
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

output storageAccountName string = modifiedStorageAccountNameLowerCase
