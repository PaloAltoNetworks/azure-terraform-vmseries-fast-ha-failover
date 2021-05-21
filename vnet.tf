# Creation of the following resources:
#   - Azure Virtual Networks
#   - Azure Virtual Network Subnets

resource "azurerm_virtual_network" "this" {
  count               = var.create_virtual_network ? 1 : 0
  address_space       = [var.virtual_network_cidr]
  location            = var.resource_location
  name                = var.virtual_network_name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.this]
}

resource "azurerm_subnet" "this" {
  for_each             = var.create_virtual_network_subnets ? var.virtual_network_subnets : {}
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = each.value.address_prefixes

  depends_on = [azurerm_virtual_network.this]
}

