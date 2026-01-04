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
source "./constants.sh"
log "Constantes carregadas"

# Incluir funções
source "./functions.sh"
log "Funções carregadas"

# Exibir banner
source "./banner.sh"
log "Banner exibido"

# Lógica de configuração principal
source "./config_logic.sh"
log "Lógica de configuração executada"

# Configuração de caminhos
source "./path_config.sh"
log "Configuração de caminhos executada"

# Configuração de cópia
source "./copy_config.sh"
log "Configuração de cópia executada"

# Configuração de email
source "./email_config.sh"
log "Configuração de email executada"

# Geração do script agendado e agendamento
source "./scheduled_gen.sh"
log "Script agendado gerado"

log "SmartSafeHanaOpusCloud v2.2 concluído"