#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ORACLE_IMAGE="container-registry.oracle.com/database/enterprise:19.3.0.0"
ORACLE_REGISTRY="container-registry.oracle.com"
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

show_help() {
    echo -e "${BLUE}Oracle Database Setup Script${NC}"
    echo ""
    echo "Uso:"
    echo "  $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --force         Fuerza el login aunque ya estés logueado"
    echo "  --no-pull       No descarga la imagen (usa la local si existe)"
    echo "  --no-terminal   No abre terminal interactivo"
    echo "  --help          Muestra esta ayuda"
    echo ""
    echo "Este script:"
    echo "  1. Verifica Docker"
    echo "  2. Verifica login en Oracle Container Registry"
    echo "  3. Configura variables de entorno"
    echo "  4. Levanta el contenedor Oracle"
    echo "  5. Verifica que esté funcionando"
    echo "  6. Crea usuario local de Oracle"
    echo "  7. Abre terminal interactivo (opcional)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                    # Setup completo con terminal interactivo"
    echo "  $0 --force           # Fuerza nuevo login"
    echo "  $0 --no-pull         # No descarga imagen"
    echo "  $0 --no-terminal     # Setup sin terminal interactivo"
}

check_docker() {
    echo -e "${BLUE}🔍 Verificando Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker no está instalado${NC}"
        echo "Instala Docker primero: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker no está corriendo${NC}"
        echo "Inicia Docker Desktop o el servicio de Docker"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker está instalado y corriendo${NC}"
}

check_oracle_access() {
    echo -e "${BLUE}🔍 Verificando acceso al Oracle Container Registry...${NC}"
    
    if docker manifest inspect "$ORACLE_IMAGE" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Tienes acceso al repositorio Oracle${NC}"
        return 0
    fi
    
    if docker system info 2>/dev/null | grep -q "$ORACLE_REGISTRY"; then
        echo -e "${YELLOW}⚠️  Tienes credenciales guardadas pero no puedes acceder al repositorio${NC}"
        echo -e "${YELLOW}   Es posible que las credenciales hayan expirado${NC}"
        return 1
    fi
    
    if docker images "$ORACLE_IMAGE" --format "{{.Repository}}:{{.Tag}}" | grep -q "$ORACLE_IMAGE"; then
        echo -e "${GREEN}✅ La imagen Oracle ya está disponible localmente${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}❌ No tienes acceso al repositorio Oracle${NC}"
    return 1
}

do_oracle_login() {
    echo -e "${BLUE}🔐 Iniciando login en Oracle Container Registry...${NC}"
    echo ""
    
    echo -e "${YELLOW}Ingresa tus credenciales de Oracle Container Registry:${NC}"
    echo ""
    
    read -p "Usuario (email): " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}❌ Usuario no puede estar vacío${NC}"
        return 1
    fi
    
    read -s -p "Contraseña: " password
    echo
    if [[ -z "$password" ]]; then
        echo -e "${RED}❌ Contraseña no puede estar vacía${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}Intentando hacer login...${NC}"
    
    if echo "$password" | docker login "$ORACLE_REGISTRY" --username "$username" --password-stdin; then
        echo -e "${GREEN}✅ Login exitoso!${NC}"
        return 0
    else
        echo -e "${RED}❌ Error en el login${NC}"
        echo ""
        echo -e "${YELLOW}Posibles causas:${NC}"
        echo "  - Credenciales incorrectas"
        echo "  - No tienes acceso al registry"
        echo "  - Problemas de conectividad"
        return 1
    fi
}

