#!/bin/bash
# 🌐 Script de Verificación - Webserver SSL
# Curso: Infra Made Easy - Equipo Webserver SSL

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración (ajustar según inventario)
WEBSERVER_GROUP="webserver_ssl_servers"
HTTP_PORT=80
HTTPS_PORT=443
NGINX_STATUS_PORT=9113

echo -e "${BLUE}🌐 Verificando Webservers SSL - Infra Made Easy${NC}"
echo "=================================================="

# 1. Verificar conectividad con servidores web
echo -e "\n${YELLOW}📡 1. Verificando conectividad con servidores web...${NC}"
if ansible $WEBSERVER_GROUP -m ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Servidores web accesibles${NC}"
    server_count=$(ansible $WEBSERVER_GROUP --list-hosts 2>/dev/null | grep -c "hosts" || echo "0")
    echo -e "${CYAN}📊 Servidores configurados: $server_count${NC}"
else
    echo -e "${RED}❌ No se puede conectar a los servidores web${NC}"
    exit 1
fi

# 2. Verificar servicios
echo -e "\n${YELLOW}🔧 2. Verificando servicios web...${NC}"
services=("nginx" "node-exporter")

for service in "${services[@]}"; do
    echo -e "${CYAN}Verificando $service...${NC}"
    ansible $WEBSERVER_GROUP -m shell -a "systemctl is-active $service" --one-line 2>/dev/null | while read line; do
        host=$(echo $line | cut -d'|' -f1 | xargs)
        status=$(echo $line | awk '{print $NF}')
        if [ "$status" = "active" ]; then
            echo -e "  ${GREEN}✅ $host: $service está activo${NC}"
        else
            echo -e "  ${RED}❌ $host: $service no está activo${NC}"
        fi
    done
done

# 3. Verificar puertos web
echo -e "\n${YELLOW}🌐 3. Verificando puertos web...${NC}"
ansible $WEBSERVER_GROUP -m shell -a "ss -tlpn | grep -E ':(80|443|9100|9113)'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ports=$(echo $line | cut -d'|' -f3- | grep -oE ':(80|443|9100|9113)' | tr -d ':' | sort -u | tr '\n' ' ')
    echo -e "${GREEN}✅ $host: Puertos activos [$ports]${NC}"
done

# 4. Verificar certificados SSL
echo -e "\n${YELLOW}🔐 4. Verificando certificados SSL...${NC}"
ansible $WEBSERVER_GROUP -m shell -a "ls -la /etc/letsencrypt/live/*/cert.pem 2>/dev/null || echo 'No SSL certs found'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    if [[ "$result" == *"cert.pem"* ]]; then
        domain=$(echo $result | grep -oE '/etc/letsencrypt/live/[^/]+' | cut -d'/' -f5)
        echo -e "${GREEN}✅ $host: Certificado SSL encontrado para $domain${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: No se encontraron certificados SSL${NC}"
    fi
done

# 5. Test de conectividad HTTP/HTTPS
echo -e "\n${YELLOW}🔍 5. Testing conectividad HTTP/HTTPS...${NC}"

# Obtener IPs y dominios de los servidores
ansible $WEBSERVER_GROUP -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ip=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    if [ ! -z "$ip" ]; then
        echo -e "${CYAN}Testing $host ($ip)...${NC}"
        
        # Test HTTP
        if timeout 10 curl -s -I "http://$ip" >/dev/null 2>&1; then
            http_status=$(curl -s -I "http://$ip" | head -1 | cut -d' ' -f2)
            echo -e "  ${GREEN}✅ HTTP ($HTTP_PORT): Status $http_status${NC}"
        else
            echo -e "  ${RED}❌ HTTP ($HTTP_PORT): No responde${NC}"
        fi
        
        # Test HTTPS (si está configurado)
        if timeout 10 curl -k -s -I "https://$ip" >/dev/null 2>&1; then
            https_status=$(curl -k -s -I "https://$ip" | head -1 | cut -d' ' -f2)
            echo -e "  ${GREEN}✅ HTTPS ($HTTPS_PORT): Status $https_status${NC}"
        else
            echo -e "  ${YELLOW}⚠️ HTTPS ($HTTPS_PORT): No configurado o no responde${NC}"
        fi
        
        # Test Node Exporter
        if timeout 5 curl -s "http://$ip:9100/metrics" | head -5 >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Node Exporter (9100): Métricas disponibles${NC}"
        else
            echo -e "  ${RED}❌ Node Exporter (9100): No responde${NC}"
        fi
    fi
