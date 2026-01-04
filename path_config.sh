# Configuração de caminhos e email em uma tela
if [ -z "$DATA_BACKUP_PATH" ]; then
    AVAILABLE_SPACE="N/A"
else
    AVAILABLE_SPACE=$(df -h "$DATA_BACKUP_PATH" | awk 'NR==2 {print $4}')
fi

exec 3>&1
VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --form "Configurações de Backup e Email" 30 120 25 \
    "Caminho do Backup:" 1 1 "$DATA_BACKUP_PATH" 1 25 80 1 \
    "Mover Backups (s/n):" 3 1 "n" 3 25 5 1 \
    "Empresas para Backup:" 5 1 "$ALL_COMPANIES" 5 25 80 0 \
    "Espaço Disponível:" 7 1 "$AVAILABLE_SPACE" 7 25 20 0 \
    "Enviar Email (s/n):" 9 1 "s" 9 25 5 1 \
    "Endereços Email:" 11 1 "" 11 25 80 1 \
    "Servidor SMTP:" 13 1 "" 13 25 80 1 \
    "Porta SMTP:" 15 1 "587" 15 25 10 1 \
    "Usuário Email:" 17 1 "" 17 25 80 1 \
    "Remetente:" 19 1 "" 19 25 80 1 \
    "Senha Email:" 21 1 "" 21 25 80 1 \
    2>&1 1>&3)
exec 3>&-

# Parse values
BACKUP_PATH=$(echo "$VALUES" | sed -n '1p')
MOVE_BACKUPS=$(echo "$VALUES" | sed -n '2p')
SEND_EMAIL=$(echo "$VALUES" | sed -n '3p')
EMAIL_ADDRESSES=$(echo "$VALUES" | sed -n '4p')
SMTP_SERVER=$(echo "$VALUES" | sed -n '5p')
SMTP_PORT=$(echo "$VALUES" | sed -n '6p')
EMAIL_USER=$(echo "$VALUES" | sed -n '7p')
EMAIL_REMETENTE=$(echo "$VALUES" | sed -n '8p')
EMAIL_PASSWORD=$(echo "$VALUES" | sed -n '9p')

# Reconfigure if path changed
if [ "$BACKUP_PATH" != "$DATA_BACKUP_PATH" ]; then
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --yesno "O caminho de backup foi alterado. Deseja reconfigurar o HANA?" 7 100
    if [ $? -eq 0 ]; then
        execute_sql "SmartSafeOpusTech.SYSTEMDB" "ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'basepath_databackup') = '$BACKUP_PATH/data' WITH RECONFIGURE;" "$USERNAME_LINUX"
        execute_sql "SmartSafeOpusTech.SYSTEMDB" "ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'basepath_logbackup') = '$BACKUP_PATH/log' WITH RECONFIGURE;" "$USERNAME_LINUX"
        DATA_BACKUP_PATH="$BACKUP_PATH"
    fi
fi

# Lógica baseada nos valores
if [ "$MOVE_BACKUPS" = "s" ]; then
    COPY_PATH=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --inputbox "Informe o caminho para copiar o backup:" 10 100 2>&1)
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --msgbox "\Zb\Z4O backup será copiado diariamente para o diretório $COPY_PATH.\n\Z1Aviso: Certifique-se de que o caminho de cópia tenha espaço suficiente para os backups." 8 100
fi