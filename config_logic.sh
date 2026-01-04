# Coleta valores predefinidos
HOSTNAME=$(hostname)
INSTANCE_NAME=$(ls -d /hana/shared/*/ | grep -oP '(?<=/hana/shared/)[A-Z]{3}(?=/)')
INSTANCE_NUMBER=$(ls -d /hana/shared/"$INSTANCE_NAME"/HDB*/ | grep -oP '(?<=HDB)[0-9]{2}')
DATABASE=SYSTEMDB

# Cria ou atualiza a entrada do hdbuserstore para o SYSTEMDB
HDBUSERSTORE_NAME="SmartSafeOpusTech.$DATABASE"

# Solicitação de confirmação ****************************************************************************************************************
echo -e "${PURPLE}Você concorda com os termos acima e deseja continuar?${NC}"
echo
echo -e "${GREEN}[s] Sim${NC} | ${RED}[n] Não${NC}"
echo
read -p "--->    " user_choice
echo
if [[ "$user_choice" =~ ^[sS]$ ]]; then
    echo -e "${GREEN}Iniciando SmartSafeHanaOpusCloud: ${NC}"
    # Continue o script
    sleep 0
else
    echo -e "${RED}Você optou por não concordar. O script será encerrado.${NC}"
    exit 1
fi

# Valida os valores coletados
validate_instance_name
validate_instance_number
echo
echo -e "${BLUE}Identificamos automaticamente os seguintes dados nesse servidor.${NC}"
echo
echo -e "${BLUE}Hostname                ${GREEN}$HOSTNAME${NC}"
echo -e "${BLUE}Nome da instância       ${GREEN}$INSTANCE_NAME${NC}"
echo -e "${BLUE}Número da instância     ${GREEN}$INSTANCE_NUMBER${NC}"
echo
echo -e "${PURPLE}Deseja usar esses valores? (s/n):${NC}"
echo
echo -e "${GREEN}[s] Sim${NC} | ${RED}[n] Não${NC}"
echo
# Solicita confirmação do usuário para os valores coletados *******************************************************************************************************
read -p "--->    " USE_PREDEFINED
while [[ ! "$USE_PREDEFINED" =~ ^[sSnN]$ ]]; do
    echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
    read -p "--->    " USE_PREDEFINED
done
echo
if [[ "$USE_PREDEFINED" =~ ^[nN]$ ]]; then
    echo -e "${PURPLE}Informe o hostname do servidor [default: $HOSTNAME]: ${NC}"
    read -p "--->    " HOSTNAME
    HOSTNAME=${HOSTNAME:-$(hostname)}

    echo -e "${PURPLE}Informe o número da instância [default: $INSTANCE_NUMBER]: ${NC}"
    read -p "--->    " INSTANCE_NUMBER
    INSTANCE_NUMBER=${INSTANCE_NUMBER:-00}
    validate_instance_number

    PORT="3${INSTANCE_NUMBER}13"

    echo -e "${PURPLE}Informe o nome da instância [default: $INSTANCE_NAME]: ${NC}"
    read -p "--->    " INSTANCE_NAME
    INSTANCE_NAME=${INSTANCE_NAME:-HDB}
    validate_instance_name
else
    PORT="3${INSTANCE_NUMBER}13"
fi

# Chama a função para garantir que a senha seja válida
request_password

# Configura os hdbuserstores
handle_hdbuserstore

HDBUSERSTORE_NAME+=("$HDBUSERSTORE_SYSTEMDB")


# Obtém o valor da variável DIR_INSTANCE
DIR_INSTANCE=$(su - $USERNAME_LINUX -c 'echo $DIR_INSTANCE')
DIR_INSTANCE=$(echo "$DIR_INSTANCE" | xargs) # Remove espaços em branco

# Obtém os diretórios de backup configuradas
DATA_BACKUP_PATH=$(execute_sql "SmartSafeOpusTech.SYSTEMDB" "SELECT VALUE FROM SYS.M_CONFIGURATION_PARAMETER_VALUES WHERE KEY = 'basepath_databackup' and VALUE IS NOT NULL limit 1")

