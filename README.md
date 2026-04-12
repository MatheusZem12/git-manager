# Git Manager

Gerenciador de repositórios Git com interface gráfica, multi-usuário e multi-PC.

## Tecnologias

- **Java 17** + **JavaFX 21** (GUI)
- **JGit** (operações Git programáticas)
- **PostgreSQL** (banco de dados)
- **HikariCP** (pool de conexões)
- **BCrypt** (hash de senhas)
- **Maven** (build)

## Pré-requisitos

- Java 17+
- Maven 3.8+
- PostgreSQL 14+ rodando localmente

## Configuração do banco

1. Crie o banco de dados:
```sql
CREATE DATABASE gitmanager;
```

2. Ajuste `src/main/resources/application.properties` com suas credenciais:
```properties
db.url=jdbc:postgresql://localhost:5432/gitmanager
db.username=postgres
db.password=sua_senha
```

O schema (tabelas, índices, triggers) é criado automaticamente na primeira execução.

## Executar

```bash
mvn javafx:run
```

Ou gerar o JAR e executar:
```bash
mvn package
java --module-path target/git-manager-1.0.0.jar -m com.gitmanager/com.gitmanager.App
```

## Funcionalidades

### Autenticação
- Cadastro com username, email e senha (mínimo 6 caracteres)
- Login via username ou email
- Senhas armazenadas com BCrypt

### Gerenciamento de projetos
- Adicionar repositórios Git via seletor de diretório
- Validação automática de `.git` antes de salvar
- Nomear/renomear projetos com alias personalizado
- Adicionar notas/observações por projeto
- Excluir projetos da conta

### Validação multi-PC
Ao fazer login, o sistema verifica **para cada projeto cadastrado**:
1. Se o diretório existe **neste** computador
2. Se o diretório contém um `.git` válido
3. Se a URL do remote `origin` é coerente com a cadastrada no banco

Somente projetos válidos neste PC aparecem como disponíveis. Os demais são listados com alerta visual.

### Indicador de status (lista lateral)
- 🟢 Verde — disponível e coerente
- 🟡 Amarelo — remote divergente (mesmo path, outro remote)
- 🟠 Laranja — diretório existe mas sem `.git`
- 🔴 Vermelho — diretório não encontrado neste PC

### Operações Git (via JGit)
- **Commit** — com opção de `git add -A` automático, nome/email do autor
- **Push** — com suporte a credenciais (usuário/senha ou token)
- **Pull** — com merge automático
- **Fetch** — atualiza referências remotas
- **Checkout** — trocar de branch com seletor
- **Nova branch** — criar e mudar para nova branch
- **Histórico** — últimos 20 commits do repositório

## Estrutura do projeto

```
src/main/java/com/gitmanager/
├── App.java                        # Ponto de entrada JavaFX
├── model/
│   ├── User.java                   # Entidade usuário
│   └── GitProject.java             # Entidade projeto Git
├── dao/
│   ├── UserDao.java                # CRUD de usuários
│   └── GitProjectDao.java          # CRUD de projetos
├── service/
│   ├── AuthService.java            # Login/registro
│   ├── GitService.java             # Operações JGit
│   └── ProjectService.java         # Lógica de negócio
├── util/
│   ├── DatabaseConfig.java         # Pool HikariCP
│   └── SchemaInitializer.java      # Init do schema SQL
└── ui/
    ├── login/
    │   ├── LoginScreen.java
    │   └── RegisterDialog.java
    ├── dashboard/
    │   ├── DashboardScreen.java
    │   └── ProjectListCell.java
    └── dialog/
        ├── AddEditProjectDialog.java
        └── GitOperationsPanel.java
```
