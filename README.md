# SmartSafeHanaOpusCloud - Refatorado

Este projeto foi refatorado em módulos para melhor organização e manutenção.

## Estrutura dos Arquivos

- `main.sh`: Script principal que inclui todos os módulos e executa o fluxo completo.
- `constants.sh`: Definições de constantes, como cores ANSI.
- `functions.sh`: Todas as funções utilitárias (error_exit, validate_instance_number, etc.).
- `banner.sh`: Exibição do banner e disclaimer.
- `config_logic.sh`: Lógica principal de configuração (coleta de dados, validações, configurações de backup).
- `path_config.sh`: Configuração de caminhos e diretórios de backup.
- `copy_config.sh`: Configuração de cópia para localização secundária.
- `email_config.sh`: Configuração de notificações por email.
- `scheduled_gen.sh`: Geração do script agendado e configuração do crontab.

## Como Usar

Execute o script principal:

```bash
bash SmartSafeHanaOpusCloud_configure.sh
```

Ou diretamente na pasta:

```bash
cd /root/SmartSafeHanaOpusCloud/
bash main.sh
```

## Funcionalidades

- Configuração automática de backups SAP HANA
- Export de schemas (especialmente para SAP Business One)
- Agendamento automático via crontab
- Envio de relatórios por email
- Cópia para localizações secundárias
- Limpeza automática de backups antigos

## Desenvolvimento

Para modificar o código, edite os arquivos individuais conforme necessário. O `main.sh` inclui todos os módulos na ordem correta.
