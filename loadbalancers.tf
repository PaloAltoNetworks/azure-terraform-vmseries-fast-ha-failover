resource "azurerm_public_ip" "ingress" {
  name                = "ingress-lb-pip"
  location            = var.resource_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.this]
  sku                 = "Standard"
}

resource "azurerm_lb" "ingress" {
  resource_group_name = var.resource_group_name
  location            = var.resource_location
  name                = "ingress-lb"
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.ingress.id
  }
  depends_on = [azurerm_virtual_network.this]
}

resource "azurerm_lb_backend_address_pool" "ethernet0_1" {
  name            = "vmseries_ethernet0_1"
  loadbalancer_id = azurerm_lb.ingress.id

  depends_on = [azurerm_linux_virtual_machine.vmseries]
}

resource "azurerm_lb_probe" "ingress_https" {
  name                = "https"
  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.ingress.id
  port                = 443
  protocol            = "https"
  request_path        = "/php/login.php"
  interval_in_seconds = 5
  number_of_probes    = 2

}

resource "azurerm_lb_rule" "tcp" {
  count                          = length(var.inbound_tcp_ports)
  name                           = "tcp-${element(var.inbound_tcp_ports, count.index)}"
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.ingress.id
  protocol                       = "TCP"
  frontend_port                  = element(var.inbound_tcp_ports, count.index)
  backend_port                   = element(var.inbound_tcp_ports, count.index)
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.ethernet0_1.id
  probe_id                       = azurerm_lb_probe.ingress_https.id
  enable_floating_ip             = true
  depends_on                     = [azurerm_lb.ingress, azurerm_lb_backend_address_pool.ethernet0_1]
  disable_outbound_snat          = true
}

resource "azurerm_lb_rule" "udp" {
  count                          = length(var.inbound_udp_ports)
  name                           = "udp-${element(var.inbound_udp_ports, count.index)}"
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.ingress.id
  protocol                       = "UDP"
  frontend_port                  = element(var.inbound_udp_ports, count.index)
  backend_port                   = element(var.inbound_udp_ports, count.index)
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.ethernet0_1.id
  probe_id                       = azurerm_lb_probe.ingress_https.id
  enable_floating_ip             = true
  depends_on                     = [azurerm_lb.ingress, azurerm_lb_backend_address_pool.ethernet0_1]
  disable_outbound_snat          = true

}

resource "azurerm_network_interface_backend_address_pool_association" "ethernet0_1" {
  for_each                = var.vmseries
  network_interface_id    = azurerm_network_interface.ethernet0_1[each.key].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ethernet0_1.id
}


resource "azurerm_lb" "egress" {
  resource_group_name = var.resource_group_name
  location            = var.resource_location
  name                = "egress-lb"
  depends_on          = [azurerm_virtual_network.this]
  sku                 = "Standard"

  frontend_ip_configuration {
    name      = "LoadBalancerIP"
    subnet_id = azurerm_subnet.this["loadbalancer"].id
  }
}

resource "azurerm_lb_probe" "egress_https" {
  name                = "https"
  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.egress.id
  port                = 443
  protocol            = "https"
  request_path        = "/php/login.php"
  interval_in_seconds = 5
  number_of_probes    = 2

}

resource "azurerm_lb_backend_address_pool" "ethernet0_2" {
  name            = "ethernet0_2"
  loadbalancer_id = azurerm_lb.egress.id

  depends_on = [azurerm_linux_virtual_machine.vmseries]
}

resource "azurerm_lb_rule" "allports" {
  name                           = "all-ports"
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.egress.id
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "LoadBalancerIP"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.ethernet0_2.id
  probe_id                       = azurerm_lb_probe.egress_https.id
  enable_floating_ip             = true
  depends_on                     = [azurerm_network_interface.ethernet0_2]
}

resource "azurerm_network_interface_backend_address_pool_association" "ethernet0_2" {
  for_each                = var.vmseries
  network_interface_id    = azurerm_network_interface.ethernet0_2[each.key].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ethernet0_2.id
  depends_on              = [azurerm_network_interface.ethernet0_2]
}

output "ingress_lb_pip" {
  value = azurerm_public_ip.ingress.ip_address
}