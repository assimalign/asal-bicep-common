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

@description('The name of the Map Account to be deployed.')
param mapAccountName string

@description('The location the Map Account will be deployed to.')
param mapAccountLocation string = resourceGroup().location

@description('The tags to attach to the resource when deployed')
param mapAccountTags object = {}


resource azMapAccountDeployment 'Microsoft.Maps/accounts@2021-02-01' = {
   name: replace(replace(mapAccountName, '@environment', environment), '@region', region)
   location: mapAccountLocation
   sku: {
      name:  'G2'
   }
   properties: {}
   tags: mapAccountTags
}
