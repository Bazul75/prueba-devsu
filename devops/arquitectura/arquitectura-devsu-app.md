Arquitectura Devsu App
[[_TOC_]]

## 1.) Diagrama Arquitectura

![diagrama-devsu.drawio.png](./diagrama-devsu.drawio-a6b9d6c2-6168-4f8b-ab24-762a24d0cf10.png)

## 2. Detalles de Componentes

### 2.1. Usuarios y Dominio

Usuarios: Usuarios finales que acceden a la aplicación a través de un navegador web.
Dominio DNS: Resuelve el nombre de dominio al Azure Front Door, facilitando el acceso de los usuarios a la aplicación.

### 2.2. Frontdoor

Propósito: Proporciona balanceo de carga global y aceleración del tráfico, asegurando la alta disponibilidad y rendimiento.

### 2.3. Azure Firewall y DDOS Protection

Azure Firewall: Proporciona seguridad en la red mediante la inspección de tráfico y aplicación de políticas.
DDOS Protection: Protege contra ataques de denegación de servicio distribuidos.

### 2.4. Red Virtual y Subredes

DevSu VNet: Aisla los recursos en una red virtual segura.
ApimSubnet: Contiene el servicio de APIM (Azure API Management).
AgicSubnet: Contiene el Application Gateway.
AksSubnet: Contiene el clúster privado de AKS.
SQLSubnet: Contiene el servicio de SQL.
ACRSubnet: Contiene el Azure Container Registry.

### 2.5. APIM y Application Gateway

APIM (Azure API Management): Gestiona las API y actúa como puerta de enlace para el tráfico de API, recibiendo las solicitudes y luego enviándolas al Application Gateway.
Application Gateway: Un balanceador de carga de capa 7 que maneja solicitudes HTTP/HTTPS, proporcionando terminación SSL y distribución de tráfico.
Listener: Monitorea los puertos HTTP/HTTPS.
Rules: Define las reglas para enrutar el tráfico a los backend pools.
Backend Pool: Grupos de recursos backend que manejan las solicitudes.

### 2.6. Private AKS Cluster

Ingress Controller: Maneja el enrutamiento del tráfico dentro del clúster.
Services: Abstracciones de los pods que permiten el acceso a las aplicaciones en el clúster.
Pods: Unidades de despliegue que ejecutan las aplicaciones y servicios.

### 2.7. Certificate Authority Service

Propósito: Gestiona los certificados de cliente y servidor necesarios para la autenticación segura.

### 2.8. Azure DevOps Pipelines

CI Pipeline: Pipeline de integración continua que se activa al empujar código al repositorio.
CD Pipeline: Pipeline de entrega continua que despliega la aplicación después del pipeline de CI.

## 3. Flujo de Trabajo

### 3.1. Desarrollo

Desarrolladores: Trabajan en el código y lo empujan al repositorio.

### 3.2. Pipelines de Azure DevOps

CI Pipeline:
Se activa el pipeline de CI, que obtiene el código fuente, instala las herramientas necesarias, compila la solución y publica la imagen Docker.
CD Pipeline:
Una vez que el pipeline de CI se completa con éxito, se activa el pipeline de CD para desplegar la aplicación en el clúster de AKS.

### 3.3. APIM y Application Gateway

APIM: Recibe las solicitudes de los usuarios y las envía al Application Gateway.
Application Gateway:
Maneja las solicitudes entrantes desde APIM, aplicando reglas y dirigiendo el tráfico al backend pool.

### 3.4. Clúster Privado de AKS

Procesamiento de Solicitudes: La aplicación desplegada en el clúster de AKS procesa las solicitudes y responde a los usuarios.

### 3.5. Seguridad y Certificación

Certificate Authority Service: Proporciona los certificados necesarios para la autenticación segura entre los componentes.
