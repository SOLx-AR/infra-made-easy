#!/bin/bash
# 📊 Script de Verificación - Stack de Monitoring
# Curso: Infra Made Easy

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
MONITORING_SERVER="server-f0x17"
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
NODE_EXPORTER_PORT=9100

echo -e "${BLUE}🚀 Verificando Stack de Monitoring - Infra Made Easy${NC}"
echo "=================================================="

# 1. Verificar conectividad con servidor de monitoring
echo -e "\n${YELLOW}📡 1. Verificando conectividad...${NC}"
if ansible $MONITORING_SERVER -m ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Servidor de monitoring accesible${NC}"
else
    echo -e "${RED}❌ No se puede conectar al servidor de monitoring${NC}"
    exit 1
fi

# 2. Verificar servicios systemd
echo -e "\n${YELLOW}🔧 2. Verificando servicios...${NC}"
services=("prometheus" "grafana-server" "node-exporter")

for service in "${services[@]}"; do
    status=$(ansible $MONITORING_SERVER -m shell -a "systemctl is-active $service" --one-line 2>/dev/null | awk '{print $NF}')
    if [ "$status" = "active" ]; then
        echo -e "${GREEN}✅ $service está activo${NC}"
    else
        echo -e "${RED}❌ $service no está activo (status: $status)${NC}"
    fi
done

# 3. Verificar puertos
echo -e "\n${YELLOW}🌐 3. Verificando puertos...${NC}"
server_ip=$(ansible $MONITORING_SERVER -m setup -a "filter=ansible_default_ipv4" --one-line 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)

ports=($PROMETHEUS_PORT $GRAFANA_PORT $NODE_EXPORTER_PORT)
port_names=("Prometheus" "Grafana" "Node Exporter")

for i in "${!ports[@]}"; do
    port=${ports[$i]}
    name=${port_names[$i]}
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$server_ip/$port" 2>/dev/null; then
        echo -e "${GREEN}✅ $name (puerto $port) accesible${NC}"
    else
        echo -e "${RED}❌ $name (puerto $port) no accesible${NC}"
    fi
done

# 4. Verificar métricas de Prometheus
echo -e "\n${YELLOW}🔍 4. Verificando métricas de Prometheus...${NC}"
if curl -s "http://$server_ip:$PROMETHEUS_PORT/api/v1/query?query=up" | grep -q '"status":"success"'; then
    echo -e "${GREEN}✅ Prometheus API responde correctamente${NC}"
    
    # Contar targets UP
    targets_up=$(curl -s "http://$server_ip:$PROMETHEUS_PORT/api/v1/query?query=up" | grep -o '"value":\["[^"]*","1"\]' | wc -l)
    echo -e "${GREEN}📊 Targets UP: $targets_up${NC}"
else
    echo -e "${RED}❌ Prometheus API no responde${NC}"
fi

# 5. Verificar Grafana
echo -e "\n${YELLOW}📈 5. Verificando Grafana...${NC}"
if curl -s "http://$server_ip:$GRAFANA_PORT/api/health" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✅ Grafana API responde correctamente${NC}"
else
    echo -e "${RED}❌ Grafana API no responde${NC}"
fi

# 6. Verificar dashboards
echo -e "\n${YELLOW}📊 6. Verificando dashboards...${NC}"
dashboard_count=$(ansible $MONITORING_SERVER -m shell -a "ls -1 /var/lib/grafana/dashboards/*.json 2>/dev/null | wc -l" --one-line 2>/dev/null | awk '{print $NF}')
if [ "$dashboard_count" -gt 0 ]; then
    echo -e "${GREEN}✅ $dashboard_count dashboards encontrados${NC}"
else
    echo -e "${YELLOW}⚠️ No se encontraron dashboards${NC}"
fi

# 7. Verificar configuración de datasources
echo -e "\n${YELLOW}🔌 7. Verificando datasources...${NC}"
if ansible $MONITORING_SERVER -m shell -a "test -f /var/lib/grafana/provisioning/datasources/datasources.yml" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Configuración de datasources encontrada${NC}"
else
    echo -e "${RED}❌ Configuración de datasources no encontrada${NC}"
fi

# 8. Resumen final
echo -e "\n${BLUE}📋 RESUMEN DE ACCESOS:${NC}"
echo "================================"
echo -e "📊 Prometheus: ${GREEN}http://$server_ip:$PROMETHEUS_PORT${NC}"
echo -e "📈 Grafana:    ${GREEN}http://$server_ip:$GRAFANA_PORT${NC} (admin/admin123)"
echo -e "🖥️ Node Exp.:  ${GREEN}http://$server_ip:$NODE_EXPORTER_PORT/metrics${NC}"

echo -e "\n${BLUE}🔗 PRÓXIMOS PASOS:${NC}"
echo "1. Cambiar contraseña de Grafana"
echo "2. Verificar dashboards en Grafana UI"
echo "3. Configurar otros servidores con node-exporter"
echo "4. Revisar targets en Prometheus: /targets"

echo -e "\n${GREEN}🎉 Verificación completada!${NC}"
