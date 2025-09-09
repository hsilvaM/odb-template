#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}Oracle Container Registry Login Script${NC}"
    echo ""
    echo "Uso:"
    echo "  $0 [username] [password]"
    echo "  $0 --force"
    echo "  $0 --help"
    echo ""
    echo "Opciones:"
    echo "  --force         Fuerza el login aunque ya estés logueado"
    echo "  --help          Muestra esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 tu-email@ejemplo.com tu-password"
    echo "  $0 --force"
    echo ""
    echo "El script verificará automáticamente si ya estás logueado"
}

check_login_status() {
    echo -e "${BLUE}Verificando acceso al Oracle Container Registry...${NC}"
    
    if docker manifest inspect container-registry.oracle.com/database/enterprise:19.3.0.0 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Tienes acceso al repositorio Oracle${NC}"
        return 0
    fi
    
    if docker system info 2>/dev/null | grep -q "container-registry.oracle.com"; then
        echo -e "${YELLOW}⚠️  Tienes credenciales guardadas pero no puedes acceder al repositorio${NC}"
        echo -e "${YELLOW}   Es posible que las credenciales hayan expirado${NC}"
        return 1
    fi
    
    if docker images container-registry.oracle.com/database/enterprise:19.3.0.0 --format "{{.Repository}}:{{.Tag}}" | grep -q "container-registry.oracle.com/database/enterprise:19.3.0.0"; then
        echo -e "${GREEN}✅ La imagen Oracle ya está disponible localmente${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}❌ No tienes acceso al repositorio Oracle${NC}"
    return 1
}

do_login() {
    local username="$1"
    local password="$2"
    
    echo -e "${BLUE}Intentando hacer login en Oracle Container Registry...${NC}"
    echo "Registry: container-registry.oracle.com"
    echo "Usuario: $username"
    echo ""
    
    if echo "$password" | docker login container-registry.oracle.com --username "$username" --password-stdin; then
        echo -e "${GREEN}✅ Login exitoso!${NC}"
        echo ""
        echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
        echo "  docker-compose up -d"
        echo ""
        echo -e "${YELLOW}Para conectarte a la base de datos:${NC}"
        echo "  docker exec -it oracle-db sqlplus system/\$ORACLE_PWD@//localhost:1521/ORCLCDB"
        return 0
    else
        echo -e "${RED}❌ Error en el login${NC}"
        echo ""
        echo -e "${YELLOW}Posibles causas:${NC}"
        echo "  - Credenciales incorrectas"
        echo "  - No tienes acceso al registry"
        echo "  - Problemas de conectividad"
        echo ""
        echo -e "${YELLOW}Verifica que:${NC}"
        echo "  - Tu cuenta Oracle esté activa"
        echo "  - Hayas aceptado los términos de uso del registry"
        echo "  - Tu email y contraseña sean correctos"
        return 1
    fi
}

interactive_login() {
    echo -e "${BLUE}Oracle Container Registry Login${NC}"
    echo ""
    
    if check_login_status; then
        echo -e "${GREEN}✅ Ya estás logueado en Oracle Container Registry${NC}"
        echo ""
        echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
        echo "  docker-compose up -d"
        echo ""
        echo -e "${YELLOW}Para conectarte a la base de datos:${NC}"
        echo "  docker exec -it oracle-db sqlplus system/\$ORACLE_PWD@//localhost:1521/ORCLCDB"
        return 0
    fi
    
    echo -e "${YELLOW}No estás logueado en Oracle Container Registry${NC}"
    echo -e "${YELLOW}Ingresa tus credenciales:${NC}"
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
    do_login "$username" "$password"
}

check_docker() {
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
}

main() {
    check_docker
    
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --force|-f)
            echo -e "${BLUE}Forzando login en Oracle Container Registry...${NC}"
            echo ""
            if check_login_status; then
                echo -e "${YELLOW}Haciendo logout primero...${NC}"
                docker logout container-registry.oracle.com
            fi
            interactive_login
            ;;
        "")
            interactive_login
            ;;
        *)
            if [[ -z "$2" ]]; then
                echo -e "${RED}❌ Error: Debes proporcionar tanto usuario como contraseña${NC}"
                echo "Uso: $0 [username] [password]"
                echo "O usa: $0 (modo interactivo)"
                exit 1
            fi
            
            if check_login_status; then
                echo -e "${GREEN}✅ Ya estás logueado en Oracle Container Registry${NC}"
                echo ""
                echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
                echo "  docker-compose up -d"
                echo ""
                echo -e "${YELLOW}Para conectarte a la base de datos:${NC}"
                echo "  docker exec -it oracle-db sqlplus system/\$ORACLE_PWD@//localhost:1521/ORCLCDB"
                exit 0
            fi
            
            username="$1"
            password="$2"
            do_login "$username" "$password"
            ;;
    esac
}

main "$@"
