#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔍 Diagnóstico de Oracle Database${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Verificar que el archivo .env existe
if [[ -f ".env" ]]; then
    echo -e "${GREEN}✅ Archivo .env encontrado${NC}"
    source .env
else
    echo -e "${RED}❌ Archivo .env no encontrado${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Información del entorno:${NC}"
echo "ORACLE_PWD: $ORACLE_PWD"
echo "LOCAL_USER: $LOCAL_USER"
echo "LOCAL_PWD: $LOCAL_PWD"
echo ""

# Verificar contenedor
echo -e "${BLUE}🐳 Verificando contenedor:${NC}"
if docker ps | grep -q "oracle-db"; then
    echo -e "${GREEN}✅ Contenedor oracle-db está corriendo${NC}"
    docker ps | grep oracle-db
else
    echo -e "${RED}❌ Contenedor oracle-db no está corriendo${NC}"
    echo "Ejecuta: docker-compose up -d"
    exit 1
fi

echo ""

# Verificar listener
echo -e "${BLUE}🔊 Verificando listener:${NC}"
if docker exec oracle-db lsnrctl status >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Listener está activo${NC}"
    
    # Mostrar servicios registrados
    echo -e "${YELLOW}📋 Servicios registrados:${NC}"
    docker exec oracle-db lsnrctl services 2>/dev/null | grep -E "Service|Instance" || echo "No hay servicios registrados aún"
else
    echo -e "${RED}❌ Listener no está activo${NC}"
fi

echo ""

