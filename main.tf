resource "azurerm_resource_group" "rg" {
  for_each = toset(var.regions)
  name     = "${var.resource_prefix}-rg-${each.value}"
  location = each.value
}

# Add Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${var.resource_prefix}acr${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg[var.regions[0]].name
  location            = azurerm_resource_group.rg[var.regions[0]].location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "random_string" "acr_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_container_group" "container" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-cg-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name
  os_type             = "Linux"

  container {
    name   = "demoapp"
    image  = "nginx:1.25-alpine" # Use specific version and lighter alpine variant
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  ip_address_type = "Public"
  dns_name_label  = lower("${var.resource_prefix}-${each.key}-dns") # Ensure lowercase for DNS

  # Add retry logic
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}