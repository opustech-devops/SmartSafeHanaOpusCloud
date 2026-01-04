echo
COPY_TO_ANOTHER_LOCATION=""
echo -e "${PURPLE}Você deseja que esse backup seja copiado para outro local? (s/n): ${NC}"
read -p "--->    " COPY_TO_ANOTHER_LOCATION
while [[ ! "$COPY_TO_ANOTHER_LOCATION" =~ ^[sSnN]$ ]]; do
    echo -e "${PURPLE}Por favor, responda com 's' ou 'n': ${NC}"
    read -p "--->    " COPY_TO_ANOTHER_LOCATION
done

if [[ "$COPY_TO_ANOTHER_LOCATION" =~ ^[sS]$ ]]; then
    echo
    echo -e "${PURPLE}Informe o caminho para copiar o backup: ${NC}"
    read -p "--->    " COPY_PATH
    echo
    echo -e "${BLUE}O backup será copiado diariamente para o diretório $COPY_PATH.${NC}"
    echo -e "${RED}Aviso: Certifique-se de que o caminho de cópia tenha espaço suficiente para os backups.${NC}"
else
    echo
    echo -e "${BLUE}O backup não será copiado para outro local.${NC}"
fi