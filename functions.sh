# Função para exibir uma mensagem de erro e sair
function error_exit {
    local message=$1
    echo
    echo -e "${RED}[ERRO]$message${NC}"
    echo
    echo -e "${PURPLE}Deseja reiniciar o script? (s/n)${NC}"
    read -p "--->    " -r resposta

    if [[ "$resposta" =~ ^[Ss]$ ]]; then
    echo
        echo -e "${GREEN}Reiniciando o script...${NC}"
        exec "$0" "$@"
    else
    echo
        echo -e "${GREEN}Encerrando o script.${NC}"
        exit 1
    fi
}

# Função para validar o número da instância
function validate_instance_number {
    if [[ ! "$INSTANCE_NUMBER" =~ ^[0-9]{2}$ ]]; then
        error_exit "Número da instância deve ter exatamente dois dígitos numéricos entre 00 e 99."
    fi
}

# Função para validar o nome da instância
function validate_instance_name {
    if [[ ! "$INSTANCE_NAME" =~ ^[a-zA-Z0-9]{3}$ ]]; then
        error_exit "Nome da instância deve ter exatamente três caracteres alfanuméricos."
    fi
}

# Função para validar o formato do endereço de email
function validate_email {
    local email=$1
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if [[ ! $email =~ $regex ]]; then
        error_exit "Endereço de email inválido. Por favor, forneça um endereço de email válido."
    fi
}

# Função para configurar ou atualizar o hdbuserstore e validar a senha
function handle_hdbuserstore {

    while true; do
        # Monta o comando do hdbuserstore
        echo
        local hdbuserstore_command="su - $USERNAME_LINUX -c 'hdbuserstore SET "$HDBUSERSTORE_NAME" $HOSTNAME:$PORT@$DATABASE $DB_USER $DB_PASSWORD'"
        #echo "su - $USERNAME_LINUX -c 'hdbuserstore SET "$HDBUSERSTORE_NAME" $HOSTNAME:$PORT@$DATABASE $DB_USER $DB_PASSWORD'"

        # Executa o comando para criar ou atualizar o hdbuserstore
        eval $hdbuserstore_command > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo
            echo -e "${RED}Erro ao executar hdbuserstore para $HDBUSERSTORE_NAME. Verifique os dados fornecidos.${NC}"
            echo
            continue
        fi
        echo -e "${GREEN}hdbuserstore $action executado com sucesso para $HDBUSERSTORE_NAME.${NC}"

        # Validação da senha
        echo
        echo -e "${BLUE}Validando a senha para $HDBUSERSTORE_NAME...${NC}"
        local validation_query="SELECT 1 FROM DUMMY;"
        local sql_file=$(mktemp)
        local output_file=$(mktemp)
        echo "$validation_query" > "$sql_file"
        chmod 777 "$sql_file" "$output_file"
        local validation_command="su - $USERNAME_LINUX -c 'hdbsql -U $HDBUSERSTORE_NAME -I $sql_file -o $output_file'"
        eval $validation_command > /dev/null 2>&1

        # Verifica se a validação falhou
        if [[ $? -ne 0 || ! -s "$output_file" || $(grep -c "authentication failed" "$output_file") -gt 0 ]]; then
            echo
            echo -e "${RED}Falha na validação da senha para $HDBUSERSTORE_NAME. Por favor, insira as credenciais novamente.${NC}"
            echo
            rm -f "$sql_file" "$output_file"
            request_password
            continue
        fi
        echo
        echo -e "${GREEN}Senha validada com sucesso para $HDBUSERSTORE_NAME.${NC}"
        rm -f "$sql_file" "$output_file"
        break
    done
}

# Função para solicitar e validar a senha
function request_password {
    while true; do
        # Solicita usuário do SYSTEMDB ****************************************************************************************************************
        echo -e "${PURPLE}Informe o usuário do $DATABASE [default: SYSTEM]: ${NC}"
        read -p "--->    " SYSTEMDB_USER
        DB_USER=${DB_USER:-SYSTEM}
        echo
        USERNAME_LINUX=$(echo "${INSTANCE_NAME,,}adm")
        # Solicita a senha do SYSTEMDB ****************************************************************************************************************
        echo -e "${PURPLE}Informe a senha do $DATABASE: ${NC}"
        read -sp "--->    " DB_PASSWORD
        echo # Para quebrar a linha após a senha

        # Verifica se a senha está em branco
        if [[ -z "$DB_PASSWORD" ]]; then
            echo -e "${RED}Erro: A senha não pode estar em branco. Por favor, forneça uma senha válida.${NC}"
        else
            # Se a senha não estiver em branco, sai do loop
            break
        fi
    done
}

# Função para executar uma consulta SQL e retornar o resultado
function execute_sql {
    local hdbuserstore=$1
    local sql_query=$2
    SQL_FILE=$(mktemp) || error_exit "Não foi possível criar um arquivo temporário para o SQL."
    OUTPUT_FILE=$(mktemp) || error_exit "Não foi possível criar um arquivo temporário para a saída."

    # Grava a consulta SQL no arquivo temporário
    echo "$sql_query" > "$SQL_FILE"
    HDBUSERSTORE_NAME=$hdbuserstore
    chmod 777 "$SQL_FILE" "$OUTPUT_FILE"  || error_exit "Falha ao configurar permissões nos arquivos temporários."

    # Executa o comando SQL com hdbsql
    HDBSQL_COMMAND="su - $USERNAME_LINUX -c 'hdbsql -U \"$HDBUSERSTORE_NAME\" -x -A -F \" \" -a -m -I \"$SQL_FILE\" -o \"$OUTPUT_FILE\"'"
    eval $HDBSQL_COMMAND || error_exit "Falha ao executar o comando SQL. Verifique o comando e os logs."

    # Verifica se há mensagens de erro no arquivo de saída
    if grep -qi "error" "$OUTPUT_FILE"; then
        error_exit "Erro detectado na execução do SQL. \nDetalhes: $(<"$OUTPUT_FILE")"
    fi

    # Lê o resultado do arquivo e limpa os arquivos temporários
    local result=$(<"$OUTPUT_FILE")
    rm -f "$SQL_FILE" "$OUTPUT_FILE" || error_exit "Falha ao limpar os arquivos temporários."

    # Retorna o resultado
    echo "$result"
}