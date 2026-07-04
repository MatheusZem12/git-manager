const { app, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const gitService = require('./git/git-service');
const { createProjectStore } = require('./storage/project-store');
const { createGroupStore } = require('./storage/group-store');

const projectStore = createProjectStore(path.join(app.getPath('userData'), 'projects.json'));
const groupStore = createGroupStore(path.join(app.getPath('userData'), 'groups.json'));

async function listValidatedProjects() {
  const projects = projectStore.load();
  return Promise.all(projects.map((p) => gitService.validateProject(p)));
}

// Converte o antigo campo `group` (string plana) de projetos existentes em
// grupos de topo no novo modelo hierárquico, atribuindo `groupId`. Roda uma
// única vez: projetos que já têm `groupId` são ignorados.
function migrateLegacyGroups() {
  const projects = projectStore.load();
  const pending = projects.filter((p) => !p.groupId && p.group && p.group.trim());
  if (pending.length === 0) return;

  const existing = groupStore.load();
  const topLevelByName = new Map(existing.filter((g) => !g.parentId).map((g) => [g.name, g.id]));

  for (const p of pending) {
    const name = p.group.trim();
    let groupId = topLevelByName.get(name);
    if (!groupId) {
      groupId = groupStore.add({ name, parentId: null }).id;
      topLevelByName.set(name, groupId);
    }
    projectStore.update(p.path, { groupId });
  }
}

function registerIpcHandlers() {
  try {
    migrateLegacyGroups();
  } catch (err) {
    console.error('Falha ao migrar grupos legados:', err);
  }

  ipcMain.handle('groups-list', () => groupStore.load());
  ipcMain.handle('groups-add', (_event, { name, parentId }) => groupStore.add({ name, parentId }));
  ipcMain.handle('groups-rename', (_event, { id, name }) => groupStore.rename(id, name));
  ipcMain.handle('groups-reparent', (_event, { id, parentId }) => groupStore.reparent(id, parentId));
  ipcMain.handle('groups-remove', (_event, id) => {
    const { reparentTo } = groupStore.remove(id);
    projectStore.reassignGroup(id, reparentTo || '');
    return { reparentTo: reparentTo || '' };
  });

  ipcMain.handle('projects-list', () => listValidatedProjects());

  ipcMain.handle('projects-add', async (_event, { name, path: repoPath, group, groupId, notes }) => {
    if (!repoPath) throw new Error('Nenhum diretório informado.');
    if (!(await gitService.isValidGitRepo(repoPath))) {
      throw new Error('O diretório selecionado não contém um repositório Git válido (.git).');
    }
    const finalName = name && name.trim() ? name.trim() : path.basename(repoPath);
    const project = projectStore.add({ name: finalName, path: repoPath, group, groupId, notes });
    return gitService.validateProject(project);
  });

  ipcMain.handle('projects-update', (_event, { path: repoPath, updates }) => {
    return projectStore.update(repoPath, updates);
  });

  ipcMain.handle('project-check', (_event, repoPath) => gitService.validateProject({ path: repoPath }));

  ipcMain.handle('projects-remove', (_event, repoPath) => {
    projectStore.remove(repoPath);
  });

  ipcMain.handle('select-directories', async () => {
    const result = await dialog.showOpenDialog({ properties: ['openDirectory', 'multiSelections'] });
    if (result.canceled) return { repos: [], rejected: [] };

    // Para cada pasta escolhida, resolve os repos Git que ela representa (a
    // própria pasta se for um repo, ou os repos nos subdiretórios imediatos).
    // Só repositórios Git válidos são retornados; o resto vira "rejected" pra
    // avisar o usuário. Isso garante multi-seleção confiável e validação.
    const repos = [];
    const rejected = [];
    for (const selected of result.filePaths) {
      const found = await gitService.findGitReposUnder(selected);
      if (found.length === 0) {
        rejected.push(selected);
      } else {
        for (const repo of found) {
          if (!repos.includes(repo)) repos.push(repo);
        }
      }
    }
    return { repos, rejected };
  });

  ipcMain.handle('open-path', (_event, targetPath) => shell.openPath(targetPath));

  ipcMain.handle('git-status', (_event, repoPath) => gitService.getStatus(repoPath));
  ipcMain.handle('git-sync-status', (_event, repoPath) => gitService.getSyncStatus(repoPath));
  ipcMain.handle('git-branches', (_event, repoPath) => gitService.getBranches(repoPath));
  ipcMain.handle('git-commits', (_event, { path: repoPath, limit }) => gitService.getCommits(repoPath, limit));
  ipcMain.handle('git-changes', (_event, repoPath) => gitService.getFileChanges(repoPath));

  ipcMain.handle('git-tags', (_event, repoPath) => gitService.getTags(repoPath));
  ipcMain.handle('git-create-tag', (_event, { path: repoPath, name, message }) =>
    gitService.createTag(repoPath, name, message)
  );
  ipcMain.handle('git-delete-tag', (_event, { path: repoPath, name }) => gitService.deleteTag(repoPath, name));

  ipcMain.handle('git-stashes', (_event, repoPath) => gitService.getStashes(repoPath));
  ipcMain.handle('git-stash-save', (_event, { path: repoPath, message }) => gitService.stashSave(repoPath, message));
  ipcMain.handle('git-stash-apply', (_event, { path: repoPath, index }) => gitService.stashApply(repoPath, index));
  ipcMain.handle('git-stash-pop', (_event, { path: repoPath, index }) => gitService.stashPop(repoPath, index));
  ipcMain.handle('git-stash-drop', (_event, { path: repoPath, index }) => gitService.stashDrop(repoPath, index));

  ipcMain.handle('git-stage', (_event, { path: repoPath, files }) => gitService.stageFiles(repoPath, files));
  ipcMain.handle('git-unstage', (_event, { path: repoPath, files }) => gitService.unstageFiles(repoPath, files));
  ipcMain.handle('git-commit', (_event, { path: repoPath, message }) => gitService.commitStaged(repoPath, message));

  ipcMain.handle('git-push', (_event, repoPath) => gitService.push(repoPath));
  ipcMain.handle('git-pull', (_event, repoPath) => gitService.pull(repoPath));
  ipcMain.handle('git-fetch', (_event, repoPath) => gitService.fetch(repoPath));

  ipcMain.handle('git-checkout', (_event, { path: repoPath, branch }) => gitService.checkout(repoPath, branch));
  ipcMain.handle('git-create-branch', (_event, { path: repoPath, branch }) =>
    gitService.createBranch(repoPath, branch)
  );
  ipcMain.handle('git-delete-branch', (_event, { path: repoPath, branch, force }) =>
    gitService.deleteBranch(repoPath, branch, force)
  );

  ipcMain.handle('git-file-content', (_event, { path: repoPath, file }) =>
    gitService.getFileContent(repoPath, file)
  );
  ipcMain.handle('git-file-content-head', (_event, { path: repoPath, file }) =>
    gitService.getFileContentAtHead(repoPath, file)
  );
  ipcMain.handle('git-file-diff', (_event, { path: repoPath, file, staged }) =>
    gitService.getFileDiff(repoPath, file, staged)
  );
}

module.exports = { registerIpcHandlers };
