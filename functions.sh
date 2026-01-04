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

    # Monta o comando do hdbuserstore
    local hdbuserstore_command="su - $linux_user -c '/hana/shared/NDB/hdbclient/hdbuserstore SET \"$hdbuserstore_name\" $db_host:$db_port@$db_name $db_user \"$db_password\"'"

    log "Montando comando hdbuserstore para $hdbuserstore_name: $hdbuserstore_command"

    # Mostra mensagem de waiting
    clear
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --infobox "Configurando hdbuserstore para $hdbuserstore_name..." 3 50

    log "Executando comando hdbuserstore para $hdbuserstore_name"

    # Executa o comando para criar ou atualizar o hdbuserstore
    error_output=$(eval "$hdbuserstore_command" 2>&1)
    if [ $? -ne 0 ]; then
        clear
        dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "X Erro ao executar hdbuserstore para $hdbuserstore_name.\nErro: $error_output" 8 80
        return 1
    fi

    # Validação da senha
    clear
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --infobox "Validando a senha para $hdbuserstore_name..." 5 50
    local validation_query="SELECT 1 FROM DUMMY;"
    local sql_file=$(mktemp)
    local output_file=$(mktemp)
    echo "$validation_query" > "$sql_file"
    chmod 777 "$sql_file" "$output_file"
    local validation_command="su - $linux_user -c '/hana/shared/NDB/hdbclient/hdbsql -U \"$hdbuserstore_name\" -I \"$sql_file\" -o \"$output_file\"'"
    validation_error=$(eval "$validation_command" 2>&1)
    if [ $? -ne 0 ]; then
        clear
        dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "X Falha na validação da senha para $hdbuserstore_name.\nErro: $validation_error" 10 80
        rm -f "$sql_file" "$output_file"
        return 1  # Indica falha para solicitar nova senha
    fi

    # Verifica se há erro no output
    if grep -qi "authentication failed\|error" "$output_file"; then
        output_content=$(cat "$output_file")
        clear
        dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "X Falha na validação da senha para $hdbuserstore_name.\nConteúdo do output: $output_content" 10 80
        rm -f "$sql_file" "$output_file"
        return 1
    fi

    clear
    log "Configuração e validação concluídas com sucesso para $hdbuserstore_name"
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --msgbox "Configuração e validação concluídas com sucesso para $hdbuserstore_name." 6 60
    rm -f "$sql_file" "$output_file"
    return 0
}

# Função para solicitar e validar a senha
function request_password {
    local db_name=$1
    local instance_name=$2
    while true; do
        # Solicita usuário do banco
        db_user=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.0" --inputbox "Informe o usuário do $db_name" 10 50 "SYSTEM" 2>&1)
        echo
        local linux_user=$(echo "${instance_name,,}adm")
        # Solicita a senha
        db_password=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.0" --passwordbox "Informe a senha do $db_name" 10 50 2>&1)
        echo

        # Verifica se a senha está em branco
        if [[ -z "$db_password" ]]; then
            dialog --backtitle "SmartSafeHanaOpusCloud v2.0" --msgbox "Erro: A senha não pode estar em branco. Por favor, forneça uma senha válida." 10 50
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
    local hdbsql_command="su - $linux_user -c 'hdbsql -q -U \"$hdbuserstore\" -x -A -F \" \" -a -m -I \"$sql_file\" -o \"$output_file\"'"
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