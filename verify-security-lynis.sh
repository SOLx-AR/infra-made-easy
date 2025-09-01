#!/bin/bash
# 🛡️ Script de Verificación - Security Lynis
# Curso: Infra Made Easy - Equipo Security

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuración (ajustar según inventario)
SECURITY_GROUP="security_servers"
SECURITY_EXPORTER_PORT=9114

echo -e "${BLUE}🛡️ Verificando Security Audit - Infra Made Easy${NC}"
echo "================================================"

# 1. Verificar conectividad con servidores de seguridad
echo -e "\n${YELLOW}📡 1. Verificando conectividad con servidores de seguridad...${NC}"
if ansible $SECURITY_GROUP -m ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Servidores de seguridad accesibles${NC}"
    server_count=$(ansible $SECURITY_GROUP --list-hosts 2>/dev/null | grep -c "hosts" || echo "0")
    echo -e "${CYAN}📊 Servidores configurados: $server_count${NC}"
else
    echo -e "${RED}❌ No se puede conectar a los servidores de seguridad${NC}"
    exit 1
fi

# 2. Verificar servicios de seguridad
echo -e "\n${YELLOW}🔧 2. Verificando servicios de seguridad...${NC}"
services=("lynis" "fail2ban" "nginx" "node-exporter" "security-exporter")

# Verificar que Lynis esté instalado
echo -e "${CYAN}Verificando instalación de Lynis...${NC}"
ansible $SECURITY_GROUP -m shell -a "which lynis" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    if [[ "$result" == *"/lynis" ]]; then
        echo -e "  ${GREEN}✅ $host: Lynis instalado en $result${NC}"
    else
        echo -e "  ${RED}❌ $host: Lynis no encontrado${NC}"
    fi
done

# Verificar servicios systemd
for service in fail2ban nginx node-exporter security-exporter; do
    echo -e "${CYAN}Verificando $service...${NC}"
    ansible $SECURITY_GROUP -m shell -a "systemctl is-active $service 2>/dev/null || echo 'not-active'" --one-line 2>/dev/null | while read line; do
        host=$(echo $line | cut -d'|' -f1 | xargs)
        status=$(echo $line | awk '{print $NF}')
        if [ "$status" = "active" ]; then
            echo -e "  ${GREEN}✅ $host: $service está activo${NC}"
        elif [ "$service" = "security-exporter" ] && [ "$status" = "not-active" ]; then
            echo -e "  ${YELLOW}⚠️ $host: $service no está activo (puede ser normal si acabas de instalar)${NC}"
        else
            echo -e "  ${RED}❌ $host: $service no está activo${NC}"
        fi
    done
done

# 3. Verificar versión de Lynis
echo -e "\n${YELLOW}📋 3. Verificando versión de Lynis...${NC}"
ansible $SECURITY_GROUP -m shell -a "lynis --version 2>/dev/null | grep -E 'Lynis [0-9]' || echo 'Version not found'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    version=$(echo $line | cut -d'|' -f3-)
    if [[ "$version" == *"Lynis"* ]]; then
        echo -e "${GREEN}✅ $host: $version${NC}"
    else
        echo -e "${RED}❌ $host: Versión no encontrada${NC}"
    fi
done

