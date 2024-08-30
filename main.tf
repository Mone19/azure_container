provider "azurerm" {
  features {}
}

# Ressourcen-Gruppe
resource "azurerm_resource_group" "rg" {
  name     = "rg-jenkins"
  location = "West Europe"
}

# Virtuelles Netzwerk
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-jenkins"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnetz für Jenkins
resource "azurerm_subnet" "jenkins_subnet" {
  name                 = "subnet-jenkins"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Öffentliche IP-Adresse für Jenkins
resource "azurerm_public_ip" "jenkins_pip" {
  name                = "pip-jenkins"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Netzwerkschnittstelle für Jenkins
resource "azurerm_network_interface" "jenkins_nic" {
  name                = "nic-jenkins"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jenkins_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_pip.id
  }
}

# Netzwerk-Sicherheitsgruppe für Jenkins
resource "azurerm_network_security_group" "jenkins_nsg" {
  name                = "jenkins-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-jenkins"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 8080
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Verknüpfung der NSG mit der Netzwerkschnittstelle
resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.jenkins_nic.id
  network_security_group_id = azurerm_network_security_group.jenkins_nsg.id
}

# Container-Gruppe für Jenkins
resource "azurerm_container_group" "jenkins" {
  name                = "jenkins-container-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type              = "Linux"

  container {
    name   = "jenkins"
    image  = "jenkins/jenkins:lts"
    cpu    = "1.0"
    memory = "2.0"

    ports {
      port     = 8080
      protocol = "TCP"
    }

    environment_variables = {
      JENKINS_OPTS = "--httpPort=8080"
    }
  }

  tags = {
    environment = "production"
  }
}

