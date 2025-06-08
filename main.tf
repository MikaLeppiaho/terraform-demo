resource "azurerm_resource_group" "rg" {
  for_each = toset(var.regions)
  name     = "${var.resource_prefix}-rg-${each.value}"
  location = each.value
}

# Generate SSH key pair for VMs
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create Virtual Network for each region
resource "azurerm_virtual_network" "vnet" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-vnet-${each.key}"
  address_space       = ["10.0.0.0/16"]
  location            = each.value.location
  resource_group_name = each.value.name
}

# Create Subnet for each region
resource "azurerm_subnet" "internal" {
  for_each             = azurerm_resource_group.rg
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg[each.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Public IP for each VM
resource "azurerm_public_ip" "vm_public_ip" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-pip-${each.key}"
  resource_group_name = each.value.name
  location            = each.value.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = lower("${var.resource_prefix}-${each.key}-vm")
}

# Create Network Security Group and rule for HTTP
resource "azurerm_network_security_group" "vm_nsg" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-nsg-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Interface
resource "azurerm_network_interface" "vm_nic" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-nic-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[each.key].id
  }
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  for_each                  = azurerm_resource_group.rg
  network_interface_id      = azurerm_network_interface.vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.vm_nsg[each.key].id
}

# Generate random text for unique storage account name per region
resource "random_id" "random_id" {
  for_each = azurerm_resource_group.rg
  keepers = {
    resource_group = azurerm_resource_group.rg[each.key].name
  }
  byte_length = 8
}

# Create storage account for boot diagnostics in each region
resource "azurerm_storage_account" "vm_storage" {
  for_each                 = azurerm_resource_group.rg
  name                     = "diag${random_id.random_id[each.key].hex}"
  location                 = each.value.location
  resource_group_name      = each.value.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = azurerm_resource_group.rg
  name                = "${var.resource_prefix}-vm-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  # Disable password authentication and use SSH keys only
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.vm_storage[each.key].primary_blob_endpoint
  }

  # Install nginx using cloud-init (inline)
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_upgrade: true
    packages:
      - nginx
    write_files:
      - content: |
          server {
              listen 80 default_server;
              listen [::]:80 default_server;
              
              root /var/www/html;
              index index.html index.htm index.nginx-debian.html;
              
              server_name _;
              
              location / {
                  try_files $uri $uri/ =404;
              }
          }
        path: /etc/nginx/sites-available/default
      - content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>Demo App - ${each.key}</title>
          </head>
          <body>
              <h1>Hello from Azure VM in ${each.key}!</h1>
              <p>This is running on a virtual machine in Azure region: ${each.key}</p>
              <p>VM Name: ${var.resource_prefix}-vm-${each.key}</p>
          </body>
          </html>
        path: /var/www/html/index.html
    runcmd:
      - systemctl start nginx
      - systemctl enable nginx
      - chown -R www-data:www-data /var/www/html
  EOF
  )
}

