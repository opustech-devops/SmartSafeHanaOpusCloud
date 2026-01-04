echo -e "${GREEN}Configuração concluída.${NC}"

# Define o caminho do arquivo
SCHEDULED_SCRIPT="$BASE_PATH/OpusTechSmartSafe_scheduled.sh"

# Cria e abre o arquivo para escrita
{
    echo "#!/bin/bash"
    echo
    echo "# Variáveis coletadas"
    SAP_HOSTNAME=$(su - "${USERNAME_LINUX}" -c 'echo $SAP_HOSTNAME')
    echo "HOSTNAME=\"$SAP_HOSTNAME\""
    echo "INSTANCE_NAME=\"$INSTANCE_NAME\""
    echo "INSTANCE_NUMBER=\"$INSTANCE_NUMBER\""
    echo "PORT=\"$PORT\""
    echo "SYSTEMDB_USER=\"$SYSTEMDB_USER\""
    echo "SYSTEMDB_PASSWORD=\"$SYSTEMDB_PASSWORD\""
    echo "USERNAME_LINUX=\"$USERNAME_LINUX\""
    echo "BASE_PATH=\"$BASE_PATH\""
    echo "DATA_BACKUP_PATH=\"$DATA_BACKUP_PATH\""
    echo "DIR_INSTANCE=\"$DIR_INSTANCE\""
    echo "DATABASE_LIST=\"$DATABASE_LIST\""
    echo "SCHEMA_BACKUP_PATH=\"$SCHEMA_BACKUP_PATH\""
    echo "SCHEDULED_SCRIPT=\"$SCHEDULED_SCRIPT\""
    echo "COPY_TO_ANOTHER_LOCATION=\"$COPY_TO_ANOTHER_LOCATION\""
    echo "COPY_PATH=\"$COPY_PATH\""
    echo "SEND_EMAIL=\"$SEND_EMAIL\""
    echo "EMAIL_ADDRESS=\"$EMAIL_ADDRESS\""
    echo "SMTP_SERVER=\"$SMTP_SERVER\""
    echo "SMTP_PORT=\"$SMTP_PORT\""
    echo "EMAIL_USER=\"$EMAIL_USER\""
    echo "EMAIL_REMETENTE=\"$EMAIL_REMETENTE\""
    echo "EMAIL_PASSWORD=\"$EMAIL_PASSWORD\""
    echo "EMAIL_RECEIVED=\"$EMAIL_RECEIVED\""
    echo "RETRY_EMAIL=\"$RETRY_EMAIL\""

    # Redireciona a saída do script para um arquivo de log com timestamp
    echo "LOG_FILE=\"\$BASE_PATH/logs/OpusTechSmartSafe_\$(date +%Y%m%d_%H%M%S).log\""
    echo "exec > >(tee -a \"\$LOG_FILE\") 2>&1"

    # Variáveis do hdbuserstore
    HDBUSERSTORE_SYSTEMDB="SmartSafeOpusTech.SYSTEMDB"
    echo "HDBUSERSTORE_SYSTEMDB=\"$HDBUSERSTORE_SYSTEMDB\""

    echo "# Diretórios e arquivos de log do SYSTEMDB"
    echo "SYSTEMDB_LOG_DIR=\"\$DIR_INSTANCE/\$HOSTNAME/trace\""
    echo "SYSTEMDB_LOG_FILE=\"backup.log\""
    echo "SYSTEMDB_BACKUP_LOG_DIR=\"\$BASE_PATH/logs\""
    echo "SYSTEMDB_BACKUP_LOG_FILE=\"\$SYSTEMDB_BACKUP_LOG_DIR/systemdb_backup_\$(date +%Y%m%d_%H%M%S).log\""
    echo

    # Função para monitorar o log
    echo "monitor_log() {"
    echo "  local log_dir=\$1"
    echo "  local log_file=\$2"
    echo "  local backup_log_dir=\$3"
    echo "  local backup_log_file=\$4"
    echo "  local comment=\$5"
    echo
    echo "  mkdir -p \"\$backup_log_dir\""
    echo "  if [[ ! -f \"\$log_dir/\$log_file\" ]]; then"
    echo "    echo \"Arquivo de log não encontrado. Criando: \$log_dir/\$log_file\""
    echo "    touch \"\$log_dir/\$log_file\""
    echo "    chmod 777 \"\$log_dir/\$log_file\""
    echo "  fi"
    echo "  if [[ ! -f \"\$backup_log_file\" ]]; then"
    echo "    touch \"\$backup_log_file\""
    echo "    chmod 777 \"\$backup_log_file\""
    echo "  fi"
    echo "  echo \"\$comment\" > \"\$backup_log_file\""
    echo "  tail -f \"\$log_dir/\$log_file\" | grep --line-buffered \"BACKUP\" >> \"\$backup_log_file\" &"
    echo "  echo \$!"
    echo "}"

    echo "# Função para verificar o status do backup no log"
    echo "check_backup_status() {"
    echo "  local log_file=\$1"
    echo "  local success_message=\$2"
    echo
    echo "  sleep 10"
    echo
    echo "  local current_date=\$(date +%Y-%m-%d)"  # Data atual no formato AAAA-MM-DD
    echo
    echo "  if [[ -s \"\$log_file\" ]]; then"
    echo "    # Filtra linhas do log com a mensagem de sucesso e data atual"
    echo "    local valid_lines=\$(grep \"\$success_message\" \"\$log_file\" | grep \"\$current_date\")"
    echo "    if [[ -n \"\$valid_lines\" ]]; then"
    echo "      local last_line=\$(echo \"\$valid_lines\" | tail -n1)"  # Obtém a última linha válida"
    echo "      echo \"Última linha do log: \$last_line\""
    echo "      echo \"Comentário: Backup foi realizado com sucesso.\""
    echo "    else"
    echo "      echo \"O backup não foi concluído com sucesso ou não é de hoje. Verifique o log para mais detalhes.\""
    echo "    fi"
    echo "  else"
    echo "    echo \"O arquivo de log está vazio ou não foi criado.\""
    echo "  fi"
    echo "}"

    # Monitorar Log
    echo "echo \"Iniciando monitoramento do log do SYSTEMDB...\""
    echo "TAIL_PID_SYSTEMDB=\$(monitor_log \"\$SYSTEMDB_LOG_DIR\" \"\$SYSTEMDB_LOG_FILE\" \"\$SYSTEMDB_BACKUP_LOG_DIR\" \"\$SYSTEMDB_BACKUP_LOG_FILE\" \"Backup do SYSTEMDB\")"
    echo "if [[ -z \"\$TAIL_PID_SYSTEMDB\" ]]; then"
    echo "  echo \"Falha ao iniciar monitoramento do log do SYSTEMDB.\""
    echo "  exit 1"
    echo "fi"
    echo "echo \"Monitoramento do log do SYSTEMDB iniciado com PID: \$TAIL_PID_SYSTEMDB\""
    echo

    # Define arquivos para armazenar comandos SQL e resultados
    echo "GET_BACKUP_ID_FILE=\"\$SYSTEMDB_BACKUP_LOG_DIR/get_backup_id_\$(date +%Y%m%d_%H%M%S).sql\""
    echo "GET_BACKUP_ID_OUTPUT_FILE=\"\$SYSTEMDB_BACKUP_LOG_DIR/get_backup_id_output_\$(date +%Y%m%d_%H%M%S).sql\""

    # Garante que o diretório de logs exista
    echo "echo \"Criando diretório de logs se não existir...\""
    echo "mkdir -p \"\$SYSTEMDB_BACKUP_LOG_DIR\""
    echo "chmod 777 \"\$SYSTEMDB_BACKUP_LOG_DIR\""
    echo "echo \"Diretório de logs criado.\""

    # Cria o arquivo de entrada com os comandos SQL
    echo "echo \"Criando arquivo de entrada com comandos SQL...\""
    echo "cat <<EOF > \"\$GET_BACKUP_ID_FILE\""
    echo "select 'BACKUP CATALOG DELETE ALL BEFORE BACKUP_ID ' || backup_id || ' WITH FILE;'"
    echo "from sys.m_backup_catalog"
    echo "where entry_type_name = 'complete data backup' and state_name = 'successful'"
    echo "order by backup_id desc"
    echo "limit 1;"
    echo "EOF"
    echo "echo \"Arquivo de entrada com comandos SQL criado.\""

    # Executa o comando SQL e grava a saída em um arquivo separado
    echo "echo \"Executando comando SQL para obter o ID do backup...\""
    echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_SYSTEMDB -x -A -F \\\" \\\" -a -m -I \$GET_BACKUP_ID_FILE -o \$GET_BACKUP_ID_OUTPUT_FILE\""
    echo "echo \"Comando SQL executado.\""

    # Utiliza o arquivo de saída para limpar backups anteriores
    echo "echo \"Limpando backups anteriores do SYSTEMDB...\""
    echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_SYSTEMDB -x -A -F \\\" \\\" -a -m -I \$GET_BACKUP_ID_OUTPUT_FILE\""
    echo "echo \"Backups anteriores do SYSTEMDB limpos.\""

    # Executa o novo backup do SYSTEMDB
    echo "echo \"Executando novo backup do SYSTEMDB...\""
    echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_SYSTEMDB \\\"backup data for SYSTEMDB using file ('COMPLETE_DATA_BACKUP')\\\"\""
    echo "echo \"Novo backup do SYSTEMDB executado.\""

    # Finaliza o monitoramento do log e exibe o status do backup
    echo "kill \$TAIL_PID_SYSTEMDB"
    echo "echo \"Logs do backup do SYSTEMDB foram salvos em \$SYSTEMDB_BACKUP_LOG_FILE\""
    echo "check_backup_status \"\$SYSTEMDB_BACKUP_LOG_FILE\" \"SAVE DATA finished successfully\""
    echo "echo \"---------------\""

    # Backup para todos os tenants
    for DATABASE in "${DATABASE_ARRAY[@]}"; do
        echo
        echo "# Backup do tenant $DATABASE"
        # Declarar Varáveis
        echo "TENANT_LOG_DIR=\"\$DIR_INSTANCE/\$HOSTNAME/trace/DB_$DATABASE\""
        echo "TENANT_LOG_FILE=\"backup.log\""
        echo "TENANT_BACKUP_LOG_DIR=\"\$BASE_PATH/logs\""
        echo "TENANT_BACKUP_LOG_FILE=\"\$TENANT_BACKUP_LOG_DIR/${DATABASE}_backup_\$(date +%Y%m%d_%H%M%S).log\""
        echo "HDBUSERSTORE_TENANT_$DATABASE=SmartSafeOpusTech.$DATABASE"

        # Monitorar Log
        echo "echo \"Iniciando monitoramento do log do tenant $DATABASE...\""
        echo "TAIL_PID_TENANT=\$(monitor_log \"\$TENANT_LOG_DIR\" \"\$TENANT_LOG_FILE\" \"\$TENANT_BACKUP_LOG_DIR\" \"\$TENANT_BACKUP_LOG_FILE\" \"Backup do tenant $DATABASE\")"
        echo "if [[ -z \"\$TAIL_PID_TENANT\" ]]; then"
        echo "  echo \"Falha ao iniciar monitoramento do log do tenant $DATABASE.\""
        echo "  exit 1"
        echo "fi"
        echo "echo \"Monitoramento do log do tenant $DATABASE iniciado com PID: \$TAIL_PID_TENANT\""

        # Define arquivos para armazenar comandos SQL e resultados
        echo "GET_BACKUP_ID_FILE=\"\$TENANT_BACKUP_LOG_DIR/get_backup_id_\$(date +%Y%m%d_%H%M%S).sql\""
        echo "GET_BACKUP_ID_OUTPUT_FILE=\"\$TENANT_BACKUP_LOG_DIR/get_backup_id_output_\$(date +%Y%m%d_%H%M%S).sql\""

        # Garante que o diretório de logs exista
        echo "echo \"Criando diretório de logs se não existir...\""
        echo "mkdir -p \"\$TENANT_BACKUP_LOG_DIR\""
        echo "chmod 777 \"\$TENANT_BACKUP_LOG_DIR\""
        echo "echo \"Diretório de logs criado.\""

        # Cria o arquivo de entrada com os comandos SQL
        echo "echo \"Criando arquivo de entrada com comandos SQL...\""
        echo "cat <<EOF > \"\$GET_BACKUP_ID_FILE\""
        echo "select 'BACKUP CATALOG DELETE ALL BEFORE BACKUP_ID ' || backup_id || ' WITH FILE;'"
        echo "from sys.m_backup_catalog"
        echo "where entry_type_name = 'complete data backup' and state_name = 'successful'"
        echo "order by backup_id desc"
        echo "limit 1;"
        echo "EOF"
        echo "echo \"Arquivo de entrada com comandos SQL criado.\""

        # Executa o comando SQL e grava a saída em um arquivo separado
        echo "echo \"Executando comando SQL para obter o ID do backup...\""
        echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_TENANT_$DATABASE -x -A -F \\\" \\\" -a -m -I \$GET_BACKUP_ID_FILE -o \$GET_BACKUP_ID_OUTPUT_FILE\""
        echo "echo \"Comando SQL executado.\""

        # Utiliza o arquivo de saída para limpar backups anteriores
        echo "echo \"Limpando backups anteriores do $DATABASE...\""
        echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_TENANT_$DATABASE -x -A -F \\\" \\\" -a -m -I \$GET_BACKUP_ID_OUTPUT_FILE\""
        echo "echo \"Backups anteriores do $DATABASE limpos.\""

        # Executa o novo backup do Tenant
        echo "echo \"Executando novo backup do $DATABASE...\""
        echo "su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_TENANT_$DATABASE \\\"backup data using file ('COMPLETE_DATA_BACKUP')\\\"\""
        echo "echo \"Novo backup do $DATABASE executado.\""

        # Finaliza o monitoramento do log e exibe o status do backup
        echo "echo \"Finalizando monitoramento do log do tenant $DATABASE...\""
        echo "kill \$TAIL_PID_TENANT"
        echo "echo \"Logs do backup do tenant $DATABASE foram salvos em \$TENANT_BACKUP_LOG_FILE\""
        echo "check_backup_status \"\$TENANT_BACKUP_LOG_FILE\" \"SAVE DATA finished successfully\""
        echo "echo \"Backup do tenant $DATABASE concluído.\""
        echo "echo \"---------------\""

        echo "IFS=$'\n' read -rd '' -a SCHEMAS_TO_EXPORT <<<\"\$DB_NAMES_$DATABASE\""

        # Define o diretório temporário fora do caminho da instância
        echo "TEMP_EXPORT_DIR=\"/tmp/sap_exports/export_\$(date +%Y%m%d_%H%M%S)\""
        echo "mkdir -p \"\$TEMP_EXPORT_DIR\""
        echo "chmod 777 \"\$TEMP_EXPORT_DIR\""

        echo "for SCHEMA_NAME in \"\${SCHEMAS_TO_EXPORT[@]}\"; do"
        echo "    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)"
        echo "    EXPORT_DIR=\"\$TEMP_EXPORT_DIR/\$SCHEMA_NAME\""
        echo "    mkdir -p \"\$EXPORT_DIR\""
        echo "    chmod 777 \"\$EXPORT_DIR\""

        # Comando de exportação
        echo "    EXPORT_COMMAND=\"export \\\"\$SCHEMA_NAME\\\".\\\"*\\\" as binary into '\$EXPORT_DIR' with replace threads 10;\""
        echo "    EXPORT_COMMAND_FILE=\$(mktemp \"/tmp/sap_exports/export_command.XXXXXX.sql\")"
        echo "    echo \"\$EXPORT_COMMAND\" > \"\$EXPORT_COMMAND_FILE\""
        echo "    chmod 777 \"\$EXPORT_COMMAND_FILE\""
        echo "    echo \"Iniciando o export da base \$SCHEMA_NAME...\""
        echo "    su - \"\$USERNAME_LINUX\" -c \"hdbsql -U \$HDBUSERSTORE_TENANT_$DATABASE -x -A -F \\\" \\\" -a -m -I \$EXPORT_COMMAND_FILE\""
        echo "    echo \"Export da base \$SCHEMA_NAME concluído.\""

        # Verifica se a pasta de exportação contém arquivos antes de compactar
        echo "    if [ -n \"\$(ls -A \"\$EXPORT_DIR\" 2>/dev/null)\" ]; then"
        echo "    ZIP_FILE=\"\$SCHEMA_BACKUP_PATH/\$SCHEMA_NAME/\$SCHEMA_NAME_\$TIMESTAMP.zip\""
        echo "    mkdir -p \"\$SCHEMA_BACKUP_PATH/\$SCHEMA_NAME\""
        echo "    chmod 777 \"\$SCHEMA_BACKUP_PATH/\$SCHEMA_NAME\""
        echo "        echo \"Compactando o backup da base \$SCHEMA_NAME...\""
        echo "        zip -rq \"\$ZIP_FILE\" \"\$EXPORT_DIR\""
        echo "        echo \"O backup da base \$SCHEMA_NAME foi concluído com sucesso no caminho \$ZIP_FILE\""

        echo "    else"
        echo "        echo \"${RED}Erro: A pasta de exportação '\$EXPORT_DIR' está vazia. Exportação do schema \$SCHEMA_NAME falhou.${NC}\" >&2"
        echo "    fi"

        # Remove arquivos e diretórios temporários
        echo "    echo \"Removendo arquivos temporários para o schema \$SCHEMA_NAME...\""
        echo "    rm -rf \"\$EXPORT_DIR\""
        echo "    rm -f \"\$EXPORT_COMMAND_FILE\""
        echo "done"

        # Remove o diretório temporário geral após o uso
        echo "rm -rf \"\$TEMP_EXPORT_DIR\""
    done

    # Copia os arquivos para outra localização
    if [[ $COPY_TO_ANOTHER_LOCATION =~ ^[sS]$ ]]; then
        echo "echo \"Copiando todos os arquivos:\""
        echo "echo \"-------------------------------------------------------------\""
        echo "echo \"Origem: $BASE_PATH\""
        echo "echo \"Destino: $COPY_PATH\""
        echo "echo \"-------------------------------------------------------------\""
        echo "cp -r \"$BASE_PATH\" \"$COPY_PATH\""
    fi

    # Limpa Exports de empresas mais antigos
    echo "echo \"Limpando backups antigos...\""
    echo "find \"$SCHEMA_BACKUP_PATH\" -type f -name '*.zip' -mtime +7 -exec rm {} \;"

    # Remove todos os backups com idade maior que 90 dias
    echo "find "$SCHEMA_BACKUP_PATH" -type f -name '*.zip' -mtime +90 -exec rm {} \;"

    # Remove todos os backups com idade maior que 7 dias e que não foram feitos em dias terminam com 1
    echo "find "$SCHEMA_BACKUP_PATH" -type f -name '*.zip' -mtime +7 ! -name '*1_*.zip' -exec rm {} \;"

    # Remove todos os logs com idade maior que 7 dias
    echo "find "$BASE_PATH/logs" -type f -name '*.log' -mtime +7 -exec rm {} \;"
    echo
    # Envia email
    if [[ $SEND_EMAIL =~ ^[sS]$ ]]; then
        echo "echo \"Enviando email para $EMAIL_ADDRESS...\""
        echo "EMAIL_BODY=\"Backup do tenant $DATABASE foi concluído com sucesso.\n\nLog do backup:\n\n\$(cat \$LOG_FILE)\""
        echo "{ echo -e \"\$EMAIL_BODY\"; } | mailx -v -s \"Backup do Banco HANA \$HOSTNAME concluído\" \\"
        echo "    -S smtp=\"smtp://\$SMTP_SERVER:\$SMTP_PORT\" \\"
        echo "    -S smtp-use-starttls \\"
        echo "    -S ssl-verify=ignore \\"
        echo "    -S smtp-auth=login \\"
        echo "    -S smtp-auth-user=\"\$EMAIL_USER\" \\"
        echo "    -S smtp-auth-password=\"\$EMAIL_PASSWORD\" \\"
        echo "    -S from=\"\$EMAIL_REMETENTE\" \\"
        echo "    \"\$EMAIL_ADDRESS\" > /dev/null 2>&1 && echo \"Email enviado com sucesso para \$EMAIL_ADDRESS.\""
    fi
} > "$SCHEDULED_SCRIPT"

