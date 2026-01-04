dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --yesno "\Zb\Z4Você deseja que esse backup seja copiado para outro local?" 8 60
COPY_TO_ANOTHER_LOCATION=$?

if [ $COPY_TO_ANOTHER_LOCATION -eq 0 ]; then
    COPY_PATH=$(dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --inputbox "Informe o caminho para copiar o backup:" 10 50 2>&1)
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --msgbox "\Zb\Z4O backup será copiado diariamente para o diretório $COPY_PATH.\n\Z1Aviso: Certifique-se de que o caminho de cópia tenha espaço suficiente para os backups." 8 60
else
    dialog --backtitle "SmartSafeHanaOpusCloud v2.2 - Opus Cloud" --colors --msgbox "\Zb\Z4O backup não será copiado para outro local." 6 50
fi