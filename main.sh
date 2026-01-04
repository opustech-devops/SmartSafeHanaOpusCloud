#!/bin/bash

# Script principal refatorado para SmartSafeHanaOpusCloud
# Inclui todos os módulos necessários

# Logging setup
mkdir -p /usr/sap/SmartSafeHanaOpusCloud
if [ -f "/usr/sap/SmartSafeHanaOpusCloud/last_execution.log" ]; then
    mv "/usr/sap/SmartSafeHanaOpusCloud/last_execution.log" "/usr/sap/SmartSafeHanaOpusCloud/last_execution_$(date +%Y%m%d_%H%M%S).log"
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> /usr/sap/SmartSafeHanaOpusCloud/last_execution.log
}

# Define base directory for absolute paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Iniciando SmartSafeHanaOpusCloud v2.2"

# Verificar e instalar dialog se necessário
if ! command -v dialog &> /dev/null; then
    log "Dialog não encontrado, instalando..."
    echo "Instalando dialog para interface gráfica..."
    zypper install -y dialog
    log "Dialog instalado com sucesso"
else
    log "Dialog já instalado"
fi

# Incluir constantes
source "$BASE_DIR/constants.sh"
log "Constantes carregadas"

# Incluir funções
source "$BASE_DIR/functions.sh"
log "Funções carregadas"

# Exibir banner
source "$BASE_DIR/banner.sh"
log "Banner exibido"

# Lógica de configuração principal
source "$BASE_DIR/config_logic.sh"
log "Lógica de configuração executada"

# Configuração de caminhos
source "$BASE_DIR/path_config.sh"
log "Configuração de caminhos executada"

# Configuração de cópia
source "$BASE_DIR/copy_config.sh"
log "Configuração de cópia executada"

# Configuração de email
source "$BASE_DIR/email_config.sh"
log "Configuração de email executada"

# Geração do script agendado e agendamento
source "$BASE_DIR/scheduled_gen.sh"
log "Script agendado gerado"

log "SmartSafeHanaOpusCloud v2.2 concluído"