setup_environment() {
    echo -e "${BLUE}⚙️  Configurando variables de entorno...${NC}"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${YELLOW}Archivo .env no encontrado, creándolo...${NC}"
        
        ORACLE_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        LOCAL_USER="oracleuser"
        LOCAL_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        cat > "$ENV_FILE" << EOF
ORACLE_PWD=$ORACLE_PWD
LOCAL_USER=$LOCAL_USER
LOCAL_PWD=$LOCAL_PWD
EOF
        echo -e "${GREEN}✅ Archivo .env creado con credenciales generadas${NC}"
        echo -e "${CYAN}Contraseña Oracle (system): $ORACLE_PWD${NC}"
        echo -e "${CYAN}Usuario local: $LOCAL_USER${NC}"
        echo -e "${CYAN}Contraseña local: $LOCAL_PWD${NC}"
        echo -e "${YELLOW}⚠️  Guarda estas credenciales en un lugar seguro${NC}"
    else
        echo -e "${GREEN}✅ Archivo .env ya existe${NC}"
        
        # Verificar y agregar ORACLE_PWD si no existe
        if ! grep -q "ORACLE_PWD=" "$ENV_FILE"; then
            echo -e "${YELLOW}⚠️  ORACLE_PWD no está definido en .env${NC}"
            ORACLE_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            echo "ORACLE_PWD=$ORACLE_PWD" >> "$ENV_FILE"
            echo -e "${GREEN}✅ ORACLE_PWD agregado al archivo .env${NC}"
            echo -e "${CYAN}Contraseña Oracle: $ORACLE_PWD${NC}"
        fi
        
        # Verificar y agregar LOCAL_USER si no existe
        if ! grep -q "LOCAL_USER=" "$ENV_FILE"; then
            echo -e "${YELLOW}⚠️  LOCAL_USER no está definido en .env${NC}"
            LOCAL_USER="oracleuser"
            echo "LOCAL_USER=$LOCAL_USER" >> "$ENV_FILE"
            echo -e "${GREEN}✅ LOCAL_USER agregado al archivo .env${NC}"
        fi
        
        # Verificar y agregar LOCAL_PWD si no existe
        if ! grep -q "LOCAL_PWD=" "$ENV_FILE"; then
            echo -e "${YELLOW}⚠️  LOCAL_PWD no está definido en .env${NC}"
            LOCAL_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            echo "LOCAL_PWD=$LOCAL_PWD" >> "$ENV_FILE"
            echo -e "${GREEN}✅ LOCAL_PWD agregado al archivo .env${NC}"
            echo -e "${CYAN}Contraseña local: $LOCAL_PWD${NC}"
        fi
    fi
}

