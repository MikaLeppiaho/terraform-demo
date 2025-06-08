output "container_fqdn" {
  description = "FQDN of deployed containers per region"
  value = {
    for key, cg in azurerm_container_group.container :
    key => cg.fqdn
  }
}