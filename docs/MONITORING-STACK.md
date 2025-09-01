# 📊 Stack de Monitoring - Infra Made Easy

## 🎯 Arquitectura del Stack de Monitoring

```
┌─────────────────────────────────────────────────────────────┐
│                 🖥️ SERVIDOR DE MONITORING                    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Prometheus  │◄───┤    HTTP     │◄───┤  Grafana    │     │
│  │   :9090     │    │   Scraping  │    │   :3000     │     │
│  │             │    │             │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         ▲                                       ▲           │
│         │                                       │           │
│         │           ┌─────────────┐             │           │
│         └───────────┤Node Exporter├─────────────┘           │
│                     │    :9100    │                         │
│                     └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                               ▲
                               │
                        📡 Scraping remoto
                               │
┌─────────────────┬─────────────────┬─────────────────┐
│ 🌐 Web Servers  │ 🔧 CI/CD       │ 🔒 Security     │
│ :9113 (nginx)   │ :9115 (jenkins)│ :9114 (lynis)   │
│ :9100 (node)    │ :9100 (node)   │ :9100 (node)    │
└─────────────────┴─────────────────┴─────────────────┘
```

## 🚀 Despliegue Rápido

### 1. Verificar configuración
```bash
# Verificar inventario
cat inventory/hosts | grep monitoring_servers

# Verificar conectividad
ansible monitoring_servers -m ping
```

### 2. Ejecutar playbook
```bash
# Instalar stack completo
ansible-playbook setup-monitoring.yml

# Solo actualizar configuración
ansible-playbook setup-monitoring.yml --tags=config
```

### 3. Verificar instalación
```bash
# Verificar servicios
ansible monitoring_servers -m shell -a "systemctl status prometheus grafana-server node-exporter"

# Verificar puertos
ansible monitoring_servers -m shell -a "ss -tlpn | grep -E ':(3000|9090|9100)'"
```

## 🔧 Configuración Post-Instalación

### Acceso a Servicios

| Servicio | Puerto | URL de Ejemplo | Credenciales |
|----------|--------|----------------|--------------|
| 📊 **Prometheus** | 9090 | `http://34.122.207.0:9090` | N/A |
| 📈 **Grafana** | 3000 | `http://34.122.207.0:3000` | admin/admin123 |
| 🖥️ **Node Exporter** | 9100 | `http://34.122.207.0:9100/metrics` | N/A |

### 🔐 Cambiar Contraseña de Grafana
```bash
# Conectar al servidor
ssh fox@34.122.207.0

# Cambiar contraseña vía CLI
sudo grafana-cli admin reset-admin-password "nueva_password_segura"

# O cambiar desde la web UI después del primer login
```

### 📊 Dashboards Incluidos

1. **🚀 Infra Made Easy - Dashboard Principal**
   - Resumen general de la infraestructura
   - CPU, Memory, Disk, Network por servidor
   - Estado de servicios

2. **📈 Node Exporter Full** (Descargado automáticamente)
   - Dashboard completo de métricas del sistema
   - Grafana Community Dashboard ID: 1860

3. **🔍 Prometheus 2.0 Overview** (Descargado automáticamente)
   - Métricas internas de Prometheus
   - Grafana Community Dashboard ID: 3662

## 📡 Targets de Monitoreo

El stack está configurado para monitorear automáticamente:

### 🎯 Targets Automáticos
- **Prometheus**: Se monitorea a sí mismo
- **Node Exporters**: Todos los servidores del inventario
- **Nginx**: Servidores web (puerto 9113)
- **Jenkins**: Servidores CI/CD (puerto 9115)
- **Security**: Servidores de seguridad (puerto 9114)
- **Traefik**: Load balancers (puerto 8080)

### ➕ Agregar Nuevos Targets

Para agregar un nuevo servidor al monitoreo:

1. **Instalar node-exporter en el servidor target**:
```bash
ansible nuevo_servidor -m include_role -a name=node-exporter
```

2. **Agregar al inventario** en el grupo correspondiente:
```ini
[webserver_ssl_servers]
nuevo-web ansible_host=1.2.3.4 server_name=nuevo-web-1
```

3. **Recargar configuración de Prometheus**:
```bash
# Regenerar configuración
ansible-playbook setup-monitoring.yml --tags=prometheus

# O recargar manualmente
curl -X POST http://34.122.207.0:9090/-/reload
```

## 🔄 Operaciones Comunes

### 🔍 Verificar Targets en Prometheus
1. Ir a: `http://34.122.207.0:9090/targets`
2. Verificar que todos los endpoints estén "UP"

### 📊 Importar Dashboards Adicionales
1. Ir a Grafana: `http://34.122.207.0:3000`
2. Login: admin/admin123
3. "+" → Import Dashboard
4. Usar ID de Grafana.com o subir JSON

### 🚨 Configurar Alertas (Futuro)
```yaml
# En setup-monitoring.yml, cambiar:
vars:
  enable_alerting: true
```

## 🛠️ Troubleshooting

### Servicios no arrancan
```bash
# Verificar logs
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
sudo journalctl -u node-exporter -f

# Verificar configuración
sudo /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
```

### Grafana no se conecta a Prometheus
```bash
# Verificar conectividad desde Grafana
curl -i http://localhost:9090/api/v1/query?query=up

# Verificar datasource en Grafana UI
# Settings → Data Sources → Prometheus → Test
```

### Targets no aparecen
```bash
# Verificar firewall
sudo ufw status

# Verificar que node-exporter esté corriendo en targets
ansible all -m shell -a "systemctl status node-exporter"
```

## 📝 Notas de Seguridad

⚠️ **IMPORTANTE EN PRODUCCIÓN:**

1. **Cambiar contraseñas por defecto**
2. **Configurar HTTPS con certificados SSL**
3. **Restringir acceso por IP/firewall**
4. **Configurar autenticación LDAP/OAuth**
5. **Habilitar auditoría de logs**

## 🔗 Enlaces Útiles

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [Grafana Community Dashboards](https://grafana.com/grafana/dashboards/)

---
**Stack configurado para**: Curso "Infra Made Easy" - Equipo Monitoring  
**Versión**: {{ monitoring_stack_version }}  
**Última actualización**: {{ ansible_date_time.date }}
