# Git Manager

Gerenciador local de repositórios Git com interface gráfica.

## Tecnologias

- **Java 17** + **JavaFX 21** (GUI)
- **JGit** (operações Git programáticas)
- **Maven** (build)

## Pré-requisitos

- Java 17+
- Maven 3.8+

## Executar

```bash
mvn javafx:run
```

Ou gerar o JAR e executar:

```bash
mvn package
java -jar target/git-manager-1.0.0.jar
```

## Funcionalidades

### Gerenciamento de repositórios
- Adicionar repositórios Git via seletor de diretório
- Validação automática de `.git` antes de salvar e ao visualizar
- Nomear projetos com alias personalizado
- Adicionar notas/observações por projeto
- Remover projetos da lista (apaga a entrada local, não o diretório)

### Indicador de status (lista lateral)
- 🟢 Verde — diretório existe e contém repositório git válido
- 🟠 Laranja — diretório existe mas sem `.git`
- 🔴 Vermelho — diretório não encontrado

### Operações Git (via JGit)
- **Commit** — com opção de `git add -A` automático, nome/email do autor
- **Push** — com suporte a credenciais (usuário/senha ou token)
- **Pull** — com merge automático
- **Fetch** — atualiza referências remotas
- **Checkout** — trocar de branch com seletor
- **Nova branch** — criar e mudar para nova branch
- **Histórico** — últimos 20 commits do repositório

## Persistência

Os diretórios cadastrados são salvos em um arquivo texto simples:

```
~/.git-manager/repos.txt
```

Formato: `nome|caminho|notas`

Não há banco de dados, login ou qualquer dependência externa.

## Estrutura do projeto

```
src/main/java/com/gitmanager/
├── App.java                        # Ponto de entrada JavaFX
├── model/
│   └── GitProject.java             # Entidade projeto Git
├── repository/
│   └── GitProjectFileRepository.java  # Persistência em arquivo txt
├── service/
│   ├── GitService.java             # Operações JGit
│   └── ProjectService.java         # Lógica de negócio
└── ui/
    ├── dashboard/
    │   ├── DashboardScreen.java    # Tela principal
    │   └── ProjectListCell.java    # Célula customizada da lista
    └── dialog/
        ├── AddEditProjectDialog.java  # Adicionar/editar repo
        └── GitOperationsPanel.java    # Painel de operações git
```
