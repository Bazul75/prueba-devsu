provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Crear el grupo de recursos
resource "azurerm_resource_group" "rg" {
  name     = "devsu-rg"
  location = "East US"
}

# Crear la red virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "devsu-Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Crear las subnets
resource "azurerm_subnet" "apim_subnet" {
  name                 = "devsu-ApimSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "agic_subnet" {
  name                 = "devsu-AgicSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "devsu-AksSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "sql_subnet" {
  name                 = "devsu-SQLSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_subnet" "acr_subnet" {
  name                 = "devsu-ACRSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Crear grupo de seguridad de red (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "devsu-myNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Regla para permitir tráfico a SQL desde la VNet
  security_rule {
    name                       = "allow_sql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1433"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.4.0/24"
  }

  # Regla para permitir tráfico a ACR desde la VNet
  security_rule {
    name                       = "allow_acr"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.5.0/24"
  }

  # Regla para permitir tráfico HTTP al Application Gateway
  security_rule {
    name                       = "allow_http"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.2.0/24"
  }

  # Regla para permitir tráfico HTTPS al Application Gateway
  security_rule {
    name                       = "allow_https"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.2.0/24"
  }

  # Regla para permitir tráfico a APIM desde la VNet
  security_rule {
    name                       = "allow_apim"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.1.0/24"
  }
}

# Asociar las subnets con el NSG
resource "azurerm_subnet_network_security_group_association" "apim_nsg" {
  subnet_id                 = azurerm_subnet.apim_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "agic_nsg" {
  subnet_id                 = azurerm_subnet.agic_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "sql_nsg" {
  subnet_id                 = azurerm_subnet.sql_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "acr_nsg" {
  subnet_id                 = azurerm_subnet.acr_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Crear identidad administrada para AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "aks-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Crear el clúster AKS
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "devsu-AKSCluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myaks"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.0.10"
    service_cidr   = "10.0.0.0/16"
  }
}

# Asignar permisos a AKS para acceder a ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Crear el Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "devsuContainerRegistry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Crear el servidor SQL

resource "azurerm_mssql_server" "sql_server" {
  name                         = "devsusqlserver"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "H@Sh1CoR3!"

  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
}

# Crear la base de datos SQL
data "azurerm_mssql_database" "sql_database" {
  name      = "example-mssql-db"
  server_id = azurerm_mssql_server.sql_server.id
}

# Regla de firewall para permitir acceso desde la VNet al servidor SQL
resource "azurerm_mssql_firewall_rule" "example" {
  name             = "allow-vnet"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "10.0.0.0"
  end_ip_address   = "10.0.255.255"
}

# Asignar permisos a AKS para acceder a SQL Database
resource "azurerm_role_assignment" "sql_access" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "Contributor"
  scope                = azurerm_mssql_server.sql_server.id
}

# Crear el Application Gateway
resource "azurerm_public_ip" "app_gateway_public_ip" {
  name                = "AppGwPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "app_gateway" {
  name                = "devsu-AppGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "AppGwIpConfig"
    subnet_id = azurerm_subnet.agic_subnet.id
  }

  frontend_ip_configuration {
    name                 = "AppGwFrontendIpConfig"
    public_ip_address_id = azurerm_public_ip.app_gateway_public_ip.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  backend_address_pool {
    name = "AppGwBackendPool"
  }

  backend_http_settings {
    name                  = "AppGwHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
  }

  http_listener {
    name                           = "AppGwHttpListener"
    frontend_ip_configuration_name = "AppGwFrontendIpConfig"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "AppGwRoutingRule"
    rule_type                  = "Basic"
    http_listener_name         = "AppGwHttpListener"
    backend_address_pool_name  = "AppGwBackendPool"
    backend_http_settings_name = "AppGwHttpSettings"
  }
}

# Crear el API Management (APIM)
resource "azurerm_api_management" "apim" {
  name                = "devsu-ApiManagement"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "devsu-test"
  publisher_email     = "devsu@example.com"
  sku_name            = "Developer_1"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# Crear el Key Vault
resource "azurerm_key_vault" "key_vault" {
  name                        = "devsu-KeyVault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  sku_name                    = "standard"

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"

    ip_rules = ["0.0.0.0/0"]
  }
}
