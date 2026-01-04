#!/usr/bin/env python3
"""
SmartSafeHanaOpusCloud - Backup automation for SAP HANA
Optimized and Object-Oriented version in Python
"""

import os
import sys
import subprocess
import re
import tempfile
import shutil
from typing import List, Optional, Dict, Any

class Colors:
    RED = "\033[1;31m"
    GREEN = "\033[1;32m"
    BLUE = "\033[1;34m"
    CYAN = "\033[1;36m"
    YELLOW = "\033[1;33m"
    PURPLE = "\033[1;35m"
    WHITE = "\033[1;37m"
    NC = "\033[0m"  # Reset

class ErrorHandler:
    @staticmethod
    def error_exit(message: str) -> None:
        print(f"\n{Colors.RED}[ERRO] {message}{Colors.NC}")
        print(f"\n{Colors.PURPLE}Deseja reiniciar o script? (s/n){Colors.NC}")
        response = input("--->    ").strip().lower()
        if response == 's':
            print(f"\n{Colors.GREEN}Reiniciando o script...{Colors.NC}")
            os.execv(sys.executable, [sys.executable] + sys.argv)
        else:
            print(f"\n{Colors.GREEN}Encerrando o script.{Colors.NC}")
            sys.exit(1)

class Validator:
    @staticmethod
    def validate_instance_number(instance_number: str) -> None:
        if not re.match(r'^\d{2}$', instance_number):
            ErrorHandler.error_exit("Número da instância deve ter exatamente dois dígitos numéricos entre 00 e 99.")

    @staticmethod
    def validate_instance_name(instance_name: str) -> None:
        if not re.match(r'^[a-zA-Z0-9]{3}$', instance_name):
            ErrorHandler.error_exit("Nome da instância deve ter exatamente três caracteres alfanuméricos.")

    @staticmethod
    def validate_email(email: str) -> None:
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_regex, email):
            ErrorHandler.error_exit("Endereço de email inválido. Por favor, forneça um endereço de email válido.")

class DatabaseConnection:
    def __init__(self, host: str, port: str, database: str, user: str, password: str, linux_user: str):
        self.host = host
        self.port = port
        self.database = database
        self.user = user
        self.password = password
        self.linux_user = linux_user
        self.hdbuserstore_name = f"SmartSafeOpusTech.{database}"

    def setup_hdbuserstore(self) -> bool:
        command = f"su - {self.linux_user} -c 'hdbuserstore SET \"{self.hdbuserstore_name}\" {self.host}:{self.port}@{self.database} {self.user} \"{self.password}\"'"
        print(f"Executando: su - {self.linux_user} -c 'hdbuserstore SET \"{self.hdbuserstore_name}\" {self.host}:{self.port}@{self.database} {self.user} [PASSWORD]'")
        try:
            subprocess.run(command, shell=True, check=True, capture_output=True)
            print(f"{Colors.GREEN}hdbuserstore configurado com sucesso para {self.hdbuserstore_name}.{Colors.NC}")
            return self.validate_connection()
        except subprocess.CalledProcessError:
            print(f"\n{Colors.RED}Erro ao executar hdbuserstore para {self.hdbuserstore_name}. Verifique os dados fornecidos.{Colors.NC}")
            return False

    def validate_connection(self) -> bool:
        print(f"\n{Colors.BLUE}Validando a senha para {self.hdbuserstore_name}...{Colors.NC}")
        query = "SELECT 1 FROM DUMMY;"
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as sql_file, \
             tempfile.NamedTemporaryFile(delete=False) as output_file:
            sql_file.write(query)
            sql_file_path = sql_file.name
            output_file_path = output_file.name

        os.chmod(sql_file_path, 0o777)
        os.chmod(output_file_path, 0o777)

        command = f"su - {self.linux_user} -c 'hdbsql -U \"{self.hdbuserstore_name}\" -I \"{sql_file_path}\" -o \"{output_file_path}\"'"
        try:
            subprocess.run(command, shell=True, check=True, capture_output=True)
            with open(output_file_path, 'r') as f:
                content = f.read()
            if 'authentication failed' in content.lower() or 'error' in content.lower():
                print(f"\n{Colors.RED}Falha na validação da senha para {self.hdbuserstore_name}. Por favor, insira as credenciais novamente.{Colors.NC}")
                return False
            print(f"\n{Colors.GREEN}Senha validada com sucesso para {self.hdbuserstore_name}.{Colors.NC}")
            return True
        except subprocess.CalledProcessError:
            print(f"\n{Colors.RED}Falha na validação da senha para {self.hdbuserstore_name}. Por favor, insira as credenciais novamente.{Colors.NC}")
            return False
        finally:
            os.unlink(sql_file_path)
            os.unlink(output_file_path)

    def execute_query(self, sql_query: str) -> str:
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as sql_file, \
             tempfile.NamedTemporaryFile(delete=False) as output_file:
            sql_file.write(sql_query)
            sql_file_path = sql_file.name
            output_file_path = output_file.name

        os.chmod(sql_file_path, 0o777)
        os.chmod(output_file_path, 0o777)

        command = f"su - {self.linux_user} -c 'hdbsql -U \"{self.hdbuserstore_name}\" -x -A -F \" \" -a -m -I \"{sql_file_path}\" -o \"{output_file_path}\"'"
        try:
            subprocess.run(command, shell=True, check=True)
            with open(output_file_path, 'r') as f:
                result = f.read().strip()
            if 'error' in result.lower():
                ErrorHandler.error_exit(f"Erro detectado na execução do SQL. Detalhes: {result}")
            return result
        except subprocess.CalledProcessError:
            ErrorHandler.error_exit("Falha ao executar o comando SQL. Verifique o comando e os logs.")
        finally:
            os.unlink(sql_file_path)
            os.unlink(output_file_path)

