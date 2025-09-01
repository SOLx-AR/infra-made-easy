#!/bin/bash
# 🔍 Script de Verificación Completa del Proyecto
# Curso: Infra Made Easy

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            🔍 VERIFICACIÓN COMPLETA DEL PROYECTO             ║"
echo "║                     INFRA MADE EASY                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Contadores
total_checks=0
passed_checks=0

check_item() {
    local description="$1"
    local command="$2"
    local expected_result="$3"
    
    ((total_checks++))
    echo -ne "${CYAN}Verificando: ${description}... ${NC}"
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        ((passed_checks++))
    else
        echo -e "${RED}❌ FALLO${NC}"
        if [ ! -z "$expected_result" ]; then
            echo -e "  ${YELLOW}Esperado: $expected_result${NC}"
        fi
    fi
}

echo -e "\n${YELLOW}📁 1. Verificando estructura del proyecto...${NC}"
check_item "README.md existe" "test -f README.md"
check_item "ansible.cfg existe" "test -f ansible.cfg"
check_item "inventory/hosts existe" "test -f inventory/hosts"
check_item "requirements.txt existe" "test -f requirements.txt"
check_item "requirements.yml existe" "test -f requirements.yml"

echo -e "\n${YELLOW}📋 2. Verificando playbooks principales...${NC}"
check_item "etapa1-webserver-basico.yml" "test -f etapa1-webserver-basico.yml"
check_item "setup-monitoring.yml" "test -f setup-monitoring.yml"
check_item "setup-webserver-ssl.yml" "test -f setup-webserver-ssl.yml"
check_item "setup-security.yml" "test -f setup-security.yml"
check_item "setup-cicd.yml" "test -f setup-cicd.yml"
check_item "setup-traefik.yml" "test -f setup-traefik.yml"

echo -e "\n${YELLOW}🔧 3. Verificando scripts de verificación...${NC}"
check_item "verify-setup.sh executable" "test -x verify-setup.sh"
check_item "verify-monitoring.sh executable" "test -x verify-monitoring.sh"
check_item "verify-webserver-ssl.sh executable" "test -x verify-webserver-ssl.sh"
check_item "verify-security-lynis.sh executable" "test -x verify-security-lynis.sh"
check_item "verify-all-teams.sh executable" "test -x verify-all-teams.sh"
check_item "activate-env.sh executable" "test -x activate-env.sh"

echo -e "\n${YELLOW}🧩 4. Verificando roles principales...${NC}"
roles=("common" "nginx" "docker" "prometheus" "grafana" "letsencrypt" "lynis" "fail2ban" "jenkins" "traefik" "node-exporter")

for role in "${roles[@]}"; do
    check_item "Role $role existe" "test -d roles/$role"
    check_item "Role $role/tasks/main.yml" "test -f roles/$role/tasks/main.yml"
    check_item "Role $role/defaults/main.yml" "test -f roles/$role/defaults/main.yml"
done

echo -e "\n${YELLOW}🌐 5. Verificando rol letsencrypt (SSL)...${NC}"
check_item "letsencrypt tasks" "test -f roles/letsencrypt/tasks/main.yml"
check_item "letsencrypt defaults" "test -f roles/letsencrypt/defaults/main.yml"
check_item "letsencrypt handlers" "test -f roles/letsencrypt/handlers/main.yml"
check_item "nginx-ssl template" "test -f roles/letsencrypt/templates/nginx-ssl.conf.j2"
check_item "nginx-acme template" "test -f roles/letsencrypt/templates/nginx-acme-temp.conf.j2"

echo -e "\n${YELLOW}🛡️ 6. Verificando rol lynis (Security)...${NC}"
check_item "lynis tasks" "test -f roles/lynis/tasks/main.yml"
check_item "lynis defaults" "test -f roles/lynis/defaults/main.yml"
check_item "lynis handlers" "test -f roles/lynis/handlers/main.yml"
check_item "security exporter" "test -f roles/lynis/templates/security-exporter.py.j2"
check_item "lynis dashboard" "test -f roles/lynis/templates/lynis-dashboard.html.j2"
check_item "lynis config" "test -f roles/lynis/templates/lynis.conf.j2"

