// resource group 
@description('The location of the resource group and the location in which all resurces would be created')
param location string = resourceGroup().location

// storage

resource lake_storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storagename
  location: location
  kind: 'StorageV2'
  properties:  {
    isHnsEnabled: true
  }
  sku: {
    name: 'Standard_LRS'
  }
}
// containers

resource bronze 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${lake_storage.name}/default/bronze'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource silver 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${lake_storage.name}/default/silver'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource gold 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name:  '${lake_storage.name}/default/gold'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}


// Synapse workspace


@description('The suffix added to all resources to be created')
param suffix string 

param storagename string = 'medalionlake${suffix}'



// Synapse area
param synapseName string = 'medalionsynapse${suffix}'


param sqlAdministratorLogin string
param sqlAdministratorLoginPassword string

// previously created storage

param defaultDataLakeStorageFilesystemName string = 'dlfs'

param userObjectId string
param dataLakeUrlFormat string 

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseName
  location: location
  properties: {
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    defaultDataLakeStorage:{
      accountUrl: format(dataLakeUrlFormat, storagename)
      filesystem: defaultDataLakeStorageFilesystemName
    }
  }
  identity:{
    type:'SystemAssigned'
  }
}

// role assignment
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageRoleUniqueId = guid(resourceId('Microsoft.Storage/storageAccounts', synapseName), storagename)
var storageRoleUserUniqueId = guid(resourceId('Microsoft.Storage/storageAccounts', synapseName), userObjectId)

resource synapseroleassing 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: storageRoleUniqueId
  scope: lake_storage
  properties:{
    principalId: synapse.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
}

resource userroleassing 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: storageRoleUserUniqueId
  scope: lake_storage
  properties:{
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
  }
}

resource manageid4Pipeline 'Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings@2021-06-01' = {
  name: 'default'
  properties: {
    grantSqlControlToManagedIdentity: {
      desiredState:'Enabled'
    }
  }
  parent:synapse
}

resource allowazure4synapse 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
  parent: synapse
}
param endIpAddress string
param startIpAddress string
resource synapse_fw 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAccessPoint'
  properties: {
    endIpAddress: endIpAddress
    startIpAddress: startIpAddress
  }
  parent: synapse
}


module AKV 'keyvault-rbac.bicep' = {
  name: 'keyVault'  
  params: {
    key_vault_name: 'medallionakv${suffix}'
    userObjId : userObjectId
    accountKeySecretValue: lake_storage.listKeys().keys[0].value
    accountCSSecretValue: 'DefaultEndpointsProtocol=https;AccountName=${lake_storage.name};AccountKey=${lake_storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    location: location
    SynapseIdentityObjId: synapse.identity.principalId
  }
}
