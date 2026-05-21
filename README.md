# Git Manager

Gerenciador local de repositórios Git com interface gráfica moderna em **Flutter Desktop** e backend **Java REST**.

## Tecnologias

- **Flutter 3.27** — Interface desktop moderna (Material 3, dark theme, animações)
- **Dart** — Cliente HTTP consumindo API REST
- **Java 17** — Backend e regra de negócio
- **Javalin 6** — Servidor REST embutido
- **JGit** — Operações Git programáticas
- **Jackson** — Serialização JSON
- **Maven** — Build do backend Java

## Arquitetura

```
┌─────────────────────┐      HTTP REST       ┌─────────────────────┐
│   Flutter Desktop   │ ◄──────────────────► │   Java Backend      │
│   (UI Moderna)      │   localhost:18765    │   (Regra de Negócio)│
└─────────────────────┘                      └─────────────────────┘
```

O **Java** continua como regra de negócio (GitService, ProjectService, models).  
O **Flutter** substituiu a UI JavaFX antiga, consumindo operações via API REST local.

## Pré-requisitos

- Java 17+
- Maven 3.8+
- Flutter 3.27+ (com Linux desktop enabled)

## Executar

### Opção rápida (script automático)

```bash
./start.sh
```

O script `start.sh` compila tudo automaticamente, inicia o backend Java e depois o app Flutter.

### Manualmente

**1. Compile o backend Java:**

```bash
mvn package -DskipTests
```

**2. Compile o app Flutter (Linux):**

```bash
cd git_manager_ui
flutter build linux --debug
```

**3. Inicie o backend:**

```bash
java -cp target/git-manager-1.0.0.jar com.gitmanager.ApiMain
```

**4. Em outro terminal, inicie o Flutter:**

```bash
./git_manager_ui/build/linux/x64/debug/bundle/git_manager_ui
```

## Funcionalidades

### Interface Flutter Moderna
- **Tema escuro premium** — inspirado em Linear/GitHub Dark, com glassmorphism, cards elevados e sombras
- **Dashboard** — lista de repositórios em cards com indicadores de status, busca em tempo real e estatísticas
- **Detalhes do projeto** — abas para Visão Geral, Histórico, Tags e Stash
- **Staging visual** — lista de arquivos alterados com checkboxes, preview de diff e commit integrado
- **Timeline gráfica** — visualização de commits com branches coloridas e conexões
- **Animações** — transições suaves, hover effects e glow nos elementos

### Operações Git (via JGit no backend)
- **Commit** — selecionar arquivos e mensagem
- **Push / Pull / Fetch** — com suporte a credenciais
- **Checkout / Nova branch**
- **Tags** — criar e listar
- **Stash** — save, pop, apply
- **Histórico** — lista e gráfico de commits

## API REST Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/health` | Health check |
| GET | `/api/projects` | Listar projetos |
| POST | `/api/projects` | Adicionar projeto |
| PUT | `/api/projects` | Atualizar projeto |
| DELETE | `/api/projects` | Remover projeto |
| GET | `/api/git/status` | Status do repo |
| GET | `/api/git/branches` | Listar branches |
| GET | `/api/git/commits` | Commits recentes |
| GET | `/api/git/graph` | Grafo de commits |
| GET | `/api/git/changes` | Arquivos alterados |
| POST | `/api/git/commit` | Fazer commit |
| POST | `/api/git/push` | Push |
| POST | `/api/git/pull` | Pull |
| POST | `/api/git/fetch` | Fetch |
| POST | `/api/git/checkout` | Checkout |
| POST | `/api/git/create-branch` | Nova branch |
| POST | `/api/git/create-tag` | Nova tag |
| POST | `/api/git/stash-*` | Operações stash |

## Estrutura do projeto

```
├── pom.xml                          # Build Maven (Java backend)
├── start.sh                         # Launcher automático
├── src/main/java/com/gitmanager/
│   ├── ApiMain.java                 # Entry point do servidor REST
│   ├── api/
│   │   └── RestServer.java          # API Javalin (endpoints REST)
│   ├── model/                       # Entidades (GitProject, GitCommit, etc.)
│   ├── service/                     # Regra de negócio (GitService, ProjectService)
│   └── ui/                          # UI antiga JavaFX (mantida para compatibilidade)
│
└── git_manager_ui/                  # Projeto Flutter Desktop
    ├── lib/
    │   ├── main.dart                # Entry point Flutter
    │   ├── theme.dart               # Tema escuro moderno
    │   ├── models/                  # Modelos Dart
    │   ├── services/
    │   │   └── api_service.dart     # Cliente HTTP para Java REST
    │   ├── screens/
    │   │   ├── dashboard_screen.dart
    │   │   ├── project_detail_screen.dart
    │   │   ├── staging_screen.dart
    │   │   └── timeline_screen.dart
    │   └── widgets/                 # Componentes reutilizáveis
    └── linux/                       # Build Linux desktop
```

## Persistência

Os diretórios cadastrados são salvos em:

```
~/.git-manager/repos.txt
```

Formato: `nome|caminho|notas`

## Notas

- O backend REST roda na porta **18765** (localhost apenas).
- O Flutter se comunica com o Java via HTTP — não há dependência direta de código.
- A UI JavaFX antiga ainda está presente em `src/main/java/com/gitmanager/ui/` mas não é mais usada como entry point principal.