# Torna o arquivo executável
chmod +x "$SCHEDULED_SCRIPT"

# Exibe o conteúdo do arquivo
echo -e "${GREEN}Arquivo de configuração gerado: $SCHEDULED_SCRIPT${NC}"
#cat "$SCHEDULED_SCRIPT"

# Solicita o horário para rodar o backup
echo
echo -e "${PURPLE}Informe o horário para executar o backup diariamente (formato HH:MM, ex: 23:30): ${NC}"
read -p "--->    " BACKUP_TIME

# Valida o formato HH:MM
while [[ ! "$BACKUP_TIME" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; do
    echo -e "${RED}Horário inválido. Certifique-se de usar o formato HH:MM, ex: 23:30.${NC}"
    echo -e "${PURPLE}Informe o horário para executar o backup diariamente (formato HH:MM): ${NC}"
    read -p "--->    " BACKUP_TIME
done

# Converte para formato cron
CRON_HOUR=$(echo "$BACKUP_TIME" | cut -d':' -f1)
CRON_MINUTE=$(echo "$BACKUP_TIME" | cut -d':' -f2)

# Define a entrada no crontab
CRON_ENTRY="$CRON_MINUTE $CRON_HOUR * * * $SCHEDULED_SCRIPT"

# Extrai o nome do arquivo do script
SCRIPT_NAME=$(basename "$SCHEDULED_SCRIPT")

# Verifica se já existe uma entrada para o script no crontab, buscando apenas pelo nome do arquivo
EXISTING_ENTRY=$(crontab -l 2>/dev/null | grep -F "$SCRIPT_NAME")

if [[ -n "$EXISTING_ENTRY" ]]; then
    # Atualiza a entrada existente
    (crontab -l 2>/dev/null | grep -vF "$SCRIPT_NAME"; echo "$CRON_ENTRY") | crontab -
    echo
    echo -e "${GREEN}A entrada existente no crontab foi atualizada para rodar diariamente às $BACKUP_TIME.${NC}"
else
    # Adiciona nova entrada ao crontab
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo
    echo -e "${GREEN}Backup agendado com sucesso para rodar diariamente às $BACKUP_TIME.${NC}"
fi