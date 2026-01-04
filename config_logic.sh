# Coleta valores predefinidos
HOSTNAME=$(hostname)
INSTANCE_NAME=$(ls -d /hana/shared/*/ | grep -oP '(?<=/hana/shared/)[A-Z]{3}(?=/)')
INSTANCE_NUMBER=$(ls -d /hana/shared/"$INSTANCE_NAME"/HDB*/ | grep -oP '(?<=HDB)[0-9]{2}')
DATABASE=SYSTEMDB

# Cria ou atualiza a entrada do hdbuserstore para o SYSTEMDB
HDBUSERSTORE_NAME="SmartSafeOpusTech.$DATABASE"

# Solicitação de confirmação ****************************************************************************************************************
if dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --yesno "Você concorda com os termos acima e deseja continuar?" 10 50; then
    echo -e "${GREEN}Iniciando SmartSafeHanaOpusCloud: ${NC}"
    # Continue o script
    sleep 0
else
    echo -e "${RED}Você optou por não concordar. O script será encerrado.${NC}"
    exit 1
fi

# Valida os valores coletados
validate_instance_name "$INSTANCE_NAME"
validate_instance_number "$INSTANCE_NUMBER"

# Menu para usar valores pré-definidos
dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --radiolist "Deseja usar os valores pré-definidos detectados?\n\nHostname: $HOSTNAME\nInstância: $INSTANCE_NAME\nNúmero: $INSTANCE_NUMBER" 15 50 2 1 "Sim" on 2 "Não" off 2> /tmp/use_predefined
USE_PREDEFINED=$(cat /tmp/use_predefined)
rm /tmp/use_predefined

if [ "$USE_PREDEFINED" = "2" ]; then
    # Form para inserir valores customizados
    exec 3>&1
    VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --form "Insira os parâmetros de configuração:" 20 60 0 \
        "Hostname:" 1 1 "$HOSTNAME" 1 20 30 0 \
        "Nome da Instância:" 2 1 "$INSTANCE_NAME" 2 20 30 0 \
        "Número da Instância:" 3 1 "$INSTANCE_NUMBER" 3 20 30 0 \
        "Usuário SYSTEMDB:" 4 1 "SYSTEM" 4 20 30 0 \
        "Senha SYSTEMDB:" 5 1 "" 5 20 30 0 \
        2>&1 1>&3)
    exec 3>&-
    
    # Parse the values
    HOSTNAME=$(echo "$VALUES" | sed -n '1p')
    INSTANCE_NAME=$(echo "$VALUES" | sed -n '2p')
    INSTANCE_NUMBER=$(echo "$VALUES" | sed -n '3p')
    DB_USER=$(echo "$VALUES" | sed -n '4p')
    DB_PASSWORD=$(echo "$VALUES" | sed -n '5p')
    
    validate_instance_name "$INSTANCE_NAME"
    validate_instance_number "$INSTANCE_NUMBER"
    PORT="3${INSTANCE_NUMBER}13"
    USERNAME_LINUX=$(echo "${INSTANCE_NAME,,}adm")
else
    PORT="3${INSTANCE_NUMBER}13"
    # Form para usuário e senha apenas
    exec 3>&1
    VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --form "Insira as credenciais do SYSTEMDB:" 15 50 0 \
        "Usuário SYSTEMDB:" 1 1 "SYSTEM" 1 20 30 0 \
        "Senha SYSTEMDB:" 2 1 "" 2 20 30 0 \
        2>&1 1>&3)
    exec 3>&-
    
    DB_USER=$(echo "$VALUES" | sed -n '1p')
    DB_PASSWORD=$(echo "$VALUES" | sed -n '2p')
    USERNAME_LINUX=$(echo "${INSTANCE_NAME,,}adm")
fi

# Configura os hdbuserstores
handle_hdbuserstore "$HDBUSERSTORE_NAME" "$HOSTNAME" "$PORT" "$DATABASE" "$DB_USER" "$DB_PASSWORD" "$USERNAME_LINUX"

HDBUSERSTORE_NAME+=("$HDBUSERSTORE_SYSTEMDB")


# Obtém o valor da variável DIR_INSTANCE
DIR_INSTANCE=$(su - $USERNAME_LINUX -c 'echo $DIR_INSTANCE')
DIR_INSTANCE=$(echo "$DIR_INSTANCE" | xargs) # Remove espaços em branco

# Obtém os diretórios de backup configuradas
DATA_BACKUP_PATH=$(execute_sql "SmartSafeOpusTech.SYSTEMDB" "SELECT VALUE FROM SYS.M_CONFIGURATION_PARAMETER_VALUES WHERE KEY = 'basepath_databackup' and VALUE IS NOT NULL limit 1" "$USERNAME_LINUX")

# Remove espaços em branco extras
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | xargs)

# Substitui $(DIR_INSTANCE) pelo valor real
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | sed "s|\$(DIR_INSTANCE)|$DIR_INSTANCE|g")