echo -e "\n${YELLOW}📊 7. Verificando rol grafana (Monitoring)...${NC}"
check_item "grafana tasks" "test -f roles/grafana/tasks/main.yml"
check_item "grafana defaults" "test -f roles/grafana/defaults/main.yml" 
check_item "grafana handlers" "test -f roles/grafana/handlers/main.yml"
check_item "grafana config" "test -f roles/grafana/templates/grafana.ini.j2"
check_item "grafana datasources" "test -f roles/grafana/templates/datasources.yml.j2"
check_item "grafana dashboards" "test -f roles/grafana/templates/dashboards.yml.j2"
check_item "custom dashboard" "test -f roles/grafana/templates/infrastructure-dashboard.json.j2"

echo -e "\n${YELLOW}⚙️ 8. Verificando configuración Ansible...${NC}"
check_item "ansible-config válido" "ansible-config dump --only-changed > /dev/null"
check_item "inventory válido" "ansible-inventory --graph > /dev/null"
check_item "roles_path configurado" "ansible-config dump | grep -q roles"
check_item "inventory configurado" "ansible-config dump | grep -q inventory/hosts"

echo -e "\n${YELLOW}👥 9. Verificando estructura de usuarios...${NC}"
check_item "directorio users/" "test -d users"
check_item "users.yml existe" "test -f users.yml"
check_item "ejemplo juan/id_rsa.pub" "test -f users/juan/id_rsa.pub"
check_item "ejemplo maria/id_rsa.pub" "test -f users/maria/id_rsa.pub"
check_item "ejemplo nico/id_rsa.pub" "test -f users/nico/id_rsa.pub"

echo -e "\n${YELLOW}📚 10. Verificando documentación...${NC}"
check_item "docs/ directory" "test -d docs"
check_item "MONITORING-STACK.md" "test -f docs/MONITORING-STACK.md"
check_item "README.md no vacío" "test -s README.md"
check_item "README contiene badges" "grep -q 'Ansible' README.md"
check_item "README contiene mermaid" "grep -q 'mermaid' README.md"

# Verificaciones de contenido específico
echo -e "\n${YELLOW}🔍 11. Verificando contenido específico...${NC}"
check_item "Playbook monitoring usa grafana role" "grep -q 'grafana' setup-monitoring.yml"
check_item "Playbook SSL usa letsencrypt role" "grep -q 'letsencrypt' setup-webserver-ssl.yml"
check_item "Playbook security usa lynis role" "grep -q 'lynis' setup-security.yml"
check_item "Inventory tiene monitoring_servers" "grep -q 'monitoring_servers' inventory/hosts"
check_item "Inventory tiene webserver_ssl_servers" "grep -q 'webserver_ssl_servers' inventory/hosts"
check_item "Inventory tiene security_servers" "grep -q 'security_servers' inventory/hosts"

# Resumen final
echo -e "\n${BLUE}${BOLD}📊 RESUMEN DE VERIFICACIÓN:${NC}"
echo "=============================="
echo -e "${CYAN}Total verificaciones: $total_checks${NC}"
echo -e "${GREEN}Verificaciones exitosas: $passed_checks${NC}"

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}${BOLD}🎉 ¡PROYECTO COMPLETAMENTE VERIFICADO!${NC}"
    echo -e "${GREEN}✅ Todos los componentes están correctamente configurados${NC}"
    exit 0
else
    failed_checks=$((total_checks - passed_checks))
    echo -e "${RED}Verificaciones fallidas: $failed_checks${NC}"
    echo -e "${YELLOW}⚠️ Algunos componentes necesitan atención${NC}"
    
    # Sugerir soluciones
    echo -e "\n${BLUE}💡 PASOS SUGERIDOS PARA RESOLVER:${NC}"
    echo "1. Revisar los elementos marcados con ❌"
    echo "2. Ejecutar: ./activate-env.sh"
    echo "3. Verificar permisos: chmod +x *.sh"
    echo "4. Re-ejecutar este script"
    
    exit 1
fi