# 4. Ejecutar auditoría rápida de Lynis
echo -e "\n${YELLOW}🏃 4. Ejecutando auditoría rápida de Lynis...${NC}"
ansible $SECURITY_GROUP -m shell -a "lynis audit system --quick --quiet --no-colors" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f2)
    if [ "$result" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $host: Auditoría rápida completada exitosamente${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: Auditoría completada con advertencias${NC}"
    fi
done

# 5. Obtener score de seguridad actual
echo -e "\n${YELLOW}📊 5. Obteniendo scores de seguridad...${NC}"
ansible $SECURITY_GROUP -m shell -a "lynis show report | grep 'Hardening index' | tail -1 || echo 'No report found'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    
    if [[ "$result" == *"Hardening index"* ]]; then
        # Extraer score
        score=$(echo $result | grep -oE '[0-9]+' | tail -1)
        if [ ! -z "$score" ]; then
            if [ "$score" -ge 80 ]; then
                echo -e "${GREEN}✅ $host: Score de seguridad: $score/100 (EXCELENTE)${NC}"
            elif [ "$score" -ge 70 ]; then
                echo -e "${YELLOW}⚠️ $host: Score de seguridad: $score/100 (BUENO)${NC}"
            elif [ "$score" -ge 50 ]; then
                echo -e "${YELLOW}⚠️ $host: Score de seguridad: $score/100 (REGULAR)${NC}"
            else
                echo -e "${RED}❌ $host: Score de seguridad: $score/100 (BAJO)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ $host: Score no encontrado en el reporte${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ $host: No se encontró reporte de auditoría${NC}"
    fi
done

# 6. Verificar reportes y logs
echo -e "\n${YELLOW}📁 6. Verificando reportes y logs...${NC}"
ansible $SECURITY_GROUP -m shell -a "ls -la /var/log/lynis/reports/ | wc -l" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    count=$(echo $line | awk '{print $NF}')
    if [ "$count" -gt 2 ]; then  # > 2 porque ls incluye . y ..
        echo -e "${GREEN}✅ $host: $((count-2)) reportes encontrados${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: Pocos o ningún reporte encontrado${NC}"
    fi
done

# 7. Verificar métricas de seguridad
echo -e "\n${YELLOW}📈 7. Verificando métricas de seguridad...${NC}"
ansible $SECURITY_GROUP -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ip=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    if [ ! -z "$ip" ]; then
        echo -e "${CYAN}Testing métricas de $host ($ip)...${NC}"
        
        # Test Security Exporter
        if timeout 10 curl -s "http://$ip:$SECURITY_EXPORTER_PORT/metrics" | head -5 >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Security Exporter (${SECURITY_EXPORTER_PORT}): Métricas disponibles${NC}"
            
            # Obtener score de las métricas
            score_metric=$(timeout 5 curl -s "http://$ip:$SECURITY_EXPORTER_PORT/metrics" | grep "lynis_security_score" | grep -v "#" | awk '{print $2}' || echo "0")
            if [ ! -z "$score_metric" ] && [ "$score_metric" != "0" ]; then
                echo -e "  ${CYAN}📊 Score desde métricas: $score_metric/100${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠️ Security Exporter (${SECURITY_EXPORTER_PORT}): No responde${NC}"
        fi
        
        # Test Node Exporter
        if timeout 5 curl -s "http://$ip:9100/metrics" | head -5 >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Node Exporter (9100): Métricas disponibles${NC}"
        else
            echo -e "  ${RED}❌ Node Exporter (9100): No responde${NC}"
        fi
        
        # Test Dashboard web
        if timeout 5 curl -s "http://$ip/lynis-dashboard/" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Dashboard web: Accesible${NC}"
        else
            echo -e "  ${YELLOW}⚠️ Dashboard web: No accesible${NC}"
        fi
    fi
done

# 8. Verificar configuración de fail2ban
echo -e "\n${YELLOW}🚫 8. Verificando fail2ban...${NC}"
ansible $SECURITY_GROUP -m shell -a "fail2ban-client status 2>/dev/null || echo 'fail2ban not running'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    
    if [[ "$result" == *"jail(s)"* ]]; then
        jails=$(echo $result | grep -oE '[0-9]+' | head -1)
        echo -e "${GREEN}✅ $host: fail2ban activo con $jails jail(s)${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: fail2ban no está corriendo o no tiene jails${NC}"
    fi
done

# 9. Verificar cron jobs de auditoría
echo -e "\n${YELLOW}⏰ 9. Verificando auditorías programadas...${NC}"
ansible $SECURITY_GROUP -m shell -a "crontab -l | grep lynis || echo 'No lynis cron jobs'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    
    if [[ "$result" == *"lynis"* ]]; then
        jobs_count=$(echo $result | grep -c "lynis" || echo "0")
        echo -e "${GREEN}✅ $host: $jobs_count auditoría(s) programada(s)${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: No se encontraron auditorías programadas${NC}"
    fi
done

# 10. Test de comandos útiles
echo -e "\n${YELLOW}🔧 10. Verificando comandos útiles disponibles...${NC}"
commands=("lynis" "fail2ban-client" "ufw" "ss" "netstat")
for cmd in "${commands[@]}"; do
    echo -e "${CYAN}Verificando $cmd...${NC}"
    ansible $SECURITY_GROUP -m shell -a "which $cmd 2>/dev/null || echo 'not found'" --one-line 2>/dev/null | while read line; do
        host=$(echo $line | cut -d'|' -f1 | xargs)
        result=$(echo $line | cut -d'|' -f3-)
        if [[ "$result" != "not found" ]]; then
            echo -e "  ${GREEN}✅ $host: $cmd disponible en $result${NC}"
        else
            echo -e "  ${YELLOW}⚠️ $host: $cmd no encontrado${NC}"
        fi
    done
done

# 11. Mostrar top warnings de Lynis
echo -e "\n${YELLOW}⚠️ 11. Top advertencias de seguridad...${NC}"
ansible $SECURITY_GROUP -m shell -a "lynis show report | grep -A 1 -E 'warning|Warning' | head -10 || echo 'No warnings found'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    
    if [[ "$result" != "No warnings found" ]] && [[ "$result" != *"SUCCESS"* ]]; then
        echo -e "${PURPLE}📋 $host: Últimas advertencias encontradas${NC}"
        # Note: Para mostrar advertencias específicas se necesitaría un enfoque más complejo
        echo -e "   ${CYAN}💡 Revisar: lynis show report${NC}"
    fi
done

# 12. Resumen final
echo -e "\n${BLUE}📋 RESUMEN DE SECURITY AUDIT:${NC}"
echo "================================"

ansible $SECURITY_GROUP -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ip=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    if [ ! -z "$ip" ]; then
        echo -e "${GREEN}🛡️ $host:${NC}"
        echo -e "   Dashboard: http://$ip/lynis-dashboard/"
        echo -e "   Métricas: http://$ip:$SECURITY_EXPORTER_PORT/metrics"
        echo -e "   Node Exporter: http://$ip:9100/metrics"
        echo ""
    fi
done

echo -e "${BLUE}🔗 COMANDOS ÚTILES PARA SECURITY AUDIT:${NC}"
echo "========================================="
echo "# Auditoría manual completa:"
echo "ansible security_servers -a 'lynis audit system'"
echo ""
echo "# Auditoría rápida:"
echo "ansible security_servers -a 'lynis audit system --quick'"
echo ""
echo "# Ver reporte:"
echo "ansible security_servers -a 'lynis show report'"
echo ""
echo "# Status de fail2ban:"
echo "ansible security_servers -a 'fail2ban-client status'"
echo ""
echo "# Verificar configuración de firewall:"
echo "ansible security_servers -a 'ufw status verbose'"
echo ""
echo "# Ejecutar hardening básico (¡CUIDADO EN PRODUCCIÓN!):"
echo "ansible security_servers -a '/var/lib/lynis/basic-hardening.sh'"

echo -e "\n${PURPLE}📚 RECURSOS ADICIONALES:${NC}"
echo "========================="
echo "• Lynis Documentation: https://cisofy.com/lynis/documentation/"
echo "• Security Hardening: https://linux-audit.com/"
echo "• fail2ban Documentation: https://github.com/fail2ban/fail2ban"

echo -e "\n${GREEN}🎉 Verificación de security audit completada!${NC}"
