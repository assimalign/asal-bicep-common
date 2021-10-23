@allowed([
  'dev'
  'qa'
  'uat'
  'prd'
])
@description('The environment in which the resource(s) will be deployed')
param environment string

@description('The location prefix or suffix for the resource name')
param location string = ''

@description('The name of the app configuration')
param appConfigurationName string

@description('The pricing tier for Azure App Configurations: "Free" or "Standard". Default is "Free"')
param appConfigurationSku object

@description('An array of object containing the key, value, and contentType if applicable.')
param appConfigurationKeys array = []

@description('Private endpoint configuration for the app configuration deployment')
param appConfigurationPrivateEndpoint object = {}

@description('Enables Maanaged System Identity')
param appConfigurationEnableMsi bool = false

@description('Disables public network access to the resource')
param appConfigurationDisablePublicAccess bool = true

@description('Enables RBAC over access policies')
param appConfigurationEnableRbac bool = false

@description('The tags to attach to the resource when deployed')
param appConfigurationTags object = {}



// **************************************************************************************** //
//                          Azure App Configuration Deployment                              //
// **************************************************************************************** //

var appConfigSku = any((environment == 'dev') ? {
  name: appConfigurationSku.dev
} : any((environment == 'qa') ? {
  name: appConfigurationSku.qa
} : any((environment == 'uat') ? {
  name: appConfigurationSku.uat
} : any((environment == 'prd') ? {
  name: appConfigurationSku.prd
} : {
  name: 'Free'
})))) 


// 1. Deploys a single instance of Azure App Configuration
resource azAppConfigurationDeployment 'Microsoft.AppConfiguration/configurationStores@2021-03-01-preview' = {
  name: replace(replace('${appConfigurationName}', '@environment', environment), '@location', location)
  location: resourceGroup().location
  sku: appConfigSku
  identity: {
    type: appConfigurationEnableMsi == true ? 'SystemAssigned' : 'None'
  }
  properties: {
    disableLocalAuth: appConfigurationEnableRbac
    publicNetworkAccess: appConfigurationDisablePublicAccess == true ? 'Disabled' : 'Enabled'
  }
  tags: appConfigurationTags

  // 1.1 Child Deployment for Azure App configuration
  resource azAppConfigurationKeyValuesDeployment 'keyValues' =  [for key in appConfigurationKeys: if (!empty(appConfigurationKeys) && appConfigurationEnableRbac == false) {
    name: !empty(appConfigurationKeys) ? key.key : 'no-app-config-keys-to-deploy'
    properties: {
      value: !empty(appConfigurationKeys) ? replace(replace(key.value, '@environment', environment), '@location', location) : 'no-app-config-value-to-deploy'
      contentType: !empty(appConfigurationKeys) ? key.contentType ?? json('null') : ''
    }
  }]
}

// 2. Deploys a private endpoint, if applicable, for an instance of Azure App Configuration
module azEventGridPrivateEndpointDeployment 'az.net.private.endpoint.bicep' = if(!empty(appConfigurationPrivateEndpoint)) {
  name: !empty(appConfigurationPrivateEndpoint) ? toLower('az-app-cfg-pri-endp-${guid('${azAppConfigurationDeployment.id}/${appConfigurationPrivateEndpoint.name}')}') : 'no-app-cfg-pri-endp-to-deploy'
  scope: resourceGroup()
  params: {
    location: location
    environment: environment
    privateEndpointName: appConfigurationPrivateEndpoint.name
    privateEndpointPrivateDnsZone: appConfigurationPrivateEndpoint.privateDnsZone
    privateEndpointPrivateDnsZoneGroupName: 'privatelink-azconfig-io'
    privateEndpointPrivateDnsZoneResourceGroup: appConfigurationPrivateEndpoint.privateDnsZoneResourceGroup
    privateEndpointSubnet: appConfigurationPrivateEndpoint.virtualNetworkSubnet
    privateEndpointSubnetVirtualNetwork: appConfigurationPrivateEndpoint.virtualNetwork
    privateEndpointSubnetResourceGroup: appConfigurationPrivateEndpoint.virtualNetworkResourceGroup
    privateEndpointLinkServiceId: azAppConfigurationDeployment.id
    privateEndpointGroupIds: [
      'configurationStores'
    ]
  }
  dependsOn: [
    azAppConfigurationDeployment
  ]
}

// 3. Return Deployment ouput
output resource object = azAppConfigurationDeployment
