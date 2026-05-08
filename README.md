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

## Gerar instalador .exe (Windows)

O projeto usa o `jpackage` (ferramenta do JDK) para criar um instalador `.exe` nativo para Windows.

### Opção 1: GitHub Actions (recomendado)

A cada push na branch `DEV` ou `main`, o workflow [`.github/workflows/build-windows.yml`](.github/workflows/build-windows.yml) executa automaticamente no Windows e gera o instalador como artefato para download.

**Como baixar:**
1. Vá na aba **Actions** do repositório no GitHub
2. Clique no workflow mais recente
3. Baixe o artefato `git-manager-windows-installer`

### Opção 2: Build local no Windows

1. Instale o JDK 17 com JavaFX incluso (recomendado: [BellSoft Liberica JDK Full](https://bell-sw.com/pages/downloads/#/java-17-lts))
2. Clone o repositório
3. Execute:

```bash
mvn clean package -Pwindows
```

O instalador `.exe` será gerado em:

```
target/dist/GitManager-1.0.0.exe
```

> **Nota:** o `jpackage` no Windows pode exigir o [WiX Toolset v3](https://wixtoolset.org/docs/v3/) instalado para gerar o `.exe`.

### Opção 3: Outras plataformas (Linux/Mac)

Para gerar um instalador nativo no Linux ou Mac:

```bash
mvn clean package -Pjpackage
```

O tipo de instalador depende do SO:
- **Linux:** `.deb` ou `.rpm`
- **Mac:** `.dmg` ou `.pkg`

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
