# Git Manager

Gerenciador local de repositórios Git com **Electron + Node.js**. Um único processo, sem API REST, sem backend separado: a UI fala direto com o Git do seu sistema através do módulo principal do Electron.

## Como funciona

1. Você cadastra repositórios já existentes no disco (seleção de pastas, pode adicionar várias de uma vez).
2. O dashboard mostra todos os projetos agrupados, com busca, estatísticas e status (limpo / com alterações / indisponível) de cada um.
3. Ao selecionar um projeto, você tem abas para: visão geral (branch, sync, push/pull/fetch), commit (stage/unstage com diff colorido), histórico, tags e stash.

Se você já usava a versão antiga (Java + Flutter), seus repositórios cadastrados em `~/.git-manager/repos.txt` são **migrados automaticamente** na primeira execução — nada precisa ser recadastrado.

## Requisitos

- Node.js 18+
- npm 9+
- `git` instalado e no PATH (o app usa o binário do sistema — herda sua configuração de SSH, credenciais e `~/.gitconfig` normalmente)

## Estrutura do projeto

- `source/` — todo o código do app (Electron + Node.js)
- `README.md`, `start.sh` — documentação e script, na raiz

```
source/
├── electron.js              # Entry point do processo principal
├── preload.js                # Ponte segura entre main e renderer
├── src/
│   ├── main/
│   │   ├── ipc-handlers.js   # Registro central dos handlers IPC
│   │   ├── git/
│   │   │   └── git-service.js    # Todas as operações Git (via simple-git)
│   │   └── storage/
│   │       └── project-store.js  # Persistência dos projetos cadastrados
│   └── renderer/
│       ├── index.html
│       ├── styles.css
│       ├── app.js
│       ├── screens/
│       │   ├── dashboard-screen.js       # Sidebar: lista, busca, grupos
│       │   ├── project-detail-screen.js  # Abas: visão geral, histórico, tags, stash
│       │   └── staging-tab.js            # Aba de commit: stage/unstage + diff
│       └── services/
│           ├── git-api.js    # Wrapper fino sobre window.gitManagerAPI
│           ├── dialogs.js    # Diálogos de confirmação/input
│           └── toast.js      # Notificações
```

## Como executar

```bash
cd source
npm install
npm start        # ou ./start.sh (na raiz do projeto)
```

## Funcionalidades

- Cadastro de repositórios (múltiplos de uma vez), agrupamento livre, busca por nome ou caminho
- Dashboard com estatísticas (total / OK / com alterações / indisponível)
- Visão geral: branch atual, HEAD, troca de branch, nova branch, push/pull/fetch com log de saída
- Commit: stage/unstage individual ou em lote, diff unificado colorido (linhas adicionadas/removidas), visualização do arquivo completo, commit dos arquivos staged
- Histórico simples de commits da branch atual
- Tags: criar (anotada se tiver mensagem, leve se não) e excluir
- Stash: salvar, aplicar, pop, listar

### Fora do escopo desta versão

Para manter a reescrita enxuta, ficaram de fora (podem ser adicionados depois, se fizerem falta):

- Timeline gráfica com branches coloridas (o histórico existe, mas como lista simples)
- Tela de merge/PR-like (merge preview, squash, resolução de conflitos assistida)
- Wizard de configuração de SSH (o push/pull/fetch funciona normalmente usando a configuração de SSH já existente no seu sistema)
- Internacionalização (só português)

## Persistência

Os projetos cadastrados ficam em um JSON na pasta de dados do usuário (`userData` do Electron) — não em `~/.git-manager/repos.txt` (esse arquivo só é lido uma vez, para migração, e nunca mais é tocado).

## Notas técnicas

- Operações Git usam a lib [`simple-git`](https://www.npmjs.com/package/simple-git), que executa o binário `git` do sistema — SSH, credenciais e configurações globais funcionam exatamente como na linha de comando.
- Delete de branch é seguro por padrão (recusa branches não mescladas); force-delete existe na camada de serviço mas não tem UI dedicada ainda.
