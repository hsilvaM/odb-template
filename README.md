# Oracle Database Template (ODB Template)

Una plantilla completa para configurar y ejecutar Oracle Database 19c Enterprise Edition en Docker de manera rápida y sencilla.

## 🚀 Características

- **Oracle Database 19c Enterprise Edition** en contenedor Docker
- **Configuración automática** de credenciales y usuarios
- **Terminal interactivo** para gestión de la base de datos
- **Scripts de autenticación** para Oracle Container Registry
- **Health checks** integrados para monitoreo
- **Persistencia de datos** con volúmenes Docker
- **Configuración de PDB** (Pluggable Database) lista para desarrollo

## 📋 Requisitos Previos

- **Docker** y **Docker Compose** instalados
- **Cuenta de Oracle** con acceso al Container Registry
- **Sistema operativo**: Linux, macOS o Windows con WSL2

### Instalación de Docker

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose

# macOS (con Homebrew)
brew install docker docker-compose

# Windows
# Descargar Docker Desktop desde: https://www.docker.com/products/docker-desktop
```

## 🛠️ Instalación y Configuración

### 1. Clonar o descargar el proyecto

```bash
git clone <repository-url>
cd odb-template
```

### 2. Ejecutar el script de configuración

```bash
chmod +x setup-oracle.sh
./setup-oracle.sh
```

El script realizará automáticamente:
- ✅ Verificación de Docker
- 🔐 Login en Oracle Container Registry
- ⚙️ Configuración de variables de entorno
- 📥 Descarga de la imagen Oracle
- 🚀 Inicio del contenedor
- 👤 Creación de usuario local
- 🖥️ Apertura de terminal interactivo

### 3. Opciones del script

```bash
# Setup completo (recomendado)
./setup-oracle.sh

# Forzar nuevo login
./setup-oracle.sh --force

# No descargar imagen (usar local)
./setup-oracle.sh --no-pull

# Setup sin terminal interactivo
./setup-oracle.sh --no-terminal

# Mostrar ayuda
./setup-oracle.sh --help
```

## 🔐 Autenticación en Oracle Container Registry

Si necesitas hacer login manualmente:

```bash
chmod +x login-oracle-registry.sh
./login-oracle-registry.sh
```

O con credenciales directas:
```bash
./login-oracle-registry.sh tu-email@ejemplo.com tu-password
```

## 📊 Información de Conexión

Una vez configurado, tendrás acceso a:

### Usuario Administrador (System)
- **Usuario**: `system`
- **Contraseña**: Generada automáticamente (ver archivo `.env`)
- **Base de datos**: `ORCLCDB` (Container Database)
- **Puerto**: `1520`

### Usuario Local (Desarrollo)
- **Usuario**: `oracleuser` (configurable)
- **Contraseña**: Generada automáticamente (ver archivo `.env`)
- **Base de datos**: `ORCLPDB1` (Pluggable Database)
- **Puerto**: `1520`

### URLs de Conexión

```bash
# SQL*Plus (Usuario Local)
sqlplus oracleuser/password@//localhost:1520/ORCLPDB1

# SQL*Plus (System)
sqlplus system/password@//localhost:1520/ORCLCDB

# JDBC URL
jdbc:oracle:thin:@//localhost:1520/ORCLPDB1
```

## 🖥️ Terminal Interactivo

El script incluye un terminal interactivo con comandos predefinidos:

```bash
# Conectarse como system (CDB)
sqlplus

# Conectarse como usuario local (PDB)
local

# Mostrar información de conexión
info

# Ver logs del contenedor
logs

# Ver estado del contenedor
status

# Salir
exit
```

## 🐳 Comandos Docker Útiles

```bash
# Ver estado del contenedor
docker ps

# Ver logs
docker logs oracle-db

# Parar el contenedor
docker-compose down

# Reiniciar el contenedor
docker-compose restart

# Conectarse directamente al contenedor
docker exec -it oracle-db bash

# Conectarse a SQL*Plus
docker exec -it oracle-db sqlplus system/password@//localhost:1521/ORCLCDB
```

## 🔧 Configuración Avanzada

### Variables de Entorno

El archivo `.env` contiene:

```bash
ORACLE_PWD=password_generada_automáticamente
LOCAL_USER=oracleuser
LOCAL_PWD=password_generada_automáticamente
```

### Puertos Expuestos

- **1520**: Puerto principal de Oracle Database
- **5500**: Oracle Enterprise Manager Express

### Volúmenes

- `oracle-data`: Persistencia de datos de la base de datos

## 🛠️ Herramientas de Desarrollo Compatibles

- **SQL Developer**: `localhost:1520/ORCLPDB1`
- **DBeaver**: `localhost:1520/ORCLPDB1`
- **Toad**: `localhost:1520/ORCLPDB1`
- **DataGrip**: `localhost:1520/ORCLPDB1`
- **Oracle SQL*Plus**: Incluido en el contenedor

## 📁 Estructura del Proyecto

```
odb-template/
├── setup-oracle.sh          # Script principal de configuración
├── login-oracle-registry.sh # Script de autenticación
├── docker-compose.yml       # Configuración de Docker Compose
├── .env                     # Variables de entorno (generado)
├── .gitignore              # Archivos ignorados por Git
├── odb.zip                 # Archivo de datos (opcional)
└── README.md               # Este archivo
```

## 🚨 Solución de Problemas

### Error de Login en Oracle Registry

```bash
# Verificar credenciales
./login-oracle-registry.sh --force

# Verificar acceso a internet
ping container-registry.oracle.com
```

### Contenedor no inicia

```bash
# Ver logs detallados
docker logs oracle-db

# Verificar recursos del sistema
docker system df
docker system prune  # Limpiar recursos no utilizados
```

### Problemas de conectividad

```bash
# Verificar que el puerto esté disponible
netstat -tulpn | grep 1520

# Verificar estado del contenedor
docker inspect oracle-db
```

## 📝 Notas Importantes

- ⚠️ **Primera ejecución**: El contenedor puede tardar varios minutos en inicializarse
- 🔐 **Credenciales**: Se generan automáticamente y se guardan en `.env`
- 💾 **Persistencia**: Los datos se mantienen entre reinicios del contenedor
- 🚫 **Producción**: Esta configuración es para desarrollo, no para producción
- 📊 **Recursos**: Oracle Database requiere al menos 2GB de RAM disponible

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🆘 Soporte

Si encuentras algún problema:

1. Revisa la sección de [Solución de Problemas](#-solución-de-problemas)
2. Verifica los [logs del contenedor](#-comandos-docker-útiles)
3. Abre un [issue](../../issues) en el repositorio

---

**¡Disfruta desarrollando con Oracle Database! 🐘**