check_docker_compose() {
    echo -e "${BLUE}🔍 Verificando docker-compose...${NC}"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ Archivo docker-compose.yml no encontrado${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ docker-compose no está instalado${NC}"
        echo "Instala docker-compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    echo -e "${GREEN}✅ docker-compose está disponible${NC}"
}

pull_oracle_image() {
    if [[ "$1" == "--no-pull" ]]; then
        echo -e "${YELLOW}⏭️  Saltando descarga de imagen (--no-pull)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📥 Descargando imagen Oracle...${NC}"
    echo "Imagen: $ORACLE_IMAGE"
    echo ""
    
    if docker pull "$ORACLE_IMAGE"; then
        echo -e "${GREEN}✅ Imagen Oracle descargada exitosamente${NC}"
    else
        echo -e "${RED}❌ Error al descargar la imagen Oracle${NC}"
        return 1
    fi
}

start_oracle_container() {
    echo -e "${BLUE}🚀 Levantando contenedor Oracle...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    if $COMPOSE_CMD up -d; then
        echo -e "${GREEN}✅ Contenedor Oracle iniciado${NC}"
    else
        echo -e "${RED}❌ Error al iniciar el contenedor Oracle${NC}"
        return 1
    fi
}

verify_oracle_container() {
    echo -e "${BLUE}🔍 Verificando estado del contenedor Oracle...${NC}"
    
    echo -e "${YELLOW}⏳ Esperando que el contenedor se inicie (esto puede tomar varios minutos)...${NC}"
    
    if docker ps | grep -q "oracle-db"; then
        echo -e "${GREEN}✅ Contenedor Oracle está corriendo${NC}"
    else
        echo -e "${RED}❌ Contenedor Oracle no está corriendo${NC}"
        echo "Verifica los logs con: docker logs oracle-db"
        return 1
    fi
    
    echo -e "${YELLOW}⏳ Verificando healthcheck del contenedor...${NC}"
    for i in {1..30}; do
        if docker inspect oracle-db --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            echo -e "${GREEN}✅ Contenedor Oracle está saludable${NC}"
            break
        elif docker inspect oracle-db --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "unhealthy"; then
            echo -e "${RED}❌ Contenedor Oracle no está saludable${NC}"
            echo "Verifica los logs con: docker logs oracle-db"
            return 1
        else
            echo -n "."
            sleep 10
        fi
        
        if [[ $i -eq 30 ]]; then
            echo -e "${YELLOW}⚠️  Timeout esperando healthcheck, pero el contenedor está corriendo${NC}"
        fi
    done
}

# Función para crear usuario local de Oracle
create_local_user() {
    echo -e "${BLUE}👤 Creando usuario local de Oracle...${NC}"
    
    # Obtener credenciales del archivo .env
    local oracle_pwd=$(grep ORACLE_PWD .env | cut -d'=' -f2)
    local local_user=$(grep LOCAL_USER .env | cut -d'=' -f2)
    local local_pwd=$(grep LOCAL_PWD .env | cut -d'=' -f2)
    
    if [[ -z "$local_user" || -z "$local_pwd" ]]; then
        echo -e "${YELLOW}⚠️  LOCAL_USER o LOCAL_PWD no están definidos en .env${NC}"
        return 1
    fi
    
    # Convertir nombre de usuario a minúsculas (Oracle requirement)
    local_user=$(echo "$local_user" | tr '[:upper:]' '[:lower:]')
    
    echo "Usuario: $local_user"
    echo -e "${YELLOW}Esperando a que la base de datos esté completamente lista...${NC}"
    
    # Esperar a que la base de datos esté completamente lista
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -n "Intento $attempt/$max_attempts: "
        
        # Verificar si podemos conectarnos y ejecutar una consulta simple
        if docker exec oracle-db sqlplus -s system/$oracle_pwd@//localhost:1521/ORCLCDB <<< "SELECT 1 FROM DUAL;" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Base de datos lista${NC}"
            break
        else
            echo -e "${YELLOW}⏳ Esperando...${NC}"
            sleep 10
            ((attempt++))
        fi
        
        if [[ $attempt -gt $max_attempts ]]; then
            echo -e "${RED}❌ Timeout esperando que la base de datos esté lista${NC}"
            return 1
        fi
    done
    
    echo "Verificando si el usuario ya existe..."
    
    # Crear script SQL para verificar y crear usuario
    local sql_script="/tmp/create_user_$$.sql"
    
    cat > "$sql_script" << EOF
SET SERVEROUTPUT ON;
SET PAGESIZE 0;
SET FEEDBACK OFF;

-- Conectar al PDB (Pluggable Database) en lugar del CDB
ALTER SESSION SET CONTAINER = ORCLPDB1;

-- Verificar si el usuario ya existe y crearlo si no existe
DECLARE
    user_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM dba_users WHERE username = UPPER('$local_user');
    
    IF user_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE USER $local_user IDENTIFIED BY "$local_pwd"';
        EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE TABLE TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE VIEW TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE PROCEDURE TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE SEQUENCE TO $local_user';
        EXECUTE IMMEDIATE 'GRANT CREATE TRIGGER TO $local_user';
        EXECUTE IMMEDIATE 'GRANT UNLIMITED TABLESPACE TO $local_user';
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Usuario $local_user creado exitosamente en PDB');
    ELSE
        DBMS_OUTPUT.PUT_LINE('INFO: Usuario $local_user ya existe en PDB');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

-- Verificar que el usuario fue creado correctamente en el PDB
SELECT 'USER_INFO: ' || username || ' - ' || account_status || ' - ' || TO_CHAR(created, 'DD-MON-YYYY HH24:MI:SS') 
FROM dba_users WHERE username = UPPER('$local_user');

EXIT;
EOF

    # Ejecutar el script SQL
    echo -e "${YELLOW}Ejecutando script SQL para crear usuario...${NC}"
    
    if docker exec -i oracle-db sqlplus -s system/$oracle_pwd@//localhost:1521/ORCLCDB < "$sql_script" > /tmp/oracle_user_creation_$$.log 2>&1; then
        # Verificar si el usuario fue creado exitosamente
        if grep -q "SUCCESS: Usuario $local_user creado exitosamente" /tmp/oracle_user_creation_$$.log; then
            echo -e "${GREEN}✅ Usuario $local_user creado exitosamente${NC}"
        elif grep -q "INFO: Usuario $local_user ya existe" /tmp/oracle_user_creation_$$.log; then
            echo -e "${GREEN}✅ Usuario $local_user ya existe${NC}"
        elif grep -q "USER_INFO:" /tmp/oracle_user_creation_$$.log; then
            echo -e "${GREEN}✅ Usuario $local_user existe y está activo${NC}"
            # Mostrar información del usuario
            grep "USER_INFO:" /tmp/oracle_user_creation_$$.log | sed 's/USER_INFO: //'
        else
            echo -e "${YELLOW}⚠️  No se pudo determinar el estado del usuario${NC}"
            echo -e "${YELLOW}Verificando manualmente...${NC}"
            
            # Verificación manual
            local verify_script="/tmp/verify_user_$$.sql"
            cat > "$verify_script" << EOF
SET PAGESIZE 0;
SET FEEDBACK OFF;
ALTER SESSION SET CONTAINER = ORCLPDB1;
SELECT username || ' - ' || account_status || ' - ' || TO_CHAR(created, 'DD-MON-YYYY HH24:MI:SS') 
FROM dba_users WHERE username = UPPER('$local_user');
EXIT;
EOF
            
            local verify_result=$(docker exec -i oracle-db sqlplus -s system/$oracle_pwd@//localhost:1521/ORCLCDB < "$verify_script" 2>/dev/null | grep -v "^$" | head -1)
            
            if [[ -n "$verify_result" && "$verify_result" != *"no rows selected"* ]]; then
                echo -e "${GREEN}✅ Usuario $local_user existe y está activo${NC}"
                echo -e "${CYAN}Información: $verify_result${NC}"
            else
                echo -e "${RED}❌ Error al crear usuario $local_user${NC}"
                echo -e "${YELLOW}Logs del error:${NC}"
                cat /tmp/oracle_user_creation_$$.log
                rm -f "$sql_script" "$verify_script" /tmp/oracle_user_creation_$$.log
                return 1
            fi
            rm -f "$verify_script"
        fi
    else
        echo -e "${RED}❌ Error al ejecutar script SQL${NC}"
        echo -e "${YELLOW}Logs del error:${NC}"
        cat /tmp/oracle_user_creation_$$.log
        rm -f "$sql_script" /tmp/oracle_user_creation_$$.log
        return 1
    fi
    
    # Limpiar archivos temporales
    rm -f "$sql_script" /tmp/oracle_user_creation_$$.log
    
    echo -e "${GREEN}✅ Usuario local configurado correctamente${NC}"
    echo -e "${CYAN}Usuario: $local_user${NC}"
    echo -e "${CYAN}Contraseña: $local_pwd${NC}"
}

open_interactive_terminal() {
    echo -e "${BLUE}🖥️  Abriendo terminal interactivo...${NC}"
    
    local oracle_pwd=$(grep ORACLE_PWD .env | cut -d'=' -f2)
    local local_user=$(grep LOCAL_USER .env | cut -d'=' -f2)
    local local_pwd=$(grep LOCAL_PWD .env | cut -d'=' -f2)
    
    local temp_script="/tmp/oracle-interactive-$$.sh"
    
    cat > "$temp_script" << EOF
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "\${CYAN}🐘 Oracle Database Interactive Terminal\${NC}"
echo -e "\${CYAN}=====================================\${NC}"
echo ""
echo -e "\${YELLOW}Información de conexión:${NC}"
echo "  Host: localhost"
echo "  Puerto: 1520"
echo "  CDB: ORCLCDB"
echo "  PDB: ORCLPDB1"
echo ""
echo -e "\${YELLOW}Usuarios disponibles:${NC}"
echo "  system (CDB): $oracle_pwd"
echo "  $local_user (PDB): $local_pwd"
echo ""
echo -e "\${CYAN}📋 Detalles técnicos (Usuario Local):${NC}"
echo "  Service Name: ORCLPDB1"
echo "  Container: ORCLPDB1"
echo "  Connection String: //localhost:1520/ORCLPDB1"
echo "  JDBC URL: jdbc:oracle:thin:@//localhost:1520/ORCLPDB1"
echo ""
echo -e "\${YELLOW}Comandos disponibles:${NC}"
echo "  sqlplus    - Conectarse a Oracle SQL*Plus (system - CDB)"
echo "  local      - Conectarse como usuario local (PDB)"
echo "  info       - Mostrar información detallada de conexión"
echo "  logs       - Ver logs del contenedor"
echo "  status     - Ver estado del contenedor"
echo "  exit       - Salir del terminal interactivo"
echo ""
echo -e "\${GREEN}¡Oracle Database está listo para usar!${NC}"
echo ""

show_help() {
    echo -e "\${YELLOW}Comandos disponibles:${NC}"
    echo "  sqlplus    - Conectarse a Oracle SQL*Plus (system - CDB)"
    echo "  local      - Conectarse como usuario local (PDB)"
    echo "  info       - Mostrar información detallada de conexión"
    echo "  logs       - Ver logs del contenedor"
    echo "  status     - Ver estado del contenedor"
    echo "  help       - Mostrar esta ayuda"
    echo "  exit       - Salir del terminal interactivo"
    echo ""
    echo -e "\${YELLOW}Ejemplos de uso:${NC}"
    echo "  sqlplus system/$oracle_pwd@//localhost:1521/ORCLCDB"
    echo "  local $local_user/$local_pwd@//localhost:1521/ORCLPDB1"
}

show_connection_info() {
    echo -e "\${CYAN}📋 Información detallada de conexión${NC}"
    echo ""
    echo -e "\${YELLOW}Usuario Local (PDB):${NC}"
    echo "  Usuario: $local_user"
    echo "  Contraseña: $local_pwd"
    echo "  Service Name: ORCLPDB1"
    echo "  Container: ORCLPDB1"
    echo "  Database Type: Pluggable Database (PDB)"
    echo ""
    echo -e "\${YELLOW}URLs de conexión:${NC}"
    echo "  Connection String: //localhost:1520/ORCLPDB1"
    echo "  JDBC URL: jdbc:oracle:thin:@//localhost:1520/ORCLPDB1"
    echo "  SQL*Plus: $local_user/$local_pwd@//localhost:1520/ORCLPDB1"
    echo ""
    echo -e "\${YELLOW}Herramientas de desarrollo:${NC}"
    echo "  SQL Developer: localhost:1520/ORCLPDB1"
    echo "  DBeaver: localhost:1520/ORCLPDB1"
    echo "  Toad: localhost:1520/ORCLPDB1"
    echo "  DataGrip: localhost:1520/ORCLPDB1"
    echo ""
    echo -e "\${YELLOW}Usuario System (CDB):${NC}"
    echo "  Usuario: system"
    echo "  Contraseña: $oracle_pwd"
    echo "  Service Name: ORCLCDB"
    echo "  Container: ORCLCDB"
    echo "  Database Type: Container Database (CDB)"
}

connect_sqlplus() {
    echo -e "\${BLUE}Conectándose a Oracle SQL*Plus como system...${NC}"
    docker exec -it oracle-db sqlplus system/$oracle_pwd@//localhost:1521/ORCLCDB
}

connect_local() {
    echo -e "\${BLUE}Conectándose a Oracle SQL*Plus como usuario local...${NC}"
    docker exec -it oracle-db sqlplus $local_user/$local_pwd@//localhost:1521/ORCLPDB1
}

show_logs() {
    echo -e "\${BLUE}Mostrando logs del contenedor Oracle...${NC}"
    docker logs oracle-db --tail 50 -f
}

show_status() {
    echo -e "\${BLUE}Estado del contenedor Oracle:${NC}"
    docker ps | grep oracle-db
    echo ""
    echo -e "\${BLUE}Healthcheck:${NC}"
    docker inspect oracle-db --format='{{.State.Health.Status}}' 2>/dev/null || echo "No disponible"
}

while true; do
    echo -n -e "\${CYAN}oracle@container:\${NC} "
    read -r command
    
    case \$command in
        sqlplus)
            connect_sqlplus
            ;;
        local)
            connect_local
            ;;
        info)
            show_connection_info
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        help)
            show_help
            ;;
        exit|quit)
            echo -e "\${GREEN}¡Hasta luego!${NC}"
            break
            ;;
        "")
            ;;
        *)
            echo -e "\${RED}Comando no reconocido: \$command${NC}"
            echo "Usa 'help' para ver los comandos disponibles"
            ;;
    esac
    echo ""
