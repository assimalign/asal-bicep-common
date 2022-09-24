@allowed([
  ''
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = ''

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('The name of an existing key vault')
param keyVaultName string

@description('The name of the secret to add to the key vault')
param keyVaultSecretName string

@description('The name of the resource with sensitive information to upload into the key vault for secure access')
param resourceName string

@description('The resource group name of the resource with sensitive information to upload into the key vault for secure access')
param resourceGroupName string

// 1. Get the existing Event Hub Authorization Rule Resource
resource azEventHubNamespaceExistingResource 'Microsoft.EventHub/namespaces/authorizationRules@2021-11-01' existing = {
  name: replace(replace('${resourceName}', '@environment', environment), '@region', region)
  scope: resourceGroup(replace(replace('${resourceGroupName}', '@environment', environment), '@region', region))
}

// 2. Create or Update Key Vault Secret with Event Hub Authorization Rule Primary Key & Connection String
resource azEventHubNamespaceKeyVaultSecretDeployment 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: replace(replace(keyVaultName, '@environment', environment), '@region', region)
  resource azEventHubNamespaceConnectionStringSecret 'secrets' = {
    name: '${keyVaultSecretName}-connection-string'
    properties: {
      value: listKeys(azEventHubNamespaceExistingResource.id, azEventHubNamespaceExistingResource.apiVersion).primaryConnectionString
    }
  }
  resource azEventHubNamespacePrimaryKeySecret 'secrets' = {
    name: '${keyVaultSecretName}-primary-key'
    properties: {
      value: listKeys(azEventHubNamespaceExistingResource.id, azEventHubNamespaceExistingResource.apiVersion).primaryKey
    }
  }
}
