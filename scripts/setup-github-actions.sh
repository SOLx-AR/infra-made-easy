#!/bin/bash
# Script para configurar GitHub Actions para infra-made-easy
# Este script ayuda a configurar los tokens y secrets necesarios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    local deps=("curl" "jq" "gh")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Dependencias faltantes: ${missing_deps[*]}"
        echo "Instalar con:"
        echo "  - curl: sudo apt install curl"
        echo "  - jq: sudo apt install jq"
        echo "  - gh: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        exit 1
    fi
    
    success "Todas las dependencias están instaladas"
}

# Verificar autenticación con GitHub
check_github_auth() {
    log "Verificando autenticación con GitHub..."
    
    if ! gh auth status &> /dev/null; then
        error "No estás autenticado con GitHub CLI"
        echo "Ejecuta: gh auth login"
        exit 1
    fi
    
    success "Autenticación con GitHub verificada"
}

# Obtener información del repositorio
get_repo_info() {
    log "Obteniendo información del repositorio..."
    
    # Intentar obtener desde git remote
    if git remote get-url origin &> /dev/null; then
        REPO_URL=$(git remote get-url origin)
        if [[ $REPO_URL == git@github.com:* ]]; then
            REPO_URL=$(echo "$REPO_URL" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$||')
        elif [[ $REPO_URL == https://github.com/* ]]; then
            REPO_URL=$(echo "$REPO_URL" | sed 's|\.git$||')
        fi
    else
        read -p "Ingresa la URL del repositorio (ej: https://github.com/usuario/repo): " REPO_URL
    fi
    
    # Extraer owner y repo name
    REPO_OWNER=$(echo "$REPO_URL" | sed 's|https://github.com/||' | cut -d'/' -f1)
    REPO_NAME=$(echo "$REPO_URL" | sed 's|https://github.com/||' | cut -d'/' -f2)
    
    log "Repositorio: $REPO_OWNER/$REPO_NAME"
    log "URL: $REPO_URL"
}

# Generar token de GitHub
setup_github_token() {
    log "Configurando token de GitHub..."
    
    # Verificar si ya existe un token
    if gh auth token &> /dev/null; then
        GITHUB_TOKEN=$(gh auth token)
        success "Token de GitHub obtenido desde CLI"
    else
        error "No se pudo obtener token de GitHub CLI"
        echo "Asegúrate de estar autenticado con: gh auth login"
        exit 1
    fi
}

# Configurar secrets del repositorio
setup_repo_secrets() {
    log "Configurando secrets del repositorio..."
    
    # Lista de secrets necesarios
    local secrets=(
        "SSH_PRIVATE_KEY:Clave SSH privada para deployments"
        "DEPLOY_HOST:Host de deployment principal"
        "SLACK_WEBHOOK_URL:URL del webhook de Slack para notificaciones"
        "PROMETHEUS_PUSHGATEWAY_URL:URL del Prometheus Pushgateway"
    )
    
    for secret_info in "${secrets[@]}"; do
        SECRET_NAME=$(echo "$secret_info" | cut -d':' -f1)
        SECRET_DESC=$(echo "$secret_info" | cut -d':' -f2)
        
        warning "Configurar secret: $SECRET_NAME"
        echo "  Descripción: $SECRET_DESC"
        
        read -p "¿Quieres configurar $SECRET_NAME ahora? (y/N): " configure
        if [[ $configure =~ ^[Yy]$ ]]; then
            if [[ $SECRET_NAME == "SSH_PRIVATE_KEY" ]]; then
                read -p "Ruta a la clave SSH privada: " ssh_key_path
                if [[ -f "$ssh_key_path" ]]; then
                    gh secret set "$SECRET_NAME" --body "$(cat "$ssh_key_path")" --repo "$REPO_OWNER/$REPO_NAME"
                    success "Secret $SECRET_NAME configurado"
                else
                    error "Archivo no encontrado: $ssh_key_path"
                fi
            else
                read -s -p "Valor para $SECRET_NAME: " secret_value
                echo
                gh secret set "$SECRET_NAME" --body "$secret_value" --repo "$REPO_OWNER/$REPO_NAME"
                success "Secret $SECRET_NAME configurado"
            fi
        fi
    done
}

# Crear archivo de variables para Ansible
create_ansible_vars() {
    log "Creando archivo de variables para Ansible..."
    
    local vars_file="inventory/group_vars/cicd_servers/github_secrets.yml"
    
    cat > "$vars_file" << EOF
# Variables de GitHub Actions - NO COMMITEAR ESTE ARCHIVO
# Añadir a .gitignore si contiene información sensible
---

# URL del repositorio
github_repo_url: "$REPO_URL"

# Token de GitHub (usar ansible-vault para encriptar en producción)
# github_token: "CONFIGURAR_CON_ANSIBLE_VAULT"

# Variables de deployment
deployment_vars:
  ssh_user: "deploy"
  ssh_port: 22
  backup_retention_days: 30
  
# Configuración de notificaciones
notifications:
  slack_enabled: true
  email_enabled: false
  
# Configuración de monitoreo
monitoring:
  prometheus_enabled: true
  grafana_dashboard_enabled: true
  metrics_retention_days: 15
EOF

    success "Archivo de variables creado: $vars_file"
    warning "IMPORTANTE: Configurar github_token usando ansible-vault en producción"
}

# Crear documentación
create_documentation() {
    log "Creando documentación..."
    
    cat > "docs/GITHUB-ACTIONS-SETUP.md" << 'EOF'
# Configuración de GitHub Actions para Infra Made Easy

## Descripción
Esta guía describe la configuración de GitHub Actions como reemplazo de Jenkins para CI/CD.

## Prerequisitos

1. **GitHub CLI instalado y autenticado**
   ```bash
   # Instalar GitHub CLI
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   
   # Autenticar
   gh auth login
   ```

2. **Variables configuradas**
   - `github_repo_url`: URL del repositorio
   - `github_token`: Token de acceso personal de GitHub

## Secrets Necesarios

Configurar los siguientes secrets en GitHub:

| Secret | Descripción | Comando |
|--------|-------------|---------|
| `SSH_PRIVATE_KEY` | Clave SSH para deployments | `gh secret set SSH_PRIVATE_KEY --body "$(cat ~/.ssh/id_rsa)"` |
| `DEPLOY_HOST` | Host principal de deployment | `gh secret set DEPLOY_HOST --body "mi-servidor.com"` |
| `SLACK_WEBHOOK_URL` | Webhook de Slack | `gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/..."` |
| `PROMETHEUS_PUSHGATEWAY_URL` | URL del Pushgateway | `gh secret set PROMETHEUS_PUSHGATEWAY_URL --body "http://monitoring:9091"` |

## Ejecutar Setup

1. **Configuración automática**
   ```bash
   ./scripts/setup-github-actions.sh
   ```

2. **Configuración manual con Ansible**
   ```bash
   # Configurar variables
   export GITHUB_REPO_URL="https://github.com/tu-usuario/infra-made-easy"
   export GITHUB_TOKEN="ghp_..."
   
   # Ejecutar playbook
   ansible-playbook -i inventory/hosts setup-cicd.yml \
     --extra-vars "github_repo_url=$GITHUB_REPO_URL" \
     --extra-vars "github_token=$GITHUB_TOKEN"
   ```

## Workflows Disponibles

### 1. CI/CD Pipeline (`ci-cd.yml`)
- **Trigger**: Push a main/develop, PRs, manual
- **Jobs**: Test, Security Scan, Build, Deploy, Notify
- **Características**:
  - Tests multi-versión (Node.js 16, 18, 20)
  - Análisis de seguridad con Trivy y CodeQL
  - Build y push de imágenes Docker
  - Deploy automático a múltiples entornos

### 2. Automated Deployment (`deploy.yml`)
- **Trigger**: Workflow completion, manual
- **Estrategias**: Rolling, Blue-Green, Canary
- **Características**:
  - Validación de prerequisitos
  - Deploy por entorno específico
  - Rollback automático en fallos
  - Métricas de deployment

## Monitoreo

Los runners reportan métricas a Prometheus:
- Estado de workflows
- Duración de jobs
- Tasa de éxito/fallo
- Uso de recursos

## Troubleshooting

### Runner no se conecta
```bash
# Verificar estado del servicio
sudo systemctl status github-runner-*

# Ver logs
sudo journalctl -u github-runner-* -f

# Reiniciar runner
sudo systemctl restart github-runner-*
```

### Problemas de permisos Docker
```bash
# Añadir usuario al grupo docker
sudo usermod -aG docker github-runner

# Reiniciar servicio
sudo systemctl restart github-runner-*
```

### Limpiar runners offline
```bash
# Ejecutar script de limpieza
sudo /usr/local/bin/cleanup-github-runners.sh

# Verificar runners en GitHub
gh api repos/:owner/:repo/actions/runners
```
EOF

    success "Documentación creada: docs/GITHUB-ACTIONS-SETUP.md"
}

# Función principal
main() {
    log "=== Configuración de GitHub Actions para Infra Made Easy ==="
    
    check_dependencies
    check_github_auth
    get_repo_info
    setup_github_token
    setup_repo_secrets
    create_ansible_vars
    create_documentation
    
    success "=== Configuración completada ==="
    echo
    warning "Próximos pasos:"
    echo "1. Revisar y encriptar secrets en inventory/group_vars/cicd_servers/github_secrets.yml"
    echo "2. Ejecutar: ansible-playbook -i inventory/hosts setup-cicd.yml"
    echo "3. Verificar runners en: https://github.com/$REPO_OWNER/$REPO_NAME/settings/actions/runners"
    echo "4. Revisar documentación en: docs/GITHUB-ACTIONS-SETUP.md"
}

# Verificar si se ejecuta como script principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