class BackupConfigurator:
    def __init__(self):
        self.hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        self.instance_name = self._get_instance_name()
        self.instance_number = self._get_instance_number()
        self.database = "SYSTEMDB"
        self.port = f"3{self.instance_number}13"
        self.connections: Dict[str, DatabaseConnection] = {}

    def _get_instance_name(self) -> str:
        try:
            result = subprocess.run("ls -d /hana/shared/*/ | grep -oP '(?<=/hana/shared/)[A-Z]{3}(?=/)'", shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        except:
            return "HDB"

    def _get_instance_number(self) -> str:
        try:
            result = subprocess.run("ls -d /hana/shared/" + self.instance_name + "/HDB*/ | grep -oP '(?<=HDB)[0-9]{2}'", shell=True, capture_output=True, text=True)
            return result.stdout.strip()
        except:
            return "00"

    def configure_systemdb(self) -> None:
        print(f"{Colors.PURPLE}Você concorda com os termos acima e deseja continuar?{Colors.NC}")
        print()
        print(f"{Colors.GREEN}[s] Sim{Colors.NC} | {Colors.RED}[n] Não{Colors.NC}")
        response = input("--->    ").strip().lower()
        if response != 's':
            print(f"{Colors.RED}Você optou por não concordar. O script será encerrado.{Colors.NC}")
            sys.exit(1)

        Validator.validate_instance_name(self.instance_name)
        Validator.validate_instance_number(self.instance_number)

        print(f"\n{Colors.BLUE}Identificamos automaticamente os seguintes dados nesse servidor.{Colors.NC}")
        print()
        print(f"{Colors.BLUE}Hostname                {Colors.GREEN}{self.hostname}{Colors.NC}")
        print(f"{Colors.BLUE}Nome da instância       {Colors.GREEN}{self.instance_name}{Colors.NC}")
        print(f"{Colors.BLUE}Número da instância     {Colors.GREEN}{self.instance_number}{Colors.NC}")
        print()
        print(f"{Colors.PURPLE}Deseja usar esses valores? (s/n):{Colors.NC}")
        print()
        print(f"{Colors.GREEN}[s] Sim{Colors.NC} | {Colors.RED}[n] Não{Colors.NC}")
        use_predefined = input("--->    ").strip().lower()
        if use_predefined == 'n':
            self.hostname = input(f"{Colors.PURPLE}Informe o hostname do servidor [default: {self.hostname}]: {Colors.NC}").strip() or self.hostname
            self.instance_number = input(f"{Colors.PURPLE}Informe o número da instância [default: {self.instance_number}]: {Colors.NC}").strip() or self.instance_number
            Validator.validate_instance_number(self.instance_number)
            self.port = f"3{self.instance_number}13"
            self.instance_name = input(f"{Colors.PURPLE}Informe o nome da instância [default: {self.instance_name}]: {Colors.NC}").strip() or self.instance_name
            Validator.validate_instance_name(self.instance_name)

        # Request password
        db_user = input(f"{Colors.PURPLE}Informe o usuário do {self.database} [default: SYSTEM]: {Colors.NC}").strip() or "SYSTEM"
        db_password = input(f"{Colors.PURPLE}Informe a senha do {self.database}: {Colors.NC}")
        linux_user = f"{self.instance_name.lower()}adm"

        systemdb_conn = DatabaseConnection(self.hostname, self.port, self.database, db_user, db_password, linux_user)
        while not systemdb_conn.setup_hdbuserstore():
            db_user = input(f"{Colors.PURPLE}Informe o usuário do {self.database} [default: SYSTEM]: {Colors.NC}").strip() or "SYSTEM"
            db_password = input(f"{Colors.PURPLE}Informe a senha do {self.database}: {Colors.NC}")
            systemdb_conn = DatabaseConnection(self.hostname, self.port, self.database, db_user, db_password, linux_user)

        self.connections[self.database] = systemdb_conn

    def get_backup_paths(self) -> None:
        query = "SELECT VALUE FROM SYS.M_CONFIGURATION_PARAMETER_VALUES WHERE KEY = 'basepath_databackup' and VALUE IS NOT NULL limit 1"
        data_backup_path = self.connections[self.database].execute_query(query).strip()
        data_backup_path = data_backup_path.replace('$(DIR_INSTANCE)', self._get_dir_instance())
        data_backup_path = re.sub(r'/data/?|/log/?|/Dump/data/?|/Dump/log/?', '', data_backup_path)
        self.schema_backup_path = f"{data_backup_path}/Empresas"
        self.base_path = data_backup_path

    def _get_dir_instance(self) -> str:
        command = f"su - {self.connections[self.database].linux_user} -c 'echo $DIR_INSTANCE'"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip()

    def list_databases(self) -> List[str]:
        query = "SELECT DATABASE_NAME FROM M_DATABASES WHERE DATABASE_NAME <> 'SYSTEMDB'"
        result = self.connections[self.database].execute_query(query)
        return [db.strip() for db in result.split() if db.strip()]

    def configure_tenants(self, databases: List[str]) -> None:
        print(f"\n{Colors.BLUE}Foram identificados os seguintes bancos além do SYSTEMDB:{Colors.NC}")
        print(" ".join(databases))
        print()
        print(f"{Colors.PURPLE}Deseja configurar os backups dos tenants? (s/n) [Nota: os dados da empresa ficam salvos dentro dos tenants]: {Colors.NC}")
        configure = input("--->    ").strip().lower()
        if configure != 's':
            print(f"{Colors.BLUE}Configuração dos backups dos tenants foi pulada.{Colors.NC}")
            return

        for db in databases:
            print(f"\n{Colors.BLUE}Processando banco de dados: {db}{Colors.NC}")
            hdbuserstore_name = f"SmartSafeOpusTech.{db}"
            print()
            configure_db = input(f"{Colors.PURPLE}Deseja configurar o backup do banco {db}? (s/n): {Colors.NC}").strip().lower()
            if configure_db != 's':
                print(f"{Colors.BLUE}Configuração do backup para o banco {db} foi pulada.{Colors.NC}")
                continue

            # Request password for tenant
            db_user = input(f"{Colors.PURPLE}Informe o usuário do {db} [default: SYSTEM]: {Colors.NC}").strip() or "SYSTEM"
            db_password = input(f"{Colors.PURPLE}Informe a senha do {db}: {Colors.NC}")
            tenant_conn = DatabaseConnection(self.hostname, self.port, db, db_user, db_password, self.connections[self.database].linux_user)
            while not tenant_conn.setup_hdbuserstore():
                db_user = input(f"{Colors.PURPLE}Informe o usuário do {db} [default: SYSTEM]: {Colors.NC}").strip() or "SYSTEM"
                db_password = input(f"{Colors.PURPLE}Informe a senha do {db}: {Colors.NC}")
                tenant_conn = DatabaseConnection(self.hostname, self.port, db, db_user, db_password, self.connections[self.database].linux_user)

            self.connections[db] = tenant_conn

            # Check for SBOCOMMON
            check_query = "SELECT 1 FROM SCHEMAS WHERE SCHEMA_NAME = 'SBOCOMMON';"
            result = tenant_conn.execute_query(check_query)
            if result:
                print(f"\n{Colors.BLUE}Aparentemente este tenant roda um SAP Business One.{Colors.NC}")
                select_query = "SELECT \"dbName\" FROM SBOCOMMON.SRGC;"
                db_names = tenant_conn.execute_query(select_query)
                print(f"\n{Colors.BLUE}As seguintes empresas foram encontradas e serão exportadas:{Colors.NC}")
                print(db_names)
                # Store for later use

def main():
    # Display banner
    print(f"{Colors.PURPLE}           .--.    ")
    print("        .-(    ).  ")
    print(f"{Colors.WHITE}       (___.__)__) {Colors.NC}  {Colors.PURPLE}  OPUS {Colors.WHITE}CLOUD {Colors.NC}")
    print(f"{Colors.PURPLE}      {Colors.NC}")
    print(f"{Colors.CYAN}============================================================================={Colors.NC}")
    print(f"{Colors.BLUE}                         ----- Seja Bem-Vindo! -----                         {Colors.NC}")
    print(f"{Colors.CYAN}============================================================================={Colors.NC}")
    print(f"{Colors.GREEN} Este é o assistente para backup de SAP HANA da OpusTech.{Colors.NC}")
    # ... (rest of banner)

    configurator = BackupConfigurator()
    configurator.configure_systemdb()
    configurator.get_backup_paths()
    databases = configurator.list_databases()
    configurator.configure_tenants(databases)

    print(f"\n{Colors.BLUE}Hoje o seu banco está configurado para fazer backup de dados na seguinte diretório: {configurator.base_path}{Colors.NC}")

if __name__ == "__main__":
    main()