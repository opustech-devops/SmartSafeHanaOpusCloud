# Função para exibir uma mensagem de erro e sair
function error_exit {
    local error_message=$1
    echo
    echo -e "${RED}[ERRO] $error_message${NC}"
    echo
    echo -e "${PURPLE}Deseja reiniciar o script? (s/n)${NC}"
    read -p "--->    " user_response

    if [[ "$user_response" =~ ^[Ss]$ ]]; then
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
    local instance_num=$1
    if [[ ! "$instance_num" =~ ^[0-9]{2}$ ]]; then
        error_exit "Número da instância deve ter exatamente dois dígitos numéricos entre 00 e 99."
    fi
}

# Função para validar o nome da instância
function validate_instance_name {
    local instance_name=$1
    if [[ ! "$instance_name" =~ ^[a-zA-Z0-9]{3}$ ]]; then
        error_exit "Nome da instância deve ter exatamente três caracteres alfanuméricos."
    fi
}

# Função para validar o formato do endereço de email
function validate_email {
    local email_address=$1
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if [[ ! "$email_address" =~ $email_regex ]]; then
        error_exit "Endereço de email inválido. Por favor, forneça um endereço de email válido."
    fi
}

# Função para configurar ou atualizar o hdbuserstore e validar a senha
function handle_hdbuserstore {
    local hdbuserstore_name=$1
    local db_host=$2
    local db_port=$3
    local db_name=$4
    local db_user=$5
    local db_password=$6
    local linux_user=$7

    while true; do
        # Monta o comando do hdbuserstore
        echo
        local hdbuserstore_command="su - $linux_user -c 'hdbuserstore SET \"$hdbuserstore_name\" $db_host:$db_port@$db_name $db_user \"$db_password\"'"
        echo "Executando: su - $linux_user -c 'hdbuserstore SET \"$hdbuserstore_name\" $db_host:$db_port@$db_name $db_user [PASSWORD]'"

        # Executa o comando para criar ou atualizar o hdbuserstore
        if ! eval "$hdbuserstore_command" > /dev/null 2>&1; then
            echo
            echo -e "${RED}Erro ao executar hdbuserstore para $hdbuserstore_name. Verifique os dados fornecidos.${NC}"
            echo
            continue
        fi
        echo -e "${GREEN}hdbuserstore configurado com sucesso para $hdbuserstore_name.${NC}"

        # Validação da senha
        echo
        echo -e "${BLUE}Validando a senha para $hdbuserstore_name...${NC}"
        local validation_query="SELECT 1 FROM DUMMY;"
        local sql_file=$(mktemp)
        local output_file=$(mktemp)
        echo "$validation_query" > "$sql_file"
        chmod 777 "$sql_file" "$output_file"
        local validation_command="su - $linux_user -c 'hdbsql -U \"$hdbuserstore_name\" -I \"$sql_file\" -o \"$output_file\"'"
        if ! eval "$validation_command" > /dev/null 2>&1; then
            echo
            echo -e "${RED}Falha na validação da senha para $hdbuserstore_name. Por favor, insira as credenciais novamente.${NC}"
            echo
            rm -f "$sql_file" "$output_file"
            return 1  # Indica falha para solicitar nova senha
        fi

        # Verifica se há erro no output
        if grep -qi "authentication failed\|error" "$output_file"; then
            echo
            echo -e "${RED}Falha na validação da senha para $hdbuserstore_name. Por favor, insira as credenciais novamente.${NC}"
            echo
            rm -f "$sql_file" "$output_file"
            return 1
        fi

        echo
        echo -e "${GREEN}Senha validada com sucesso para $hdbuserstore_name.${NC}"
        rm -f "$sql_file" "$output_file"
        return 0
    done
}

# Função para solicitar e validar a senha
function request_password {
    local db_name=$1
    local instance_name=$2
    while true; do
        # Solicita usuário do banco
        echo -e "${PURPLE}Informe o usuário do $db_name [default: SYSTEM]: ${NC}"
        read -p "--->    " db_user
        db_user=${db_user:-SYSTEM}
        echo
        local linux_user=$(echo "${instance_name,,}adm")
        # Solicita a senha
        echo -e "${PURPLE}Informe a senha do $db_name: ${NC}"
        read -sp "--->    " db_password
        echo # Para quebrar a linha após a senha

        # Verifica se a senha está em branco
        if [[ -z "$db_password" ]]; then
            echo -e "${RED}Erro: A senha não pode estar em branco. Por favor, forneça uma senha válida.${NC}"
        else
            # Retornar valores via variáveis globais ou echo
            DB_USER=$db_user
            DB_PASSWORD=$db_password
            USERNAME_LINUX=$linux_user
            break
        fi
    done
}

# Função para executar uma consulta SQL e retornar o resultado
function execute_sql {
    local hdbuserstore=$1
    local sql_query=$2
    local linux_user=$3
    local sql_file=$(mktemp) || error_exit "Não foi possível criar um arquivo temporário para o SQL."
    local output_file=$(mktemp) || error_exit "Não foi possível criar um arquivo temporário para a saída."

    # Grava a consulta SQL no arquivo temporário
    echo "$sql_query" > "$sql_file"
    chmod 777 "$sql_file" "$output_file" || error_exit "Falha ao configurar permissões nos arquivos temporários."

    # Executa o comando SQL com hdbsql
    local hdbsql_command="su - $linux_user -c 'hdbsql -U \"$hdbuserstore\" -x -A -F \" \" -a -m -I \"$sql_file\" -o \"$output_file\"'"
    if ! eval "$hdbsql_command"; then
        error_exit "Falha ao executar o comando SQL. Verifique o comando e os logs."
    fi

    # Verifica se há mensagens de erro no arquivo de saída
    if grep -qi "error" "$output_file"; then
        error_exit "Erro detectado na execução do SQL. Detalhes: $(<"$output_file")"
    fi

    # Lê o resultado do arquivo e limpa os arquivos temporários
    local result=$(<"$output_file")
    rm -f "$sql_file" "$output_file" || error_exit "Falha ao limpar os arquivos temporários."

    # Retorna o resultado
    echo "$result"
}