 #Resource group config
resource "azurerm_resource_group" "srg" {
    name = var.rgname
    location = var.location
}
#vnet config
resource "azurerm_virtual_network" "vnet" {
    name = var.vnet
    resource_group_name = azurerm_resource_group.srg.name
    location = azurerm_resource_group.srg.location
    address_space = var.vnetaddress 
}
#subnet config
resource "azurerm_subnet" "sub" {
    name = var.subnet
    resource_group_name = azurerm_resource_group.srg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = var.subaddress
}
#subnet config1

#Bastian subnet config
resource "azurerm_subnet" "bastian" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.srg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.49.20.0/24"]
}
#pubip config
resource "azurerm_public_ip" "pubip" {
    name = "${var.pubip}${count.index}"
    count = 2
    resource_group_name = azurerm_resource_group.srg.name
    location = azurerm_resource_group.srg.location
    allocation_method = "Static"

    tags = {
    environment = "Hub"
  }
}

#Nic configuration
resource "azurerm_network_interface" "nic" {
    name = var.nic
    resource_group_name = azurerm_resource_group.srg.name
    location = azurerm_resource_group.srg.location

    ip_configuration {
        name = var.subnet
        subnet_id = azurerm_subnet.sub.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.pubip[0].id
    }  
}
#SG configuration && Assosiation to NIC
resource "azurerm_network_security_group" "nsg" {
    name = var.nsg
    resource_group_name = azurerm_resource_group.srg.name
    location = azurerm_resource_group.srg.location

    security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    }
resource "azurerm_network_interface_security_group_association" "nsg-nic" {
    network_interface_id = azurerm_network_interface.nic.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}
#VM creation
resource "azurerm_linux_virtual_machine" "example" {
  name                = var.vm
  resource_group_name = azurerm_resource_group.srg.name
  location            = azurerm_resource_group.srg.location
  size                = var.vmsize
  admin_username      = var.username
  disable_password_authentication = "true"
#   admin_password      = var.password
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  admin_ssh_key {
    username   = var.username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDG6oYC/SKicE+RhSs5wsctCrze7C0aPWpg7p9N78+QFUpkhLqQIJZpzvAT2E2TrcQA6maiZQBRM+lQ/7+2/VksWgFAPt1g4HAtLtBdRLPmx0i2JoDg9aytY2nGXD33PkXG3ocbqPxQQpP1u9elZmT7hyWyw9WUD02ftixKtJ2Kb099kAWdnttzShDMsNb3BOUjc/CSFHar+57/0O7+7BRFfTHiJAkSiD4w7FUFyT27igS8B/fiyLfGRzUp3uqxDhkuO5kKM0LrB9g59NU0LBAIK7ZgPUVIkHIN882979ED/K7b9cJEKHwCPUh09WeRluQcY5wPQntBp/pGmpGbxhtV rsa-key-20241214"
  } 
}
resource "azurerm_bastion_host" "bhost" {
  name                = "bastianhost"
  location            = azurerm_resource_group.srg.location
  resource_group_name = azurerm_resource_group.srg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastian.id
    public_ip_address_id = azurerm_public_ip.pubip[1].id
  }
}