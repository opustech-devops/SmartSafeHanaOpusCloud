#!/bin/bash

# Script principal refatorado para SmartSafeHanaOpusCloud
# Inclui todos os módulos necessários

# Verificar e instalar dialog se necessário
if ! command -v dialog &> /dev/null; then
    echo "Instalando dialog para interface gráfica..."
    zypper install -y dialog
fi

# Incluir constantes
source "./constants.sh"

# Incluir funções
source "/usr/sap/SmartSafeHanaOpusCloud/functions.sh"

# Exibir banner
source "/usr/sap/SmartSafeHanaOpusCloud/banner.sh"

# Lógica de configuração principal
source "./config_logic.sh"

# Configuração de caminhos
source "./path_config.sh"

# Configuração de cópia
source "./copy_config.sh"

# Configuração de email
source "./email_config.sh"

# Geração do script agendado e agendamento
source "./scheduled_gen.sh"