**Despliegue Aplicativo Devsu App**

[[_TOC_]]

El despliegue de la infraestructura para el proyecto "Devsu Node App" se realizara con Terraform como herramienta de Infraestructura como código, Azure cloud como proveedor de Nube y Azure Devops como servidor de CI/CD. Para esto, se deben seguir los siguientes pasos y consideraciones:

## 1.) Generación Service Principal

Para establecer la autenticación entre terraform y azure debemos crear un service principal que este asociado a la suscripción de Azure en donde vamos a desplegar los recursos del aplicativo. Para esto, debemos ejecutar los siguientes comandos establecidos en la [documentación oficial de terraform](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build#create-a-service-principal:~:text=35akss%2Dsubscription%2Did%22-,Create%20a%20Service%20Principal,-Next%2C%20create%20a):

En mi terminal o la terminal de Azure Cloud Shell ejecutamos:

```
$ az login
$ az account set --subscription "subscription-id"
$ az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription-id>"
```

En esta serie de comandos es importante que agreguemos la suscripción donde vamos a instanciar los recursos del aplicativo. El ultimo comando nos dará la siguiente salida:

```
{
  "appId": "xxxxxx-xxx-xxxx-xxxx-xxxxxxxxxx",
  "displayName": "azure-cli-2022-xxxx",
  "password": "xxxxxx~xxxxxx~xxxxx",
  "tenant": "xxxxx-xxxx-xxxxx-xxxx-xxxxx"
}
```

Estos valores debemos guardarlos ya posteriormente vamos a configurarlos como variables de entorno en el pipeline. Para esto, recomiendo crear una librería y almacenarlo de la siguiente manera:

```
TENANT_ID= tenant
SUBSCRIPTION_ID= subscription-id
CLIENT_SECRET= password
CLIENT_ID= appId
```

## 2.) Creación Backend Azure

Para realizar la configuración del backend en Azure debemos crear un storage account en Azure y alli es donde se almacenara toda la información relacionada a la infraestructura. Este storage account debe ser creado manualmente o por línea de comandos, y una vez generado recomiendo guardar estos valores en la librería mencionada en el punto 1.1 con los siguientes valores

```
terraformStaRg: Grupo de recursos del Storage Account
terraformSta: Nombre del Storage Account
terraformStateKey: Nombre del archivo .tfstate
terraformStaContainer: Contenedor del Storage Account donde se almacenara el .tfstate
acceskey: Llave de acceso del storage account
```

Ahora bien, se puede optar por no generar este Storage Account y dejar que el estado se genere localmente

## 3.) Módulos de terraform

Para esta infraestructura del aplicativo Devsu no se generaron los módulos de los servicios definidos en la arquitectura. Pero si se desean generar, se recomienda que se encuentren en un proyecto diferente al que contiene los pipelines que realizan el despliegue.

## 4. Archivo main.tf y variables de configuración

Para la arquitectura descrita en el [diagrama](https://dev.azure.com/josedanielbaena/prueba-sofka/_wiki/wikis/prueba-sofka.wiki/6/Arquitectura) tenemos el siguiente archivo main.tf que posteriormente será consumido por el pipeline

<details>
<summary> <code>main.tf</code> </summary>

```json
terraform {
    required_providers {
        azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 3.0.2"
        }
    }
    required_version = ">= 1.1.0"
    backend "azurerm" {}
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
```

</details>

## 5.) Pipeline para el despliegue de la infraestructura

Para el despliegue de la infraestructura vamos a usar el siguiente pipeline en formato yaml

<details>
<summary> <code>iac-deploy.yaml</code> </summary>

```yaml
trigger:
  branches:
    include:
      - main

variables:
  - group: variable-group-devsu-app

stages:
  - stage: DeployInfrastructure
    jobs:
      - job: Job
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: TerraformInstaller@1
            displayName: "Terraforn Install"
            inputs:
              terraformVersion: "latest"
          - task: UsePythonVersion@0
            inputs:
              versionSpec: "3.x"
              addToPath: true
              architecture: "x64"
          - task: Bash@3
            displayName: "Install Checkov"
            inputs:
              targetType: "inline"
              script: |
                pip install checkov \
                pip install jq
          - task: Bash@3
            displayName: "Setting Environment Variables SP"
            inputs:
              targetType: "inline"
              script: |
                echo "Setting Environment Variables for Terraform"
                echo "##vso[task.setvariable variable=ARM_CLIENT_ID]$(CLIENT_ID)"
                echo "##vso[task.setvariable variable=ARM_CLIENT_SECRET]$(CLIENT_SECRET)"
                echo "##vso[task.setvariable variable=ARM_SUBSCRIPTION_ID]$(SUBSCRIPTION_ID)"
                echo "##vso[task.setvariable variable=ARM_TENANT_ID]$(TENANT_ID)"
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Init"
            inputs:
              targetType: "inline"
              script: |
                terraform init \
                    -input=false \
                    -backend-config="resource_group_name=$(terraformStaRg)" \
                    -backend-config="storage_account_name=$(terraformSta)" \
                    -backend-config="container_name=$(terraformStaContainer)" \
                    -backend-config="key=$(terraformStateKey)"
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Plan"
            inputs:
              targetType: "inline"
              script: |
                terraform plan -out=tf.plan
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Show"
            inputs:
              targetType: "inline"
              script: 'terraform show -json tf.plan | jq "." > tf.json'
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Analisis Estatico de Codigo con Checkov"
            inputs:
              targetType: "inline"
              script: |
                ls
                ruta=iac-test/src/tf.json
                mkdir $(System.DefaultWorkingDirectory)/iac/checkov-report
                checkov -f $(System.DefaultWorkingDirectory)/$ruta --output cli
                checkov -f $(System.DefaultWorkingDirectory)/$ruta --output junitxml > $(System.DefaultWorkingDirectory)/iac/checkov-report/TEST-checkov-report.xml
          - task: PublishTestResults@2
            displayName: "Publish checkov Test Results"
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "**/TEST-*.xml"
              searchFolder: "$(System.DefaultWorkingDirectory)/iac/checkov-report"
              testRunTitle: "CheckOV Scan"
          - task: Bash@3
            displayName: "Terraform Apply"
            condition: succeeded()
            inputs:
              targetType: "inline"
              script: |
                terraform apply -auto-approve tf.plan
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

</details>

Que se divide en las siguientes tareas:

### 5.1) Terraform Installer

```yaml
- task: TerraformInstaller@1
  displayName: "Terraforn Install"
  inputs:
    terraformVersion: "latest"
```

Instala la última versión de Terraform en el agente de construcción.

### 5.2) Use Python Version

```yaml
- task: UsePythonVersion@0
  inputs:
    versionSpec: "3.x"
    addToPath: true
    architecture: "x64"
```

Configura el entorno para usar Python 3.x, necesario para ejecutar scripts de Checkov y otros scripts de Python.

### 5.3) Install Checkov

```yaml
- task: Bash@3
  displayName: "Install Checkov"
  inputs:
    targetType: "inline"
    script: |
      pip install checkov \
      pip install jq
```

Instala Checkov, una herramienta de análisis de seguridad de infraestructuras como código (IaC), y jq, una herramienta para procesar JSON.

### 5.4) Setting Environment Variables SP

```yaml
- task: Bash@3
  displayName: "Setting Environment Variables SP"
  inputs:
    targetType: "inline"
    script: |
      echo "Setting Environment Variables for Terraform"
      echo "##vso[task.setvariable variable=ARM_CLIENT_ID]$(CLIENT_ID)"
      echo "##vso[task.setvariable variable=ARM_CLIENT_SECRET]$(CLIENT_SECRET)"
      echo "##vso[task.setvariable variable=ARM_SUBSCRIPTION_ID]$(SUBSCRIPTION_ID)"
      echo "##vso[task.setvariable variable=ARM_TENANT_ID]$(TENANT_ID)"
    workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

Configura las variables de entorno necesarias para la autenticación con Azure mediante Service Principal. Estas variables se generaron en el apartado 1 de esta wiki y se almacenaron en el variable group relacionado en el pipeline.

### 5.5) Terraform init

```yaml
- task: Bash@3
  displayName: "Terraform Init"
  inputs:
    targetType: "inline"
    script: |
      terraform init \
          -input=false \
          -backend-config="resource_group_name=$(terraformStaRg)" \
          -backend-config="storage_account_name=$(terraformSta)" \
          -backend-config="container_name=$(terraformStaContainer)" \
          -backend-config="key=$(terraformStateKey)"
    workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

Inicializa el backend de Terraform, configurando el almacenamiento remoto del estado de Terraform en una cuenta de almacenamiento de Azure.

### 5.6) Terraform Plan

```yaml
- task: Bash@3
  displayName: "Terraform Plan"
  inputs:
    targetType: "inline"
    script: |
      terraform plan -out=tf.plan
    workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

Genera y guarda un plan de ejecución de Terraform (tf.plan) que muestra las acciones que Terraform realizará para alcanzar el estado deseado de la infraestructura.

### 5.7) Terraform Show

```yaml
- task: Bash@3
  displayName: "Terraform Show"
  inputs:
    targetType: "inline"
    script: 'terraform show -json tf.plan | jq "." > tf.json'
    workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

Convierte el plan de Terraform (tf.plan) en un formato JSON legible y lo guarda en tf.json.

### 5.8) Análisis Estático de Código con Checkov

```yaml
- task: Bash@3
  displayName: "Analisis Estatico de Codigo con Checkov"
  inputs:
    targetType: "inline"
    script: |
      ls
      ruta=iac-test/src/tf.json
      mkdir $(System.DefaultWorkingDirectory)/iac/checkov-report
      checkov -f $(System.DefaultWorkingDirectory)/$ruta --output cli
      checkov -f $(System.DefaultWorkingDirectory)/$ruta --output junitxml > $(System.DefaultWorkingDirectory)/iac/checkov-report/TEST-checkov-report.xml
```

Realiza un análisis de seguridad del archivo JSON generado (tf.json) usando Checkov y guarda los resultados en formato JUnit XML para su posterior publicación.

### 5.9) Análisis Estático de Código con Checkov

```yaml
- task: PublishTestResults@2
  displayName: "Publish checkov Test Results"
  condition: succeededOrFailed()
  inputs:
    testResultsFormat: "JUnit"
    testResultsFiles: "**/TEST-*.xml"
    searchFolder: "$(System.DefaultWorkingDirectory)/iac/checkov-report"
    testRunTitle: "CheckOV Scan"
```

Publica los resultados del análisis de Checkov en Azure DevOps para su revisión.

### 5.10) Análisis Estático de Código con Checkov

```yaml
- task: Bash@3
  displayName: "Terraform Apply"
  condition: succeeded()
  inputs:
    targetType: "inline"
    script: |
      terraform apply -auto-approve tf.plan
    workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
```

Aplica los cambios planificados en la infraestructura usando el plan generado anteriormente (tf.plan). Esta tarea se ejecuta solo si todas las tareas anteriores han tenido éxito.

Una vez clara cada una de las tareas, debemos llevar este archivo yaml con la declaracion de la infraestructura a un repositorio donde deseemos tenerlos y debemos realizar la configuración del pipeline con este yaml como parámetro de entrada

Consideraciones:

- Este pipeline solo es funcional si incluimos el yaml en el repositorio donde se encuentra la declaración de la infraestructura y los modulos.
- Si deseamos separar los modulos del repositorio donde se encuentra la infraestructura al pipeline debemos configurar la ruta a los modulos dentro del archivo main.tf y ingresar el siguientes bloque de código en el yaml

```yaml
resources:
  repositories:
    - repository: Nombre-del-repositorio
      type: git
      ref: rama-del-repositorio
      name: "Nombre-del-proyecto"
```

y las siguientes tareas

```yaml
- task: 6d15af64-176c-496d-b583-fd2ae21d4df4@1
inputs:
  repository: self
- task: 6d15af64-176c-496d-b583-fd2ae21d4df4@1
inputs:
  repository: Common-Modules
```

Dando como resultado el siguiente pipeline:

```yaml
trigger:
  branches:
    include:
      - main

variables:
  - group: variable-group-devsu-app

stages:
  - stage: DeployInfrastructure
    jobs:
      - job: Job
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: 6d15af64-176c-496d-b583-fd2ae21d4df4@1
            inputs:
              repository: self
          - task: 6d15af64-176c-496d-b583-fd2ae21d4df4@1
            inputs:
              repository: nombre-del-repositoprio
          - task: TerraformInstaller@1
            displayName: "Terraforn Install"
            inputs:
              terraformVersion: "latest"
          - task: UsePythonVersion@0
            inputs:
              versionSpec: "3.x"
              addToPath: true
              architecture: "x64"
          - task: Bash@3
            displayName: "Install Checkov"
            inputs:
              targetType: "inline"
              script: |
                pip install checkov \
                pip install jq
          - task: Bash@3
            displayName: "Setting Environment Variables SP"
            inputs:
              targetType: "inline"
              script: |
                echo "Setting Environment Variables for Terraform"
                echo "##vso[task.setvariable variable=ARM_CLIENT_ID]$(CLIENT_ID)"
                echo "##vso[task.setvariable variable=ARM_CLIENT_SECRET]$(CLIENT_SECRET)"
                echo "##vso[task.setvariable variable=ARM_SUBSCRIPTION_ID]$(SUBSCRIPTION_ID)"
                echo "##vso[task.setvariable variable=ARM_TENANT_ID]$(TENANT_ID)"
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Init"
            inputs:
              targetType: "inline"
              script: |
                terraform init \
                    -input=false \
                    -backend-config="resource_group_name=$(terraformStaRg)" \
                    -backend-config="storage_account_name=$(terraformSta)" \
                    -backend-config="container_name=$(terraformStaContainer)" \
                    -backend-config="key=$(terraformStateKey)"
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Plan"
            inputs:
              targetType: "inline"
              script: |
                terraform plan -out=tf.plan
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Terraform Show"
            inputs:
              targetType: "inline"
              script: 'terraform show -json tf.plan | jq "." > tf.json'
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
          - task: Bash@3
            displayName: "Analisis Estatico de Codigo con Checkov"
            inputs:
              targetType: "inline"
              script: |
                ls
                ruta=iac-test/src/tf.json
                mkdir $(System.DefaultWorkingDirectory)/iac/checkov-report
                checkov -f $(System.DefaultWorkingDirectory)/$ruta --output cli
                checkov -f $(System.DefaultWorkingDirectory)/$ruta --output junitxml > $(System.DefaultWorkingDirectory)/iac/checkov-report/TEST-checkov-report.xml
          - task: PublishTestResults@2
            displayName: "Publish checkov Test Results"
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "**/TEST-*.xml"
              searchFolder: "$(System.DefaultWorkingDirectory)/iac/checkov-report"
              testRunTitle: "CheckOV Scan"
          - task: Bash@3
            displayName: "Terraform Apply"
            condition: succeeded()
            inputs:
              targetType: "inline"
              script: |
                terraform apply -auto-approve tf.plan
              workingDirectory: "$(System.DefaultWorkingDirectory)/iac/"
resources:
  repositories:
    - repository: Nombre-del-repositorio
      type: git
      ref: rama-del-repositorio
      name: "Nombre-del-proyecto"
```
