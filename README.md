# Git Manager

Gerenciador local de repositórios Git com **Electron + Node.js**. Um único processo, sem API REST, sem backend separado: a UI fala direto com o Git do seu sistema através do módulo principal do Electron.

## Como funciona

1. Você cadastra repositórios já existentes no disco (seleção de pastas, pode adicionar várias de uma vez).
2. O dashboard mostra os projetos organizados em **grupos e subgrupos** — arraste repositórios e grupos para reorganizar — com busca, estatísticas e status (limpo / com alterações / indisponível) de cada um.
3. Ao selecionar um projeto, você tem abas para: visão geral (branch, sync, push/pull/fetch), commit (stage/unstage com diff colorido), histórico (em gráfico de branches ou lista), tags e stash. Cada repositório também pode ser renomeado ou removido direto pelo cartão.

Se você já usava a versão antiga (Java + Flutter), seus repositórios cadastrados em `~/.git-manager/repos.txt` são **migrados automaticamente** na primeira execução — nada precisa ser recadastrado.

## Requisitos

- Node.js 18+
- npm 9+
- `git` instalado e no PATH (o app usa o binário do sistema — herda sua configuração de SSH, credenciais e `~/.gitconfig` normalmente)

## Estrutura do projeto

- `source/` — todo o código do app (Electron + Node.js)
- `README.md`, `start.sh`, `install-desktop.sh` — documentação e scripts, na raiz

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
│   │       ├── project-store.js  # Persistência dos projetos cadastrados
│   │       └── group-store.js    # Grupos e subgrupos (hierárquicos)
│   └── renderer/
│       ├── index.html
│       ├── styles.css
│       ├── app.js
│       ├── screens/
│       │   ├── dashboard-screen.js       # Sidebar: lista, busca, grupos aninhados, drag & drop
│       │   ├── project-detail-screen.js  # Abas: visão geral, histórico (gráfico/lista), tags, stash
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

### Instalar como app do desktop (Linux)

Para criar um atalho no menu de aplicativos, com ícone:

```bash
./install-desktop.sh              # instala/atualiza o atalho
./install-desktop.sh --uninstall  # remove
```

## Funcionalidades

- Cadastro de repositórios (múltiplos de uma vez), organização em **grupos e subgrupos** (aninhados) com **arrastar-e-soltar** para mover repositórios e grupos, e busca por nome ou caminho
- Renomear e remover repositórios direto pelo cartão
- Dashboard com estatísticas (total / OK / com alterações / indisponível)
- Visão geral: branch atual, HEAD, troca de branch, nova branch, push/pull/fetch com log de saída
- Commit: stage/unstage individual ou em lote, diff unificado colorido (linhas adicionadas/removidas), visualização do arquivo completo, commit dos arquivos staged
- Histórico da branch em duas visões: **gráfico de commits** (lanes coloridas mostrando branches e merges) ou lista
- Tags: criar (anotada se tiver mensagem, leve se não) e excluir
- Stash: salvar, aplicar, pop, listar

### Fora do escopo desta versão

Para manter a reescrita enxuta, ficaram de fora (podem ser adicionados depois, se fizerem falta):

- Tela de merge/PR-like (merge preview, squash, resolução de conflitos assistida)
- Wizard de configuração de SSH (o push/pull/fetch funciona normalmente usando a configuração de SSH já existente no seu sistema)
- Internacionalização (só português)

## Persistência

Os projetos cadastrados ficam em um JSON na pasta de dados do usuário (`userData` do Electron) — não em `~/.git-manager/repos.txt` (esse arquivo só é lido uma vez, para migração, e nunca mais é tocado).

## Notas técnicas

- Operações Git usam a lib [`simple-git`](https://www.npmjs.com/package/simple-git), que executa o binário `git` do sistema — SSH, credenciais e configurações globais funcionam exatamente como na linha de comando.
- Delete de branch é seguro por padrão (recusa branches não mescladas); force-delete existe na camada de serviço mas não tem UI dedicada ainda.
