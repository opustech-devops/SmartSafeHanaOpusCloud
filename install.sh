#!/bin/bash
# Instalador SmartSafeHanaOpusCloud
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/opustech-devops/SmartSafeHanaOpusCloud/main/install.sh)

set -e
REPO_URL="https://github.com/opustech-devops/SmartSafeHanaOpusCloud.git"
INSTALL_DIR="/opt/smartsafehana"
BIN_LINK="/usr/local/bin/smartsafehana"

# 1. Clona ou atualiza o repositório
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Atualizando SmartSafeHanaOpusCloud em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull
else
    echo "Clonando SmartSafeHanaOpusCloud em $INSTALL_DIR..."
    sudo git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 2. Permissões de execução
sudo chmod +x "$INSTALL_DIR"/*.sh

# 3. Cria link simbólico para facilitar execução
if [ -L "$BIN_LINK" ]; then
    sudo rm "$BIN_LINK"
fi
sudo ln -s "$INSTALL_DIR/main.sh" "$BIN_LINK"

# 4. Instala dependências mínimas (ajuste conforme necessário)
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y mailutils git
fi

# 5. Mensagem final
cat <<EOF

${GREEN}Instalação concluída!${NC}
Execute o comando abaixo para iniciar o assistente:

  smartsafehana

Ou rode manualmente:

  bash $INSTALL_DIR/main.sh

EOF
