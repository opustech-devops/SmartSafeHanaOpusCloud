# Coleta valores predefinidos
log "Iniciando coleta de parâmetros do sistema"
HOSTNAME=$(hostname)
log "Hostname detectado: $HOSTNAME"
INSTANCE_NAME=$(ls -d /hana/shared/*/ | grep -oP '(?<=/hana/shared/)[A-Z]{3}(?=/)')
log "Nome da instância detectado: $INSTANCE_NAME"
INSTANCE_NUMBER=$(ls -d /hana/shared/"$INSTANCE_NAME"/HDB*/ | grep -oP '(?<=HDB)[0-9]{2}')
log "Número da instância detectado: $INSTANCE_NUMBER"
DATABASE=SYSTEMDB
log "Banco padrão: $DATABASE"

# Cria ou atualiza a entrada do hdbuserstore para o SYSTEMDB
HDBUSERSTORE_NAME="SmartSafeOpusTech_$DATABASE"
log "Nome do hdbuserstore para SYSTEMDB: $HDBUSERSTORE_NAME"

# Solicitação de confirmação ****************************************************************************************************************
if dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --yesno "\Zb\Z4Este é o assistente gratuito para backup de SAP HANA da OpusTech.\nDesenvolvido para auxiliar na manutenção dos backups de ambientes que utilizam banco de dados HANA, como SAP Business One, S/4 HANA, ECC on HANA, entre outros.\n\nEste script é distribuído gratuitamente pela equipe de DBA's da OpusTech, para facilitar a administração, melhorar a disponibilidade e a resiliência de um dos sistemas mais críticos de uma organização: o seu ERP.\n\n\Z1A utilização deste script não implica em qualquer responsabilidade ou ônus para a OpusTech e seus especialistas. Não há garantia de integridade dos dados gerados nem de sua recuperabilidade.\n\nÉ imprescindível que outros fatores sejam considerados, como: Persistência dos dados em mais locais; Testes periódicos dos backups; Acompanhamento da correta execução do processo.\n\n\Z0Versão 2.2 - 04/01/2026\n\n\Z4Você concorda com os termos acima e deseja continuar?" 30 100; then
    log "Usuário concordou com os termos, iniciando configuração"
    echo -e "${GREEN}Iniciando SmartSafeHanaOpusCloud: ${NC}"
    # Continue o script
    sleep 0
else
    log "Usuário não concordou com os termos, encerrando script"
    echo -e "${RED}Você optou por não concordar. O script será encerrado.${NC}"
    exit 1
fi

# Loop para permitir correção de senhas
while true; do
    # Form para confirmar parâmetros e inserir senhas
    exec 3>&1
    VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --form "Parâmetros do Sistema - Valores detectados automaticamente:
--------------------------------------------------------------------------------
Nota: As senhas são visíveis durante a digitação por limitações do TUI." 28 100 0 \
        "Hostname:" 1 1 "$HOSTNAME" 1 25 45 0 \
        "Instância:" 3 1 "$INSTANCE_NAME" 3 25 45 0 \
        "Número:" 5 1 "$INSTANCE_NUMBER" 5 25 45 0 \
        "Credenciais SYSTEMDB:" 8 1 "" 8 25 0 0 \
        "Usuário:" 10 1 "SYSTEM" 10 25 45 0 \
        "Senha:" 12 1 "" 12 25 45 0 \
        "Credenciais Tenants:" 15 1 "" 15 25 0 0 \
        "Usuário:" 17 1 "SYSTEM" 17 25 45 0 \
        "Senha:" 19 1 "" 19 25 45 0 \
        2>&1 1>&3)
    exec 3>&-

    # Parse the values
    HOSTNAME=$(echo "$VALUES" | sed -n '1p')
    INSTANCE_NAME=$(echo "$VALUES" | sed -n '2p')
    INSTANCE_NUMBER=$(echo "$VALUES" | sed -n '3p')
    DB_USER=$(echo "$VALUES" | sed -n '4p')
    DB_PASSWORD=$(echo "$VALUES" | sed -n '5p')
    TENANT_USER=$(echo "$VALUES" | sed -n '6p')
    TENANT_PASSWORD=$(echo "$VALUES" | sed -n '7p')

    validate_instance_name "$INSTANCE_NAME"
    validate_instance_number "$INSTANCE_NUMBER"
    PORT="3${INSTANCE_NUMBER}13"
    USERNAME_LINUX=$(echo "${INSTANCE_NAME,,}adm")

    # Configura os hdbuserstores para SYSTEMDB
    if handle_hdbuserstore "$HDBUSERSTORE_NAME" "$HOSTNAME" "$PORT" "$DATABASE" "$DB_USER" "$DB_PASSWORD" "$USERNAME_LINUX"; then
        break  # Sucesso, sai do loop
    else
        dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "Falha na configuração do hdbuserstore para SYSTEMDB. Corrija as credenciais e tente novamente." 7 100
        # Continua o loop para re-exibir o form
    fi
done

# Define um array para armazenar os nomes do hdbuserstore
HDBUSERSTORE_NAMES=()