# Verificar conectividad CDB
echo -e "${BLUE}🔗 Verificando conectividad CDB:${NC}"
cdb_test=$(echo "SELECT 1 FROM DUAL;" | docker exec -i oracle-db sqlplus -s system/$ORACLE_PWD@//localhost:1521/ORCLCDB 2>&1)
if echo "$cdb_test" | grep -q "ORA-01017"; then
    echo -e "${RED}❌ CDB (ORCLCDB) - Error ORA-01017: Invalid username/password${NC}"
    echo -e "${YELLOW}💡 Soluciones:${NC}"
    echo "  1. Regenerar contraseña: rm .env && ./setup-oracle.sh"
    echo "  2. Verificar que el contenedor esté completamente inicializado"
    echo "  3. Reiniciar: docker-compose restart"
elif echo "$cdb_test" | grep -q "ORA-12541"; then
    echo -e "${RED}❌ CDB (ORCLCDB) - Error ORA-12541: TNS no listener${NC}"
    echo -e "${YELLOW}💡 El listener no está activo${NC}"
elif echo "$cdb_test" | grep -q "ORA-12514"; then
    echo -e "${RED}❌ CDB (ORCLCDB) - Error ORA-12514: TNS service not found${NC}"
    echo -e "${YELLOW}💡 El servicio no está registrado${NC}"
elif echo "$cdb_test" | grep -q "1"; then
    echo -e "${GREEN}✅ CDB (ORCLCDB) es accesible${NC}"
else
    echo -e "${RED}❌ CDB (ORCLCDB) no es accesible${NC}"
    echo -e "${YELLOW}Error: $(echo "$cdb_test" | grep -i "ora-" | head -1)${NC}"
fi

echo ""

# Verificar conectividad PDB
echo -e "${BLUE}🔗 Verificando conectividad PDB:${NC}"
pdb_test=$(echo "SELECT 1 FROM DUAL;" | docker exec -i oracle-db sqlplus -s system/$ORACLE_PWD@//localhost:1521/ORCLPDB1 2>&1)
if echo "$pdb_test" | grep -q "ORA-01017"; then
    echo -e "${RED}❌ PDB (ORCLPDB1) - Error ORA-01017: Invalid username/password${NC}"
    echo -e "${YELLOW}💡 Soluciones:${NC}"
    echo "  1. Regenerar contraseña: rm .env && ./setup-oracle.sh"
    echo "  2. Verificar que el contenedor esté completamente inicializado"
    echo "  3. Reiniciar: docker-compose restart"
elif echo "$pdb_test" | grep -q "ORA-12541"; then
    echo -e "${RED}❌ PDB (ORCLPDB1) - Error ORA-12541: TNS no listener${NC}"
    echo -e "${YELLOW}💡 El listener no está activo${NC}"
elif echo "$pdb_test" | grep -q "ORA-12514"; then
    echo -e "${RED}❌ PDB (ORCLPDB1) - Error ORA-12514: TNS service not found${NC}"
    echo -e "${YELLOW}💡 El servicio no está registrado${NC}"
elif echo "$pdb_test" | grep -q "1"; then
    echo -e "${GREEN}✅ PDB (ORCLPDB1) es accesible${NC}"
else
    echo -e "${RED}❌ PDB (ORCLPDB1) no es accesible${NC}"
    echo -e "${YELLOW}Error: $(echo "$pdb_test" | grep -i "ora-" | head -1)${NC}"
fi

echo ""

# Verificar estado del PDB
echo -e "${BLUE}📊 Verificando estado del PDB:${NC}"
pdb_status=$(echo "SELECT name, open_mode FROM v\$pdbs WHERE name = 'ORCLPDB1';" | docker exec -i oracle-db sqlplus -s system/$ORACLE_PWD@//localhost:1521/ORCLCDB 2>/dev/null | grep -v "^$" | grep -v "SQL>" | grep -v "Connected" | head -1)
if [[ -n "$pdb_status" ]]; then
    echo -e "${GREEN}✅ Estado del PDB: $pdb_status${NC}"
else
    echo -e "${RED}❌ No se pudo obtener el estado del PDB${NC}"
fi

echo ""

# Verificar si el usuario local existe
echo -e "${BLUE}👤 Verificando usuario local:${NC}"
if [[ -n "$LOCAL_USER" ]]; then
    # Verificar usuario de forma simple
    user_count=$(echo "SELECT COUNT(*) FROM dba_users WHERE username = UPPER('$LOCAL_USER');" | docker exec -i oracle-db sqlplus -s system/$ORACLE_PWD@//localhost:1521/ORCLPDB1 2>/dev/null | awk '/^[[:space:]]*[0-9]+[[:space:]]*$/ {print $1}')
    
    if [[ "$user_count" == "1" ]]; then
        echo -e "${GREEN}✅ Usuario $LOCAL_USER existe${NC}"
        
        # Verificar estado del usuario
        # Verificar estado del usuario de forma simple
        user_status=$(echo "SELECT username, account_status FROM dba_users WHERE username = UPPER('$LOCAL_USER');" | docker exec -i oracle-db sqlplus -s system/$ORACLE_PWD@//localhost:1521/ORCLPDB1 2>/dev/null | grep -v "^$" | grep -v "SQL>" | grep -v "Connected" | grep -v "Disconnected" | grep -v "USERNAME" | grep -v "\-\-\-" | tail -1)
        echo -e "${CYAN}Estado: $user_status${NC}"
    elif [[ "$user_count" == "0" ]]; then
        echo -e "${YELLOW}⚠️  Usuario $LOCAL_USER no existe${NC}"
    else
        echo -e "${RED}❌ Error al verificar usuario $LOCAL_USER${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  LOCAL_USER no está definido${NC}"
fi

echo ""

# Verificar logs recientes
echo -e "${BLUE}📋 Logs recientes del contenedor:${NC}"
docker logs oracle-db --tail 10 2>/dev/null | tail -5

echo ""
echo -e "${BLUE}💡 Comandos útiles para diagnóstico:${NC}"
echo "  Ver logs completos: docker logs oracle-db"
echo "  Conectar a CDB: docker exec -it oracle-db sqlplus system/$ORACLE_PWD@//localhost:1521/ORCLCDB"
echo "  Conectar a PDB: docker exec -it oracle-db sqlplus system/$ORACLE_PWD@//localhost:1521/ORCLPDB1"
echo "  Ver servicios: docker exec oracle-db lsnrctl services"
echo "  Reiniciar: docker-compose restart"
