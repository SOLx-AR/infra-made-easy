#!/bin/bash
# Script de verificación del entorno "Infra Made Easy"

set -e  # Salir si hay errores

echo "Verificando configuración de Ansible..."
echo ""

# Activar entorno virtual
source venv-ansible/bin/activate

echo "Entorno virtual activado"

# Verificar Ansible
echo "Version de Ansible:"
ansible --version | head -n1

# Verificar configuración
echo ""
echo "Archivo de configuración activo:"
ansible-config dump | grep "CONFIG_FILE" || echo "No se encontró archivo de configuración"

# Verificar inventario
echo ""
echo "Verificando inventario..."
host_count=$(ansible-inventory --list | jq '.all.children | length' 2>/dev/null || echo "0")
if [ "$host_count" -gt 0 ]; then
    echo "Inventario cargado correctamente ($host_count grupos principales)"
else
    echo "Error al cargar inventario"
    exit 1
fi

# Verificar roles
echo ""
echo "Verificando roles disponibles..."
role_count=$(ls -d roles/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$role_count" -gt 0 ]; then
    echo "$role_count roles encontrados:"
    ls -1 roles/ | sed 's/^/  - /'
else
    echo "No se encontraron roles"
    exit 1
fi

# Verificar playbooks
echo ""
echo "Verificando playbooks..."
playbook_files=$(ls -1 *.yml 2>/dev/null | grep -E "(etapa|setup)" | wc -l | tr -d ' ')
if [ "$playbook_files" -gt 0 ]; then
    echo "$playbook_files playbooks encontrados:"
    ls -1 *.yml | grep -E "(etapa|setup)" | sed 's/^/  - /'
else
    echo "No se encontraron playbooks principales"
    exit 1
fi

# Verificar sintaxis de un playbook básico
echo ""
echo "Verificando sintaxis del playbook etapa1..."
if ansible-playbook --syntax-check etapa1-webserver-basico.yml > /dev/null 2>&1; then
    echo "Sintaxis correcta en etapa1-webserver-basico.yml"
else
    echo "Error de sintaxis en etapa1-webserver-basico.yml"
    exit 1
fi

# Verificar colecciones de Ansible
echo ""
echo "Verificando colecciones de Ansible..."
if ansible-galaxy collection list 2>/dev/null | grep -q "community"; then
    collections=$(ansible-galaxy collection list 2>/dev/null | grep -E "community\.|ansible\." | wc -l | tr -d ' ')
    echo "$collections colecciones instaladas correctamente"
else
    echo "Algunas colecciones pueden no estar disponibles, pero Ansible funciona"
fi

# Verificar group_vars
echo ""
echo "Verificando variables de grupo..."
group_vars_count=$(ls inventory/group_vars/*/main.yml 2>/dev/null | wc -l | tr -d ' ')
if [ "$group_vars_count" -gt 0 ]; then
    echo "$group_vars_count archivos de variables de grupo encontrados"
else
    echo "No se encontraron archivos de variables de grupo"
fi

echo ""
echo "VERIFICACION COMPLETADA!"
echo ""
echo "Tu entorno está listo para:"
echo "  - Ejecutar playbooks de Ansible"
echo "  - Gestionar infraestructura colaborativa"
echo "  - Trabajar con los 5 equipos del curso"
echo ""
echo "Para empezar:"
echo "  ./activate-env.sh"
echo "  ansible-playbook etapa1-webserver-basico.yml"
echo ""