done

rm -f "$temp_script"
EOF

    chmod +x "$temp_script"
    
    if [[ -n "$DISPLAY" ]] && command -v xterm &> /dev/null; then
        xterm -title "Oracle Database Interactive Terminal" -e "bash $temp_script" &
        echo -e "${GREEN}✅ Terminal interactivo abierto en nueva ventana${NC}"
    elif [[ -n "$DISPLAY" ]] && command -v gnome-terminal &> /dev/null; then
        gnome-terminal --title="Oracle Database Interactive Terminal" -- bash -c "$temp_script; exec bash" &
        echo -e "${GREEN}✅ Terminal interactivo abierto en nueva ventana${NC}"
    elif [[ -n "$DISPLAY" ]] && command -v konsole &> /dev/null; then
        konsole --title "Oracle Database Interactive Terminal" -e bash -c "$temp_script; exec bash" &
        echo -e "${GREEN}✅ Terminal interactivo abierto en nueva ventana${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]] && command -v osascript &> /dev/null; then
        osascript -e "tell application \"Terminal\" to do script \"bash $temp_script\""
        echo -e "${GREEN}✅ Terminal interactivo abierto en nueva ventana${NC}"
    elif [[ -n "$WT_SESSION" ]] && command -v wt &> /dev/null; then
        wt bash -c "$temp_script; exec bash" &
        echo -e "${GREEN}✅ Terminal interactivo abierto en nueva ventana${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo abrir nueva ventana, ejecutando en terminal actual${NC}"
        echo -e "${YELLOW}Presiona Ctrl+C para salir del modo interactivo${NC}"
        bash "$temp_script"
    fi
}

