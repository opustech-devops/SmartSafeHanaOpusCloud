#!/bin/bash

# Script principal refatorado para SmartSafeOpusCloud
# Inclui todos os módulos necessários

# Incluir constantes
source "$(dirname "$0")/constants.sh"

# Incluir funções
source "$(dirname "$0")/functions.sh"

# Exibir banner
source "$(dirname "$0")/banner.sh"

# Lógica de configuração principal
source "$(dirname "$0")/config_logic.sh"

# Configuração de caminhos
source "$(dirname "$0")/path_config.sh"

# Configuração de cópia
source "$(dirname "$0")/copy_config.sh"

# Configuração de email
source "$(dirname "$0")/email_config.sh"

# Geração do script agendado e agendamento
source "$(dirname "$0")/scheduled_gen.sh"