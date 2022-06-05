//adding terraform backend block to create terraform state file on azure
terraform {
 backend "azure" {} 
}

resource "azurerm_resource_group" "rg" {
  name      = "myresourcegoup"
  location  = var.resource_group_location //"westeurope"
}

# Create virtual network

resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
#subnet1
resource "azurerm_subnet" "myterraformsubnet1" {
  name                 = "mySubnet1" //actual name of the resource
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}
#subnet2
resource "azurerm_subnet" "myterraformsubnet2" {
  name                 = "mySubnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

#we can ssh(one of the way to connect) to the vm using this pubic ip over internet

# Create public IPs for vm1
resource "azurerm_public_ip" "myterraformpublicip1" {
  name                = "myPublicIP1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic" //dynamic ip can be changed | static can
}
# Create public IPs for vm2
resource "azurerm_public_ip" "myterraformpublicip2" {
  name                = "myPublicIP2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

#network securtiy group can be attatchd to vm nic or subnet as well
#here we are attaching it to vm nic

# Create Network Security Group and rule for vm1 
resource "azurerm_network_security_group" "myterraformnsg1" {
  name                = "myNetworkSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "rule1"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"//Tcp
    source_port_range          = "*"
    destination_port_range     = "22"//for inbound traffic dest port is given coz 
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Security Group and rule for vm2
resource "azurerm_network_security_group" "myterraformnsg2" {
  name                = "myNetworkSecurityGroup2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "rule2"//name of sec rule
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Create network interface for vm 1// NIC used for communication with vm
resource "azurerm_network_interface" "myterraformnic1" {
  name                = "myNIC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration1"
    subnet_id                     = azurerm_subnet.myterraformsubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip1.id
  }
}

# Create network interface for vm 2
resource "azurerm_network_interface" "myterraformnic2" {
  name                = "myNIC2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration2"
    subnet_id                     = azurerm_subnet.myterraformsubnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip2.id
  }
}


# Connect the security group to the network interface FOR VM1
resource "azurerm_network_interface_security_group_association" "example1" {
  network_interface_id      = azurerm_network_interface.myterraformnic1.id
  network_security_group_id =  azurerm_network_security_group.myterraformnsg1.id
}

# Connect the security group to the network interface FOR VM2
resource "azurerm_network_interface_security_group_association" "example2" {
  network_interface_id      = azurerm_network_interface.myterraformnic2.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg2.id
}


# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine vm1 
resource "azurerm_linux_virtual_machine" "myterraformvm1" {
  name                  =   "vm1" //"slvm2" 
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.myterraformnic1.id]//nic created in subnet 1
  size                  = "standard_b1s"

  os_disk {
    name                 = "myOsDisk1"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm1"
  admin_username                  = "azureuser"
  disable_password_authentication = true

#one of the method to communicate to vm
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
# troubleshooting the vm
  boot_diagnostics {//
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }
}

# Create virtual machine vm2
resource "azurerm_linux_virtual_machine" "myterraformvm2" {
  name                  =   "vm2" //"slvm1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.myterraformnic2.id]
  size                  = "standard_b1s"

  os_disk {
    name                 = "myOsDisk2"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm2"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "ishanstorage"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard" //
  account_replication_type = "LRS"//locally redundant storage
}





#load balancer for config
# resource "azurerm_resource_group" "example" {
#   name     = "LoadBalancerRG"
#   location = "West Europe"
# }



resource "azurerm_public_ip" "publicip_lb" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "example" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.publicip_lb.id
  }
}