show_connection_info() {
    echo ""
    echo -e "${CYAN}🎉 Oracle Database está listo!${NC}"
    echo ""
    echo -e "${YELLOW}Información de conexión:${NC}"
    echo "  Host: localhost"
    echo "  Puerto: 1520"
    echo "  CDB: ORCLCDB"
    echo "  PDB: ORCLPDB1"
    echo ""
    echo -e "${YELLOW}Usuarios disponibles:${NC}"
    echo "  Usuario administrador (system):"
    echo "    Usuario: system"
    echo "    Contraseña: $(grep ORACLE_PWD .env | cut -d'=' -f2)"
    echo "    Base de datos: ORCLCDB (CDB)"
    echo ""
    echo "  Usuario local:"
    echo "    Usuario: $(grep LOCAL_USER .env | cut -d'=' -f2)"
    echo "    Contraseña: $(grep LOCAL_PWD .env | cut -d'=' -f2)"
    echo "    Base de datos: ORCLPDB1 (PDB)"
    echo ""
    echo -e "${CYAN}📋 Detalles técnicos de conexión (Usuario Local):${NC}"
    echo "  Service Name: ORCLPDB1"
    echo "  Container: ORCLPDB1"
    echo "  Database Type: Pluggable Database (PDB)"
    echo "  Connection String: //localhost:1520/ORCLPDB1"
    echo "  JDBC URL: jdbc:oracle:thin:@//localhost:1520/ORCLPDB1"
    echo "  TNS Entry: ORCLPDB1"
    echo ""
    echo -e "${CYAN}🔗 URLs de conexión (Usuario Local):${NC}"
    echo "  SQL*Plus: \$(grep LOCAL_USER .env | cut -d'=' -f2)/\$(grep LOCAL_PWD .env | cut -d'=' -f2)@//localhost:1520/ORCLPDB1"
    echo "  SQL Developer: localhost:1520/ORCLPDB1"
    echo "  DBeaver: localhost:1520/ORCLPDB1"
    echo "  Toad: localhost:1520/ORCLPDB1"
    echo ""
    echo -e "${YELLOW}Comandos útiles:${NC}"
    echo "  Conectarse como system (CDB):"
    echo "    docker exec -it oracle-db sqlplus system/\$(grep ORACLE_PWD .env | cut -d'=' -f2)@//localhost:1521/ORCLCDB"
    echo ""
    echo "  Conectarse como usuario local (PDB):"
    echo "    docker exec -it oracle-db sqlplus \$(grep LOCAL_USER .env | cut -d'=' -f2)/\$(grep LOCAL_PWD .env | cut -d'=' -f2)@//localhost:1521/ORCLPDB1"
    echo ""
    echo "  Ver logs:"
    echo "    docker logs oracle-db"
    echo ""
    echo "  Parar el contenedor:"
    echo "    docker-compose down"
    echo ""
    echo "  Reiniciar el contenedor:"
    echo "    docker-compose restart"
    echo ""
    echo -e "${CYAN}🖥️  Terminal interactivo disponible${NC}"
    echo "  El script abrirá una nueva ventana con terminal interactivo"
    echo "  donde podrás ejecutar comandos de Oracle directamente"
}

