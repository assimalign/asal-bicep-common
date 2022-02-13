@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string = 'dev'

@description('The region prefix or suffix for the resource name, if applicable.')
param region string = ''

@description('the name of the key vault to be deployed. NOTE: Prefix and environment name are not included in this resource deployment')
param keyVaultName string

@description('')
param keyVaultLocation string = resourceGroup().location

@description('The pricing tier for the key vault resource')
param keyVaultSku object = {}

@description('The private endpoint to create or update for the key vault')
param keyVaultPrivateEndpoint object = {}

@description('')
param keyVaultEnableSoftDelete bool = true

@description('The virtual networks to allow access to the deployed key vault')
param keyVaultVirtualNetworks array = []

@allowed([
  'Allow'
  'Deny'
])
@description('')
param keyVaultDefaultNetworkAccess string = 'Allow'

@description('The access policies for obtaining keys, secrets, and certificates with the vault')
param keyVaultPolicies array = []

@description('')
param keyVaultKeys array = []

@description('Key Vault Secret References for azure resources. Specify existing resources to add as secrets for applications to use such as; storage accounts , cosmos db connection strings, etc')
param keyVaultSecrets array = []

@allowed([
  'default'
  'recover'
])
@description('The creation mode for disaster recovery')
param keyVaultCreationMode string = 'default'

@description('Custom attributes to attach to key vault deployment')
param keyVaultTags object = {}

@description('Enable RBAC (Role Based Access Control) for authroization to the key vault')
param keyVaultEnableRbac bool = false

// 1. Format the Virtual Network Access Rules for the Key Vault deployment
var virtualNetworks = [for network in keyVaultVirtualNetworks: {
  id: replace(replace(resourceId('${network.virtualNetworkResourceGroup}', 'Microsoft.Network/virtualNetworks/subnets', '${network.virtualNetwork}', network.virtualNetworkSubnet), '@environment', environment), '@region', region)
}]

// 2. Format Key Vault Policies, if any
var policies = [for policy in keyVaultPolicies: {
  tenantId: subscription().tenantId
  objectId: policy.objectId
  permissions: policy.permissions
}]

// 3. Deploy Key Vault
resource azKeyVaultDeployment 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: replace(replace(keyVaultName, '@environment', environment), '@region', region)
  location: keyVaultLocation
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: keyVaultEnableRbac
    tenantId: subscription().tenantId
    createMode: keyVaultCreationMode
    accessPolicies: policies
    enableSoftDelete: keyVaultEnableSoftDelete
    sku: any(environment == 'dev' ? {
      name: keyVaultSku.dev
      family: 'A'
    } : any(environment == 'qa' ? {
      name: keyVaultSku.qa
      family: 'A'
    } : any(environment == 'uat' ? {
      name: keyVaultSku.uat
      family: 'A'
    } : any(environment == 'prd' ? {
      name: keyVaultSku.dev
      family: 'A'
    } : {
      name: 'Standard'
      family: 'A'
    }))))
    networkAcls: {
      defaultAction: keyVaultDefaultNetworkAccess
      virtualNetworkRules: virtualNetworks
    }
  }
  tags: keyVaultTags
}


module azKeyVaultSecretDeployment 'az.key.vault.secret.bicep' = [for secret in keyVaultSecrets: if (!empty(keyVaultSecrets)) {
  name: !empty(keyVaultSecrets) ? toLower('az-kv-secret-${guid('${azKeyVaultDeployment.id}/${secret.keyVaultSecretName}')}') : 'no-key-vault-secrets-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultSecretName: secret.keyVaultSecretName
    keyVaultSecretResourceName: secret.keyVaultSecretResourceName
    keyVaultSecretResourceType: secret.keyVaultSecretResourceType
    keyVaultSecretResourceGroupOfResource: secret.keyVaultSecretResourceGroupOfResource
  }
}]


module azKeyVaultKeyDeployment 'az.key.vault.key.bicep' = [for key in keyVaultKeys: if (!empty(keyVaultKeys)) {
  name: !empty(keyVaultKeys) ? toLower('az-kv-key-${guid('${azKeyVaultDeployment.id}/${key.name}')}') : 'no-key-vault-keys-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    keyVaultName: keyVaultName
    keyVaultKeyName: key.name
    keyVaultKeySize: key.size
    keyVaultKeyCurveName: key.curveName
    keyVaultTags: keyVaultTags
  }
}]

module azKeyVaultPrivateEndpointDeployment '../../az.private.endpoint/v1.0/az.private.endpoint.bicep' = if (!empty(keyVaultPrivateEndpoint)) {
  name: !empty(keyVaultPrivateEndpoint) ? toLower('az-kv-priv-endpoint-${guid('${azKeyVaultDeployment.id}/${keyVaultPrivateEndpoint.privateEndpointName}')}') : 'no-key-vault-private-endpoint-to-deploy'
  scope: resourceGroup()
  params: {
    region: region
    environment: environment
    privateEndpointName: keyVaultPrivateEndpoint.privateEndpointName
    privateEndpointLocation: contains(keyVaultPrivateEndpoint, 'privateEndpointLocation') ? keyVaultPrivateEndpoint.privateEndpointLocation : keyVaultLocation
    privateEndpointDnsZoneName: keyVaultPrivateEndpoint.privateEndpointDnsZoneName
    privateEndpointDnsZoneGroupName: 'privatelink-vaultcore-azure-net'
    privateEndpointDnsZoneResourceGroup: keyVaultPrivateEndpoint.privateEndpointDnsZoneResourceGroup
    privateEndpointVirtualNetworkName: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkName
    privateEndpointVirtualNetworkSubnetName: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkSubnetName
    privateEndpointVirtualNetworkResourceGroup: keyVaultPrivateEndpoint.privateEndpointVirtualNetworkResourceGroup
    privateEndpointResourceIdLink: azKeyVaultDeployment.id
    privateEndpointGroupIds: [
      'vault'
    ]
  }
}
