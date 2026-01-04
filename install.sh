#!/bin/bash
# Instalador SmartSafeHanaOpusCloud
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/opustech-devops/SmartSafeHanaOpusCloud/main/install.sh)

set -e
REPO_URL="https://github.com/opustech-devops/SmartSafeHanaOpusCloud.git"
INSTALL_DIR="/opt/smartsafehana"
BIN_LINK="/usr/local/bin/smartsafehana"


# 1. Baixa ou atualiza o repositório
ZIP_URL="https://github.com/opustech-devops/SmartSafeHanaOpusCloud/archive/refs/heads/main.zip"
TMP_DIR="/tmp/smartsafehana_zip"

if command -v git >/dev/null 2>&1; then
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Atualizando SmartSafeHanaOpusCloud em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull
  else
    echo "Clonando SmartSafeHanaOpusCloud em $INSTALL_DIR..."
    sudo git clone "$REPO_URL" "$INSTALL_DIR"
  fi
else
  echo "Git não encontrado. Baixando o projeto como .zip..."
  sudo rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  if command -v curl >/dev/null 2>&1; then
    curl -L "$ZIP_URL" -o "$TMP_DIR/main.zip"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$TMP_DIR/main.zip" "$ZIP_URL"
  else
    echo "Erro: nem curl nem wget encontrados. Instale um deles para continuar."
    exit 1
  fi
  unzip -q "$TMP_DIR/main.zip" -d "$TMP_DIR"
  sudo rm -rf "$INSTALL_DIR"
  sudo mv "$TMP_DIR/SmartSafeHanaOpusCloud-main" "$INSTALL_DIR"
  sudo rm -rf "$TMP_DIR"
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
