BASE_PATH=""
while true; do
    echo -e "${PURPLE}Deseja usar esse mesmo diretório para o backup? (s/n): ${NC}"
    read -p "--->    " USE_SAME_PATHS
    echo
    while [[ ! "$USE_SAME_PATHS" =~ ^[sSnN]$ ]]; do
        echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
        read -p "--->    " USE_SAME_PATHS
    done

    if [[ "$USE_SAME_PATHS" =~ ^[sS]$ ]]; then
        BASE_PATH=$DATA_BACKUP_PATH
        break  # Sai do loop principal, pois a confirmação foi positiva
    else
        echo
        echo -e "${PURPLE}Informe o caminho base para o backup de dados: ${NC}"
        read -p "--->    " BASE_PATH
        DATA_BACKUP_PATH="$BASE_PATH/Dump"
        # Exibição do aviso sobre a alteração do destino do backup
        echo -e "${CYAN}=============================================================================${NC}"
        echo -e "${BLUE}                          ----- Aviso Importante -----                        ${NC}"
        echo -e "${CYAN}=============================================================================${NC}"
        echo -e "${RED} ⚠️  ATENÇÃO: ${NC} Você está prestes a alterar o destino do backup no servidor."
        echo -e "${RED} Essa alteração atualizará as configurações para usar o novo caminho informado.${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
        echo -e "${YELLOW} Certifique-se de que o novo caminho possui espaço suficiente para os backups.${NC}"
        echo -e "${YELLOW} Backups de dados e logs exigem armazenamento adequado para evitar falhas.${NC}"
        echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
        echo -e "${GREEN} Caso tenha dúvidas, recomendamos manter o caminho atual para maior segurança.${NC}"
        echo -e "${CYAN}=============================================================================${NC}"
        echo

        # Solicita confirmação do usuário para continuar com a alteração
        echo -e "${PURPLE}Você confirma que deseja continuar? (s/n): ${NC}"
        read -p "--->    " CONFIRMATION
        while [[ ! "$CONFIRMATION" =~ ^[sSnN]$ ]]; do
            echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
            read -p "--->    " CONFIRMATION
        done
        echo

        if [[ "$CONFIRMATION" =~ ^[sS]$ ]]; then
            # Verifica se o diretório BASE_PATH existe
            if [ ! -d "$BASE_PATH" ]; then
                echo -e "${BLUE}Criando o diretório $BASE_PATH...${NC}"
                mkdir -p "$BASE_PATH" && echo -e "${GREEN}Diretório $BASE_PATH criado com sucesso.${NC}" || error_exit "Erro ao criar o diretório $BASE_PATH. Verifique as permissões."
                chmod -R 777 "$BASE_PATH" && echo -e "${GREEN}Permissões do diretório $BASE_PATH ajustadas com sucesso.${NC}" || error_exit "Erro ao alterar as permissões do diretório $BASE_PATH."
            else
                echo -e "${BLUE}O diretório $BASE_PATH já existe.${NC}"
            fi

            # Verifica se o diretório DATA_BACKUP_PATH existe
            if [ ! -d "$DATA_BACKUP_PATH" ]; then
                echo -e "${BLUE}Criando o diretório $DATA_BACKUP_PATH...${NC}"
                mkdir -p "$DATA_BACKUP_PATH" && echo -e "${GREEN}Diretório $DATA_BACKUP_PATH criado com sucesso.${NC}" || error_exit "Erro ao criar o diretório $DATA_BACKUP_PATH. Verifique as permissões."
                chmod -R 777 "$DATA_BACKUP_PATH" && echo -e "${GREEN}Permissões do diretório $DATA_BACKUP_PATH ajustadas com sucesso.${NC}" || error_exit "Erro ao alterar as permissões do diretório $DATA_BACKUP_PATH."
            else
                echo -e "${BLUE}O diretório $DATA_BACKUP_PATH já existe.${NC}"
            fi

            # Verifica se o diretório SCHEMA_BACKUP_PATH existe
            if [ ! -d "$SCHEMA_BACKUP_PATH" ]; then
                echo -e "${BLUE}Criando o diretório $SCHEMA_BACKUP_PATH...${NC}"
                mkdir -p "$SCHEMA_BACKUP_PATH" && echo -e "${GREEN}Diretório $SCHEMA_BACKUP_PATH criado com sucesso.${NC}" || error_exit "Erro ao criar o diretório $SCHEMA_BACKUP_PATH. Verifique as permissões."
                chmod -R 777 "$SCHEMA_BACKUP_PATH" && echo -e "${GREEN}Permissões do diretório $SCHEMA_BACKUP_PATH ajustadas com sucesso.${NC}" || error_exit "Erro ao alterar as permissões do diretório $SCHEMA_BACKUP_PATH."
            else
                echo -e "${BLUE}O diretório $SCHEMA_BACKUP_PATH já existe.${NC}"
            fi

            AVAILABLE_SPACE=$(df --block-size=1G "$BASE_PATH" | awk 'NR==2 {print $4}')
            AVAILABLE_SPACE=${AVAILABLE_SPACE%G} # Remove a letra G

            # Exibe um alerta se o espaço disponível for menor que 100 GB
            if [ "$AVAILABLE_SPACE" -lt 100 ]; then
                echo -e "${RED}----------------------${NC}"
                echo -e "${RED}Aviso: A unidade onde o diretório $BASE_PATH está armazenado tem menos de 100 GB de espaço disponível."
                echo -e "Isso pode ser insuficiente para os backups.${NC}"
                echo -e "${RED}----------------------${NC}"
            fi
            # Obtém os diretórios de backup configuradas
            # Remove barras duplicadas do caminho
            DATA_BACKUP_PATH=$(echo "$DATA_BACKUP_PATH" | sed 's|//|/|g')

            execute_sql "SmartSafeOpusTech.SYSTEMDB" "ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'basepath_databackup') = '$DATA_BACKUP_PATH/data' WITH RECONFIGURE;"
            execute_sql "SmartSafeOpusTech.SYSTEMDB" "ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'basepath_logbackup') = '$DATA_BACKUP_PATH/log' WITH RECONFIGURE;"
            break  # Sai do loop principal após todas as verificações e criação do diretório
        else
            echo -e "${BLUE}Alteração do destino do backup cancelada. Vamos tentar novamente.${NC}"
        fi
    fi
done