# LOAD BALANCER ===================================================================================================

/*-----------------------------------------------------------------------------8
Load balancer front IP address range: .4 - .9
+--------------------------------------4--------------------------------------*/

resource "azurerm_lb" "anydb-lb" {
  for_each            = local.loadbalancers
  name                = format("%s-%s-lb", each.value.sid, var.role)
  resource_group_name = var.resource-group[0].name
  location            = var.resource-group[0].location

  frontend_ip_configuration {
    name = format("%s-%s-lb-feip", each.value.sid, var.role)

    subnet_id                     = var.subnet-sap-db[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.infrastructure.vnets.sap.subnet_db.is_existing ? each.value.frontend_ip : lookup(each.value, "frontend_ip", false) != false ? each.value.frontend_ip : cidrhost(var.infrastructure.vnets.sap.subnet_db.prefix, tonumber(each.key) + 4)
  }
  sku = "Standard"

}

resource "azurerm_lb_backend_address_pool" "anydb-lb-back-pool" {
  for_each            = local.loadbalancers
  name                = format("%s-%s-lb-bep", each.value.sid, var.role)
  resource_group_name = var.resource-group[0].name
  loadbalancer_id     = azurerm_lb.anydb-lb[0].id

}

resource "azurerm_lb_probe" "anydb-lb-health-probe" {
  for_each            = local.loadbalancers
  resource_group_name = var.resource-group[0].name
  loadbalancer_id     = azurerm_lb.anydb-lb[0].id
  name                = format("%s-%s-lb-hpp", each.value.sid, var.role)
  port                = "443"
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# TODO:
# Current behavior, it will try to add all VMs in the cluster into the backend pool, which would not work since we do not have availability sets created yet.
# In a scale-out scenario, we need to rewrite this code according to the scale-out + HA reference architecture.
resource "azurerm_network_interface_backend_address_pool_association" "anydb-lb-nic-bep" {
  count                   = local.vm_count
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = azurerm_network_interface.nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.anydb-lb-back-pool[0].id
}

# resource "azurerm_lb_rule" "anydb-lb-rules" {
#   count                          = length(local.loadbalancers-ports)
#   resource_group_name            = var.resource-group[0].name
#   loadbalancer_id                = azurerm_lb.anydb-lb[0].id
#   name                           = "anydb_${local.loadbalancers[0].sid}_${local.loadbalancers[0].ports[count.index]}"
#   protocol                       = "Tcp"
#   frontend_port                  = local.loadbalancers[0].ports[count.index]
#   backend_port                   = local.loadbalancers[0].ports[count.index]
#   frontend_ip_configuration_name = "anydb-${local.loadbalancers[0].sid}-lb-feip"
#   backend_address_pool_id        = azurerm_lb_backend_address_pool.anydb-lb-back-pool[0].id
#   probe_id                       = azurerm_lb_probe.anydb-lb-health-probe[0].id
#   enable_floating_ip             = true
# }