# Configura o hdbuserstore para o tenant principal
MAIN_TENANT="$INSTANCE_NAME"
if ! handle_hdbuserstore "SmartSafeOpusTech_$MAIN_TENANT" "$HOSTNAME" "$PORT" "$MAIN_TENANT" "$TENANT_USER" "$TENANT_PASSWORD" "$USERNAME_LINUX"; then
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "Falha na configuração do hdbuserstore para $MAIN_TENANT. Verifique as credenciais." 7 100
    exit 1
fi
log "Configuração e validação concluídas com sucesso para SmartSafeOpusTech_$MAIN_TENANT"

# Verifica se o schema SBOCOMMON existe no banco para o tenant principal
# check_sbo_query="SELECT 1 FROM SCHEMAS WHERE SCHEMA_NAME = 'SBOCOMMON';"
# result=$(execute_sql "SmartSafeOpusTech_$MAIN_TENANT" "$check_sbo_query" "$USERNAME_LINUX")

# if [[ -n "$result" ]]; then
#     dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --infobox "Tenant $MAIN_TENANT roda SAP Business One. Verificando empresas..." 5 50

#     # Executa query para pegar os nomes das bases no SBOCOMMON.SRGC
#     select_db_query="SELECT \"dbName\" FROM SBOCOMMON.SRGC;"
#     db_names=$(execute_sql "SmartSafeOpusTech_$MAIN_TENANT" "$select_db_query" "$USERNAME_LINUX")
#     # Limpar espaços e quebras de linha
#     db_names_clean=$(echo "$db_names" | tr -d '\n' | tr -s ' ' | sed 's/^ *//;s/ *$//')

#     # Usar todas as empresas encontradas
#     eval "DATABASES_TO_BACKUP_$MAIN_TENANT=($db_names_clean)"
#     echo "DB_NAMES_$MAIN_TENANT=\"$db_names_clean\""
# fi

log "Detectando databases tenants adicionais..."
DATABASE_LIST=$(execute_sql "SmartSafeOpusTech_$DATABASE" "SELECT DATABASE_NAME FROM M_DATABASES WHERE DATABASE_NAME != 'SYSTEMDB' AND DATABASE_NAME != '$INSTANCE_NAME';" "$USERNAME_LINUX")
log "Databases tenants adicionais detectados: $DATABASE_LIST"

# Configura backups para tenants adicionais
IFS=$'\n' read -rd '' -a DATABASE_ARRAY <<<"$DATABASE_LIST"
for DATABASE in "${DATABASE_ARRAY[@]}"; do
    DATABASE=$(echo "$DATABASE" | xargs) # Remove espaços em branco

    # Form para credenciais do tenant adicional
    exec 3>&1
    VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --form "Credenciais para Tenant Adicional: $DATABASE" 10 100 0 \
        "Usuário:" 1 1 "SYSTEM" 1 20 20 0 \
        "Senha:" 3 1 "" 3 20 20 0 \
        2>&1 1>&3)
    exec 3>&-

    ADD_USER=$(echo "$VALUES" | sed -n '1p')
    ADD_PASSWORD=$(echo "$VALUES" | sed -n '2p')

    # Configura os hdbuserstores para o tenant adicional
    if ! handle_hdbuserstore "SmartSafeOpusTech_$DATABASE" "$HOSTNAME" "$PORT" "$DATABASE" "$ADD_USER" "$ADD_PASSWORD" "$USERNAME_LINUX"; then
        dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "Falha na configuração do hdbuserstore para $DATABASE. Verifique as credenciais." 7 100
        exit 1
    fi
    log "Configuração e validação concluídas com sucesso para SmartSafeOpusTech_$DATABASE"

    # Verifica se o schema SBOCOMMON existe no banco
    # result=$(execute_sql "SmartSafeOpusTech_$DATABASE" "$check_sbo_query" "$USERNAME_LINUX")

    # if [[ -n "$result" ]]; then
    #     dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --infobox "Tenant $DATABASE roda SAP Business One. Verificando empresas..." 5 50

    #     # Executa query para pegar os nomes das bases no SBOCOMMON.SRGC
    #     db_names=$(execute_sql "SmartSafeOpusTech_$DATABASE" "$select_db_query" "$USERNAME_LINUX")
    #     # Limpar espaços e quebras de linha
    #     db_names_clean=$(echo "$db_names" | tr -d '\n' | tr -s ' ' | sed 's/^ *//;s/ *$//')

    #     # Usar todas as empresas encontradas
    #     eval "DATABASES_TO_BACKUP_$DATABASE=($db_names_clean)"
    #     echo "DB_NAMES_$DATABASE=\"$db_names_clean\""
    # fi
done

# Collect all companies
ALL_COMPANIES=""
TENANT_LIST=("$MAIN_TENANT" "${DATABASE_ARRAY[@]}")
for DATABASE in "${TENANT_LIST[@]}"; do
    eval "companies=(\${DATABASES_TO_BACKUP_$DATABASE[@]})"
    ALL_COMPANIES="$ALL_COMPANIES ${companies[*]}"
done
ALL_COMPANIES=$(echo "$ALL_COMPANIES" | tr -s ' ' | sed 's/^ *//;s/ *$//')

dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "hdbuserstore configurado com sucesso para SYSTEMDB e todos os tenants." 6 100

dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --msgbox "\Zb\Z4Hoje o seu banco está configurado para fazer backup de dados na seguinte diretório:\n\n\Z0$DATA_BACKUP_PATH" 8 60
 
 