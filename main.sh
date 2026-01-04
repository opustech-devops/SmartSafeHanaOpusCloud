#!/bin/bash

# Script principal refatorado para SmartSafeHanaOpusCloud
# Inclui todos os módulos necessários

# Incluir constantes
source "/usr/sap/SmartSafeHanaOpusCloud/constants.sh"

# Incluir funções
source "/usr/sap/SmartSafeHanaOpusCloud/functions.sh"

# Exibir banner
source "/usr/sap/SmartSafeHanaOpusCloud/banner.sh"

# Lógica de configuração principal
source "/usr/sap/SmartSafeHanaOpusCloud/config_logic.sh"

# Configuração de caminhos
source "/usr/sap/SmartSafeHanaOpusCloud/path_config.sh"

# Configuração de cópia
source "/usr/sap/SmartSafeHanaOpusCloud/copy_config.sh"

# Configuração de email
source "/usr/sap/SmartSafeHanaOpusCloud/email_config.sh"

# Geração do script agendado e agendamento
source "/usr/sap/SmartSafeHanaOpusCloud/scheduled_gen.sh"