# Remove a parte final do caminho, se for /data, /log, /Dump/data ou /Dump/log
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | sed 's/\/\(data\|log\|Dump\/data\|Dump\/log\)\/\?$//')

# Adiciona a pasta "Empresas" ao final do data backup path na variavel schema_backup_path
SCHEMA_BACKUP_PATH="$DATA_BACKUP_PATH/Empresas"

# Comando SQL para listar bancos de dados
DATABASE_LIST=$(execute_sql "SmartSafeOpusTech.SYSTEMDB" "SELECT DATABASE_NAME FROM M_DATABASES WHERE DATABASE_NAME <> 'SYSTEMDB'" "$USERNAME_LINUX")
DATABASE_LIST=$(echo "$DATABASE_LIST" | tr -d ' ') # Remove todos os espaços

# Exibe os bancos de dados encontrados
echo
echo -e "${BLUE}Foram identificados os seguintes bancos além do SYSTEMDB:${NC}"
echo "$DATABASE_LIST"
echo
# Define um array para armazenar os nomes do hdbuserstore
HDBUSERSTORE_NAMES=()

# Validação para configurar os backups dos tenants *****************************************************************************************************************
dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --radiolist "Deseja configurar os backups dos tenants?\n(Nota: os dados da empresa ficam salvos dentro dos tenants)\n\nTenants encontrados: $DATABASE_LIST" 15 60 2 1 "Sim" off 2 "Não" on 2> /tmp/configure_tenants
CONFIGURE_TENANTS=$(cat /tmp/configure_tenants)
rm /tmp/configure_tenants

if [ "$CONFIGURE_TENANTS" = "1" ]; then
    # Solicita configuração do backup para cada banco de dados
    IFS=$'\n' read -rd '' -a DATABASE_ARRAY <<<"$DATABASE_LIST"
    for DATABASE in "${DATABASE_ARRAY[@]}"; do
        DATABASE=$(echo "$DATABASE" | xargs) # Remove espaços em branco
        dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --radiolist "Deseja configurar o backup do banco $DATABASE?" 10 50 2 1 "Sim" off 2 "Não" on 2> /tmp/configure
        CONFIGURE=$(cat /tmp/configure)
        rm /tmp/configure

        if [ "$CONFIGURE" = "1" ]; then
            # Form para credenciais do tenant
            exec 3>&1
            VALUES=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.1" --form "Credenciais para $DATABASE:" 15 50 0 \
                "Usuário:" 1 1 "SYSTEM" 1 20 30 0 \
                "Senha:" 2 1 "" 2 20 30 0 \
                2>&1 1>&3)
            exec 3>&-
            
            DB_USER_TENANT=$(echo "$VALUES" | sed -n '1p')
            DB_PASSWORD_TENANT=$(echo "$VALUES" | sed -n '2p')

            # Configura os hdbuserstores
            handle_hdbuserstore "SmartSafeOpusTech.$DATABASE" "$HOSTNAME" "$PORT" "$DATABASE" "$DB_USER_TENANT" "$DB_PASSWORD_TENANT" "$USERNAME_LINUX"

            # Verifica se o schema SBOCOMMON existe no banco
            check_sbo_query="SELECT 1 FROM SCHEMAS WHERE SCHEMA_NAME = 'SBOCOMMON';"
            result=$(execute_sql "SmartSafeOpusTech.$DATABASE" "$check_sbo_query" "$USERNAME_LINUX")

            if [[ -n "$result" ]]; then
                echo
                echo -e "${BLUE}Aparentemente este tenant roda um SAP Business One.${NC}"
                echo

                # Executa query para pegar os nomes das bases no SBOCOMMON.SRGC
                select_db_query="SELECT \"dbName\" FROM SBOCOMMON.SRGC;"
                db_names=$(execute_sql "SmartSafeOpusTech.$DATABASE" "$select_db_query" "$USERNAME_LINUX")
                # Limpar espaços e quebras de linha
                db_names_clean=$(echo "$db_names" | tr -d '\n' | tr -s ' ' | sed 's/^ *//;s/ *$//')
                echo
                echo -e "${BLUE}As seguintes empresas foram encontradas e serão exportadas:${NC}"
                echo "$db_names_clean" | tr ' ' '\n'
                echo

                # Usar todas as empresas encontradas
                eval "DATABASES_TO_BACKUP_$DATABASE=($db_names_clean)"
                echo "DB_NAMES_$DATABASE=\"$db_names_clean\""
            fi

             eval "echo As bases selecionadas para backup são: \${DATABASES_TO_BACKUP_$DATABASE[@]}"
        else
            echo -e "${BLUE}Configuração do backup para o banco $DATABASE foi pulada.${NC}"
        fi
    done
else
    echo -e "${BLUE}Configuração dos backups dos tenants foi pulada.${NC}"
fi


echo
echo -e "${BLUE}Hoje o seu banco está configurado para fazer backup de dados na seguinte diretório: $DATA_BACKUP_PATH${NC}"

# Adiciona uma linha em branco para clareza antes do prompt
echo