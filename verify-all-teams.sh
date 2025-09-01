#!/bin/bash
# 🚀 Script Master de Verificación - Todos los Equipos
# Curso: Infra Made Easy

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  🚀 INFRA MADE EASY                         ║"
echo "║              Verificación de Todos los Equipos              ║"
echo "║                                                              ║"
echo "║  📊 Monitoring  🌐 WebServer SSL  🛡️ Security  🔧 CI/CD      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Función para mostrar ayuda
show_help() {
    echo -e "${YELLOW}Uso: $0 [OPCIÓN]${NC}"
    echo ""
    echo "OPCIONES:"
    echo "  all         Verificar todos los equipos (por defecto)"
    echo "  monitoring  Verificar solo equipo de monitoring"
    echo "  webserver   Verificar solo equipo de webserver SSL"
    echo "  security    Verificar solo equipo de security"
    echo "  -h, --help  Mostrar esta ayuda"
    echo ""
    echo "EJEMPLOS:"
    echo "  $0                    # Verifica todos los equipos"
    echo "  $0 monitoring         # Solo monitoring"
    echo "  $0 webserver          # Solo webserver SSL"
    echo "  $0 security           # Solo security"
}

# Función para verificar conectividad general
check_connectivity() {
    echo -e "\n${YELLOW}🔍 Verificación general de conectividad...${NC}"
    
    # Verificar que ansible esté disponible
    if ! command -v ansible &> /dev/null; then
        echo -e "${RED}❌ Ansible no está instalado o no está en el PATH${NC}"
        exit 1
    fi
    
    # Verificar conectividad con todos los servidores
    echo -e "${CYAN}Verificando conectividad con todos los servidores...${NC}"
    if ansible all -m ping > /dev/null 2>&1; then
        server_count=$(ansible all --list-hosts 2>/dev/null | grep -c "hosts" || echo "0")
        echo -e "${GREEN}✅ $server_count servidores accesibles${NC}"
    else
        echo -e "${RED}❌ Algunos servidores no son accesibles${NC}"
        echo -e "${YELLOW}Continuando con la verificación individual...${NC}"
    fi
}

# Función para mostrar resumen final
show_summary() {
    echo -e "\n${BLUE}${BOLD}📋 RESUMEN FINAL${NC}"
    echo "=================="
    
    echo -e "\n${CYAN}📊 STACK DE MONITORING:${NC}"
    echo "   Dashboard: http://34.122.207.0:3000 (admin/admin123)"
    echo "   Prometheus: http://34.122.207.0:9090"
    echo "   Node Exporter: http://34.122.207.0:9100/metrics"
    
    echo -e "\n${CYAN}🌐 WEBSERVER SSL:${NC}"
    echo "   HTTP: http://[servidor-web] (redirige a HTTPS)"
    echo "   HTTPS: https://[dominio-configurado]"
    echo "   Status: nginx -t"
    
    echo -e "\n${CYAN}🛡️ SECURITY AUDIT:${NC}"
    echo "   Dashboard: http://[servidor-security]/lynis-dashboard/"
    echo "   Métricas: http://[servidor-security]:9114/metrics"
    echo "   Auditoría: lynis audit system"
    
    echo -e "\n${YELLOW}📚 RECURSOS Y COMANDOS:${NC}"
    echo "=========================="
    echo "# Verificaciones individuales:"
    echo "./verify-monitoring.sh       # Stack Prometheus + Grafana"
    echo "./verify-webserver-ssl.sh    # Servidores web con SSL"
    echo "./verify-security-lynis.sh   # Auditoría de seguridad"
    echo ""
    echo "# Desplegar servicios:"
    echo "ansible-playbook setup-monitoring.yml   # Stack monitoring"
    echo "ansible-playbook setup-webserver-ssl.yml # Webserver + SSL"
    echo "ansible-playbook setup-security.yml     # Security audit"
    echo ""
    echo "# Ver inventario:"
    echo "ansible-inventory --graph               # Estructura de servidores"
    echo "ansible all --list-hosts               # Lista de hosts"
}

# Función principal para ejecutar verificaciones
run_verification() {
    local team=$1
    
    case $team in
        "monitoring")
            if [ -f "./verify-monitoring.sh" ]; then
                echo -e "\n${BLUE}🚀 Ejecutando verificación de MONITORING...${NC}"
                ./verify-monitoring.sh
            else
                echo -e "${RED}❌ Script verify-monitoring.sh no encontrado${NC}"
            fi
            ;;
        "webserver")
            if [ -f "./verify-webserver-ssl.sh" ]; then
                echo -e "\n${BLUE}🚀 Ejecutando verificación de WEBSERVER SSL...${NC}"
                ./verify-webserver-ssl.sh
            else
                echo -e "${RED}❌ Script verify-webserver-ssl.sh no encontrado${NC}"
            fi
            ;;
        "security")
            if [ -f "./verify-security-lynis.sh" ]; then
                echo -e "\n${BLUE}🚀 Ejecutando verificación de SECURITY...${NC}"
                ./verify-security-lynis.sh
            else
                echo -e "${RED}❌ Script verify-security-lynis.sh no encontrado${NC}"
            fi
            ;;
        "all")
            echo -e "\n${PURPLE}🔄 Ejecutando verificación completa de todos los equipos...${NC}"
            
            # Ejecutar todas las verificaciones
            run_verification "monitoring"
            run_verification "webserver"
            run_verification "security"
            ;;
    esac
}

# Verificar argumentos
case ${1:-all} in
    -h|--help)
        show_help
        exit 0
        ;;
    all|monitoring|webserver|security)
        TEAM=${1:-all}
        ;;
    *)
        echo -e "${RED}❌ Opción no válida: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

# Verificación de prerequisitos
echo -e "${YELLOW}🔧 Verificando prerequisitos...${NC}"

# Verificar que estamos en el directorio correcto
if [ ! -f "ansible.cfg" ]; then
    echo -e "${RED}❌ No se encontró ansible.cfg. ¿Estás en el directorio correcto?${NC}"
    exit 1
fi

if [ ! -f "inventory/hosts" ]; then
    echo -e "${RED}❌ No se encontró inventory/hosts${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisitos verificados${NC}"

# Ejecutar verificación de conectividad general
check_connectivity

# Ejecutar verificaciones según el equipo seleccionado
echo -e "\n${BOLD}${BLUE}🎯 Iniciando verificaciones para: ${TEAM^^}${NC}"
run_verification $TEAM

# Mostrar resumen final
show_summary

echo -e "\n${GREEN}${BOLD}🎉 Verificación completada para el equipo: ${TEAM^^}${NC}"
echo -e "${CYAN}Para más detalles, revisar los logs individuales de cada script.${NC}"
