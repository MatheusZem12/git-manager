# Git Manager

A local Git repository manager built with **Electron + Node.js**. A single process, with no REST API and no separate backend: the UI talks straight to your system's Git through Electron's main process.

## How it works

1. You register repositories that already exist on disk (folder selection; you can add several at once).
2. The dashboard shows the projects organized in **groups and subgroups** — drag repositories and groups to rearrange them — with search, stats and the status of each one (clean / with changes / unavailable).
3. When you select a project, you get tabs for: overview (branch, sync, push/pull/fetch), commit (stage/unstage with a colored diff), history (as a branch graph or a list), tags and stash. Each repository can also be renamed or removed straight from its card.

If you used the old version (Java + Flutter), the repositories registered in `~/.git-manager/repos.txt` are **migrated automatically** on the first run — nothing needs to be registered again.

## Requirements

- Node.js 18+
- npm 9+
- `git` installed and on the PATH (the app uses the system binary — it inherits your SSH setup, credentials and `~/.gitconfig` as usual)

## Project layout

- `source/` — all of the app code (Electron + Node.js)
- `README.md`, `start.sh`, `install-desktop.sh` — docs and scripts, at the root

```
source/
├── electron.js              # Main process entry point
├── preload.js                # Safe bridge between main and renderer
├── src/
│   ├── main/
│   │   ├── ipc-handlers.js   # Central registry of IPC handlers
│   │   ├── git/
│   │   │   └── git-service.js    # Every Git operation (via simple-git)
│   │   └── storage/
│   │       ├── project-store.js  # Persistence of registered projects
│   │       └── group-store.js    # Groups and subgroups (hierarchical)
│   └── renderer/
│       ├── index.html
│       ├── styles.css
│       ├── app.js
│       ├── screens/
│       │   ├── dashboard-screen.js       # Sidebar: list, search, nested groups, drag & drop
│       │   ├── project-detail-screen.js  # Tabs: overview, history (graph/list), tags, stash
│       │   └── staging-tab.js            # Commit tab: stage/unstage + diff
│       └── services/
│           ├── git-api.js    # Thin wrapper over window.gitManagerAPI
│           ├── dialogs.js    # Confirm/input dialogs
│           └── toast.js      # Notifications
```

## Running

```bash
cd source
npm install
npm start        # or ./start.sh (at the project root)
```

### Install as a desktop app (Linux)

To create a launcher in the applications menu, with an icon:

```bash
./install-desktop.sh              # installs/updates the launcher
./install-desktop.sh --uninstall  # removes it
```

## Features

- Register repositories (several at once), organize them in nested **groups and subgroups** with **drag and drop** to move repositories and groups, and search by name or path
- Rename and remove repositories straight from the card
- A dashboard with stats (total / OK / with changes / unavailable)
- Overview: current branch, HEAD, switch branch, new branch, push/pull/fetch with an output log
- Commit: stage/unstage one by one or in bulk, a colored unified diff (added/removed lines), a full-file view, commit of the staged files
- Branch history in two views: a **commit graph** (colored lanes showing branches and merges) or a list
- Tags: create (annotated if it has a message, lightweight if not) and delete
- Stash: save, apply, pop, list

### Out of scope for this version

To keep the rewrite lean, these were left out (they can be added later if missed):

- A merge/PR-like screen (merge preview, squash, assisted conflict resolution)
- An SSH setup wizard (push/pull/fetch work normally with the SSH setup already on your system)
- Internationalization (English only)

## Persistence

Registered projects live in a JSON file in the user data folder (Electron's `userData`) — not in `~/.git-manager/repos.txt` (that file is read only once, for the migration, and never touched again).

## Technical notes

- Git operations use the [`simple-git`](https://www.npmjs.com/package/simple-git) library, which runs the system `git` binary — SSH, credentials and global settings work exactly as on the command line.
- Branch deletion is safe by default (it refuses unmerged branches); force-delete exists in the service layer but has no dedicated UI yet.