# Remove espaços em branco extras
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | xargs)

# Substitui $(DIR_INSTANCE) pelo valor real
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | sed "s|\$(DIR_INSTANCE)|$DIR_INSTANCE|g")

# Remove a parte final do caminho, se for /data, /log, /Dump/data ou /Dump/log
DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | sed 's/\/\(data\|log\|Dump\/data\|Dump\/log\)\/\?$//')

# Adiciona a pasta "Empresas" ao final do data backup path na variavel schema_backup_path
SCHEMA_BACKUP_PATH="$DATA_BACKUP_PATH/Empresas"

# Comando SQL para listar bancos de dados
DATABASE_LIST=$(execute_sql "SmartSafeOpusTech.SYSTEMDB" "SELECT DATABASE_NAME FROM M_DATABASES WHERE DATABASE_NAME <> 'SYSTEMDB'")
DATABASE_LIST=$(echo "$DATABASE_LIST" | tr -d ' ') # Remove todos os espaços

# Exibe os bancos de dados encontrados
echo
echo -e "${BLUE}Foram identificados os seguintes bancos além do SYSTEMDB:${NC}"
echo "$DATABASE_LIST"
echo
# Define um array para armazenar os nomes do hdbuserstore
HDBUSERSTORE_NAMES=()

# Validação para configurar os backups dos tenants *****************************************************************************************************************
echo -e "${PURPLE}Deseja configurar os backups dos tenants? (s/n) [Nota: os dados da empresa ficam salvos dentro dos tenants]: ${NC}"
read -p "--->    " CONFIGURE_TENANTS
while [[ ! "$CONFIGURE_TENANTS" =~ ^[sSnN]$ ]]; do
    echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
    read -p "--->    " CONFIGURE_TENANTS
done

if [[ "$CONFIGURE_TENANTS" =~ ^[sS]$ ]]; then
    # Solicita configuração do backup para cada banco de dados
    IFS=$'\n' read -rd '' -a DATABASE_ARRAY <<<"$DATABASE_LIST"
    for DATABASE in "${DATABASE_ARRAY[@]}"; do
        DATABASE=$(echo "$DATABASE" | xargs) # Remove espaços em branco
        echo
        echo -e "${BLUE}Processando banco de dados: $DATABASE${NC}"
        HDBUSERSTORE_NAME="SmartSafeOpusTech.$DATABASE"
        echo

        CONFIGURE="s"
        while [[ ! "$CONFIGURE" =~ ^[sSnN]$ ]]; do
            echo -e "${PURPLE}Deseja configurar o backup do banco $DATABASE? (s/n): ${NC}"
            read -p "--->    " CONFIGURE
        done
        echo

        if [[ "$CONFIGURE" =~ ^[sS]$ ]]; then
            # Chama a função para garantir que a senha seja válida
            request_password

            # Configura os hdbuserstores
            handle_hdbuserstore

            # Verifica se o schema SBOCOMMON existe no banco
            check_sbo_query="SELECT 1 FROM SCHEMAS WHERE SCHEMA_NAME = 'SBOCOMMON';"
            result=$(execute_sql "SmartSafeOpusTech.$DATABASE" "$check_sbo_query")

            if [[ -n "$result" ]]; then
                echo
                echo -e "${BLUE}Aparentemente este tenant roda um SAP Business One.${NC}"
                echo

                # Executa query para pegar os nomes das bases no SBOCOMMON.SRGC
                select_db_query="SELECT \"dbName\" FROM SBOCOMMON.SRGC;"
                db_names=$(execute_sql "SmartSafeOpusTech.$DATABASE" "$select_db_query")
                echo
                echo -e "${BLUE}As seguintes empresas foram encontradas e serão exportadas:${NC}"
                echo "$db_names"
                echo

                # Usar todas as empresas encontradas
                eval "DATABASES_TO_BACKUP_$DATABASE=($db_names)"
                echo "DB_NAMES_$DATABASE=\"$db_names\""
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