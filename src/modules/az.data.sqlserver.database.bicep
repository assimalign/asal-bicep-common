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

@description('The name of the sql server instance')
param sqlServerName string

@description('The pricing tier for the database instance')
param sqlServerDatabaseSku object

@description('The name of the database')
param sqlServerDatabaseName string


resource sqlServerDatabaseDeployment 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: replace(replace('${sqlServerName}/${sqlServerDatabaseName}', '@environment', environment), '@location', location)
  location: resourceGroup().location
  properties: {
      
  }
  sku: sqlServerDatabaseSku
}

output resource object = sqlServerDatabaseDeployment
