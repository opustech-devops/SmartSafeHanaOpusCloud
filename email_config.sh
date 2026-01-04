echo -e "${PURPLE}Gostaria de receber um email diariamente após a execução do backup? (s/n): ${NC}"
read -p "--->    " SEND_EMAIL
while [[ ! "$SEND_EMAIL" =~ ^[sSnN]$ ]]; do
    echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
    read -p "--->    " SEND_EMAIL
done

function configure_email {
    echo -e "${PURPLE}Informe os endereços de email para receber o relatório diário (separados por espaço): ${NC}"
    read -p "--->    " EMAIL_ADDRESS
    echo
    echo -e "${PURPLE}Informe o servidor SMTP para envio de email: ${NC}"
    read -p "--->    " SMTP_SERVER
    echo
    echo -e "${PURPLE}Informe a porta do servidor SMTP: ${NC}"
    read -p "--->    " SMTP_PORT
    echo
    echo -e "${PURPLE}Informe o usuario do email: ${NC}"
    read -p "--->    " EMAIL_USER
    echo
    echo -e "${PURPLE}Informe o remetente do email: ${NC}"
    read -p "--->    " EMAIL_REMETENTE
    echo
    echo -e "${PURPLE}Informe a senha do email: ${NC}"
    read -sp "--->    " EMAIL_PASSWORD
    echo
    # Teste de envio de email
    echo "Teste de configuração de email para backup do SAP HANA." | mailx -v -s "Teste de Email - Backup SAP HANA" \
    -S smtp="smtp://$SMTP_SERVER:$SMTP_PORT" \
    -S smtp-use-starttls \
    -S ssl-verify=ignore \
    -S smtp-auth=login \
    -S smtp-auth-user="$EMAIL_USER" \
    -S smtp-auth-password="$EMAIL_PASSWORD" \
    -S from="$EMAIL_REMETENTE" \
    "$EMAIL_ADDRESS"
}

if [[ "$SEND_EMAIL" =~ ^[sS]$ ]]; then
    echo
    while true; do
        configure_email

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Email de teste enviado com sucesso para $EMAIL_ADDRESS.${NC}"
            echo -e "${PURPLE}Você recebeu o email de teste? (s/n): ${NC}"
            read -p "--->    " EMAIL_RECEIVED
            while [[ ! "$EMAIL_RECEIVED" =~ ^[sSnN]$ ]]; do
                echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
                read -p "--->    " EMAIL_RECEIVED
            done

            if [[ "$EMAIL_RECEIVED" =~ ^[sS]$ ]]; then
                echo -e "${GREEN}Configuração de email concluída com sucesso.${NC}"
                break
            else
                echo -e "${RED}Por favor, verifique a pasta de spam e o log do servidor de email.${NC}"
                echo -e "${PURPLE}Deseja tentar configurar o email novamente? (s/n): ${NC}"
                read -p "--->    " RETRY_EMAIL
                while [[ ! "$RETRY_EMAIL" =~ ^[sSnN]$ ]]; do
                    echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
                    read -p "--->    " RETRY_EMAIL
                done

                if [[ "$RETRY_EMAIL" =~ ^[nN]$ ]]; then
                    echo -e "${BLUE}Continuando sem a configuração de email.${NC}"
                    break
                fi
            fi
        else
            echo -e "${RED}Falha ao enviar o email de teste.${NC}"
            echo -e "${PURPLE}Deseja tentar configurar o email novamente? (s/n): ${NC}"
            read -p "--->    " RETRY_EMAIL
            while [[ ! "$RETRY_EMAIL" =~ ^[sSnN]$ ]]; do
                echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
                read -p "--->    " RETRY_EMAIL
            done

            if [[ "$RETRY_EMAIL" =~ ^[nN]$ ]]; then
                echo -e "${BLUE}Continuando sem a configuração de email.${NC}"
                break
            fi
        fi
    done
    echo -e "${BLUE}Um email será enviado diariamente para $EMAIL_ADDRESS após a execução do backup.${NC}"
else
    echo
    echo -e "${BLUE}Você optou por não receber emails após a execução do backup.${NC}"
fi