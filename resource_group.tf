# Creation of the following resources:
#   - Azure Resource Group

resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  location = var.resource_location
  name     = var.resource_group_name
}