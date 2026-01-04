# Instalação rápida do SmartSafeHanaOpusCloud

Execute este comando no seu servidor Linux:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/opustech-devops/SmartSafeHanaOpusCloud/main/install.sh)
```

Isso irá:
- Baixar e instalar o projeto em `/opt/smartsafehana`
- Criar o comando global `smartsafehana`
- Instalar dependências mínimas (mailutils, git)

Depois, basta rodar:

```bash
smartsafehana
```

Ou, se preferir:

```bash
bash /opt/smartsafehana/main.sh
```

---

> Para personalizações, consulte os arquivos no diretório `/opt/smartsafehana`.
> 
> Requer permissões de sudo para instalar dependências e criar links globais.
