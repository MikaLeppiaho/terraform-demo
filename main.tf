resource "azurerm_resource_group" "rg" {
  for_each = toset(var.regions)
  name     = "${var.resource_prefix}-rg-${each.value}"
  location = each.value
}

resource "azurerm_container_group" "container" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-cg-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name
  os_type             = "Linux"

  container {
    name   = "demoapp"
    image  = "nginx:latest" # Consider using a more specific image
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  ip_address_type = "Public"
  dns_name_label  = lower("${var.resource_prefix}-${each.key}-dns") # Ensure lowercase for DNS

}