done

# 6. Verificar configuración de nginx
echo -e "\n${YELLOW}⚙️ 6. Verificando configuración de nginx...${NC}"
ansible $WEBSERVER_GROUP -m shell -a "nginx -t" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    if [[ "$result" == *"syntax is ok"* ]] && [[ "$result" == *"test is successful"* ]]; then
        echo -e "${GREEN}✅ $host: Configuración de nginx válida${NC}"
    else
        echo -e "${RED}❌ $host: Error en configuración de nginx${NC}"
    fi
done

# 7. Verificar headers de seguridad
echo -e "\n${YELLOW}🛡️ 7. Verificando headers de seguridad...${NC}"
ansible $WEBSERVER_GROUP -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ip=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    if [ ! -z "$ip" ]; then
        echo -e "${CYAN}Verificando headers de $host ($ip)...${NC}"
        
        # Verificar headers básicos
        headers=$(timeout 10 curl -s -I "http://$ip" 2>/dev/null || echo "No response")
        
        if [[ "$headers" == *"X-Frame-Options"* ]]; then
            echo -e "  ${GREEN}✅ X-Frame-Options configurado${NC}"
        else
            echo -e "  ${YELLOW}⚠️ X-Frame-Options no encontrado${NC}"
        fi
        
        if [[ "$headers" == *"X-Content-Type-Options"* ]]; then
            echo -e "  ${GREEN}✅ X-Content-Type-Options configurado${NC}"
        else
            echo -e "  ${YELLOW}⚠️ X-Content-Type-Options no encontrado${NC}"
        fi
        
        if [[ "$headers" == *"X-XSS-Protection"* ]]; then
            echo -e "  ${GREEN}✅ X-XSS-Protection configurado${NC}"
        else
            echo -e "  ${YELLOW}⚠️ X-XSS-Protection no encontrado${NC}"
        fi
    fi
done

# 8. Test de SSL Labs (si hay HTTPS)
echo -e "\n${YELLOW}🔒 8. Test básico de SSL...${NC}"
echo -e "${CYAN}Para test completo de SSL, usar: https://www.ssllabs.com/ssltest/${NC}"

# 9. Verificar renovación automática de certificados
echo -e "\n${YELLOW}⏰ 9. Verificando renovación automática de SSL...${NC}"
ansible $WEBSERVER_GROUP -m shell -a "crontab -l | grep certbot || echo 'No cron for certbot'" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    result=$(echo $line | cut -d'|' -f3-)
    if [[ "$result" == *"certbot"* ]]; then
        echo -e "${GREEN}✅ $host: Renovación automática configurada${NC}"
    else
        echo -e "${YELLOW}⚠️ $host: Renovación automática no encontrada${NC}"
    fi
done

# 10. Resumen final
echo -e "\n${BLUE}📋 RESUMEN DE WEBSERVERS SSL:${NC}"
echo "=================================="

ansible $WEBSERVER_GROUP -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | while read line; do
    host=$(echo $line | cut -d'|' -f1 | xargs)
    ip=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    
    if [ ! -z "$ip" ]; then
        echo -e "${GREEN}🖥️ $host:${NC}"
        echo -e "   HTTP:  http://$ip"
        echo -e "   HTTPS: https://$ip (si está configurado)"
        echo -e "   Métricas: http://$ip:9100/metrics"
        echo ""
    fi
done

echo -e "${BLUE}🔗 TESTS RECOMENDADOS:${NC}"
echo "1. SSL Labs Test: https://www.ssllabs.com/ssltest/"
echo "2. Security Headers: https://securityheaders.com/"
echo "3. Verificar renovación: certbot certificates"
echo "4. Load testing: curl -w \"@curl-format.txt\" -o /dev/null"

echo -e "\n${GREEN}🎉 Verificación de webserver SSL completada!${NC}"
