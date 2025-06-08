output "vm_public_ips" {
  description = "Public IP addresses of deployed VMs per region"
  value = {
    for key, pip in azurerm_public_ip.vm_public_ip :
    key => pip.ip_address
  }
}

output "vm_fqdns" {
  description = "FQDN of deployed VMs per region"
  value = {
    for key, pip in azurerm_public_ip.vm_public_ip :
    key => pip.fqdn
  }
}

output "vm_ssh_commands" {
  description = "SSH commands to connect to VMs"
  value = {
    for key, pip in azurerm_public_ip.vm_public_ip :
    key => "ssh adminuser@${pip.ip_address}"
  }
}

output "vm_web_urls" {
  description = "Web URLs to access nginx on VMs"
  value = {
    for key, pip in azurerm_public_ip.vm_public_ip :
    key => "http://${pip.ip_address}"
  }
}

output "ssh_private_key" {
  description = "SSH private key for connecting to VMs"
  value       = tls_private_key.vm_ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "SSH public key used for VMs"
  value       = tls_private_key.vm_ssh.public_key_openssh
}

output "vm_details" {
  description = "Complete VM details per region"
  value = {
    for key, vm in azurerm_linux_virtual_machine.vm :
    key => {
      name        = vm.name
      location    = vm.location
      size        = vm.size
      public_ip   = azurerm_public_ip.vm_public_ip[key].ip_address
      fqdn        = azurerm_public_ip.vm_public_ip[key].fqdn
      ssh_command = "ssh adminuser@${azurerm_public_ip.vm_public_ip[key].ip_address}"
      web_url     = "http://${azurerm_public_ip.vm_public_ip[key].ip_address}"
    }
  }
}