# Migración de Jenkins a GitHub Actions

## 🚀 Resumen de Cambios

Este proyecto ha sido migrado de Jenkins a GitHub Actions para CI/CD, proporcionando:
- **Mayor integración** con GitHub
- **Menor overhead** de infraestructura
- **Mejor escalabilidad** y gestión de recursos
- **Configuración más simple** y mantenible

## 📁 Archivos Modificados/Creados

### 🆕 Nuevos Archivos
```
.github/workflows/
├── ci-cd.yml                    # Pipeline principal de CI/CD
└── deploy.yml                   # Deployments automáticos avanzados

roles/github-actions/            # Nuevo rol de Ansible
├── defaults/main.yml
├── tasks/main.yml
├── tasks/configure_runner.yml
├── handlers/main.yml
└── templates/
    ├── github-runner.service.j2
    ├── start-runner.sh.j2
    ├── stop-runner.sh.j2
    ├── cleanup-runners.sh.j2
    └── github-runner-logrotate.j2

scripts/
└── setup-github-actions.sh     # Script de configuración automática

docs/
└── GITHUB-ACTIONS-SETUP.md     # Documentación completa
```

### ✏️ Archivos Modificados
- `setup-cicd.yml` - Actualizado para usar `github-actions` role
- `inventory/group_vars/cicd_servers/main.yml` - Configuración para GitHub Actions

## 🔧 Características Principales

### Workflows
1. **CI/CD Pipeline** (`.github/workflows/ci-cd.yml`)
   - Tests multi-versión (Node.js 16, 18, 20)
   - Security scanning (Trivy + CodeQL)
   - Docker build y push al registry
   - Deploy automático a múltiples entornos
   - Notificaciones Slack y métricas Prometheus

2. **Automated Deployment** (`.github/workflows/deploy.yml`)
   - Estrategias: Rolling, Blue-Green, Canary
   - Deploy por ambiente específico
   - Rollback automático en fallos
   - Validación de prerequisitos

### Self-hosted Runners
- **Configuración automática** de múltiples runners por servidor
- **Aislamiento de seguridad** con systemd
- **Limpieza automática** de logs y artefactos
- **Integración Docker** para builds
- **Monitoreo** con Prometheus

## 🛠️ Configuración Rápida

### 1. Prerequisitos
```bash
# Instalar GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh

# Autenticar
gh auth login
```

### 2. Configuración Automática
```bash
# Ejecutar script de setup
./scripts/setup-github-actions.sh
```

### 3. Deploy de Infraestructura
```bash
# Con variables de entorno
export GITHUB_REPO_URL="https://github.com/tu-usuario/infra-made-easy"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

ansible-playbook -i inventory/hosts setup-cicd.yml \
  --extra-vars "github_repo_url=$GITHUB_REPO_URL" \
  --extra-vars "github_token=$GITHUB_TOKEN"
```

## 🔐 Secrets Requeridos

Configurar en GitHub Settings > Secrets and variables > Actions:

| Secret | Descripción |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Clave SSH para deployments |
| `DEPLOY_HOST` | Servidor principal de deployment |
| `SLACK_WEBHOOK_URL` | Webhook para notificaciones |
| `PROMETHEUS_PUSHGATEWAY_URL` | URL del Pushgateway |

## 📊 Monitoreo y Métricas

Los runners exportan métricas a Prometheus:
- Estado de workflows y jobs
- Duración de builds y deployments
- Tasa de éxito/fallo
- Uso de recursos del runner

## 🔄 Migración desde Jenkins

### Que se mantiene:
- ✅ Misma funcionalidad de CI/CD
- ✅ Deploy a múltiples entornos
- ✅ Integración con Docker
- ✅ Monitoreo con Prometheus
- ✅ Notificaciones Slack

### Que mejora:
- 🚀 **Rendimiento**: Runners más eficientes
- 🔧 **Mantenimiento**: Sin gestión de Jenkins
- 🔒 **Seguridad**: Integración nativa con GitHub
- 📈 **Escalabilidad**: Auto-scaling de runners
- 🎯 **Simplicidad**: Configuración como código

### Que cambia:
- ❌ **UI Jenkins**: Ahora en GitHub Actions tab
- ❌ **Plugins Jenkins**: Reemplazados por Actions del marketplace
- ❌ **Jenkinsfile**: Reemplazado por workflows YAML

## 🆘 Troubleshooting

### Runners no aparecen en GitHub
```bash
# Verificar servicios
sudo systemctl status github-runner-*

# Ver logs detallados
sudo journalctl -u github-runner-* -f

# Reiniciar runners
sudo systemctl restart github-runner-*
```

### Problemas con Docker
```bash
# Verificar permisos
groups github-runner

# Añadir al grupo docker si es necesario
sudo usermod -aG docker github-runner
sudo systemctl restart github-runner-*
```

### Limpiar runners offline
```bash
# Script automático
sudo /usr/local/bin/cleanup-github-runners.sh

# Manual con GitHub CLI
gh api repos/:owner/:repo/actions/runners
```

## 📚 Documentación Adicional

- [Setup completo](docs/GITHUB-ACTIONS-SETUP.md)
- [Configuración del rol](roles/github-actions/README.md)
- [Workflows de ejemplo](.github/workflows/)

---

**¡La migración está completa!** 🎉

Para cualquier duda o problema, revisar la documentación completa o crear un issue en el repositorio.