main() {
    local force_login=false
    local no_pull=false
    local no_terminal=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_login=true
                shift
                ;;
            --no-pull)
                no_pull=true
                shift
                ;;
            --no-terminal)
                no_terminal=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción desconocida: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}🚀 Iniciando setup de Oracle Database${NC}"
    echo ""
    
    check_docker
    echo ""
    
    if ! check_oracle_access; then
        echo ""
        if [[ "$force_login" == true ]]; then
            echo -e "${YELLOW}Forzando nuevo login...${NC}"
            docker logout "$ORACLE_REGISTRY" 2>/dev/null || true
        fi
        do_oracle_login
        echo ""
    fi
    
    setup_environment
    echo ""
    
    check_docker_compose
    echo ""
    
    if [[ "$no_pull" == false ]]; then
        pull_oracle_image
        echo ""
    fi
    
    start_oracle_container
    echo ""
    
    verify_oracle_container
    echo ""
    
    # Paso 8: Crear usuario local
    create_local_user
    echo ""
    
    show_connection_info
    
    if [[ "$no_terminal" == false ]]; then
        echo ""
        open_interactive_terminal
    else
        echo ""
        echo -e "${YELLOW}Terminal interactivo deshabilitado (--no-terminal)${NC}"
    fi
}

main "$@"