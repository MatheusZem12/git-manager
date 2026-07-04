const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('gitManagerAPI', {
  listProjects: () => ipcRenderer.invoke('projects-list'),
  addProject: (project) => ipcRenderer.invoke('projects-add', project),
  updateProject: (repoPath, updates) => ipcRenderer.invoke('projects-update', { path: repoPath, updates }),
  removeProject: (repoPath) => ipcRenderer.invoke('projects-remove', repoPath),
  checkProject: (repoPath) => ipcRenderer.invoke('project-check', repoPath),
  selectDirectories: () => ipcRenderer.invoke('select-directories'),
  openPath: (targetPath) => ipcRenderer.invoke('open-path', targetPath),

  listGroups: () => ipcRenderer.invoke('groups-list'),
  addGroup: (name, parentId) => ipcRenderer.invoke('groups-add', { name, parentId }),
  renameGroup: (id, name) => ipcRenderer.invoke('groups-rename', { id, name }),
  reparentGroup: (id, parentId) => ipcRenderer.invoke('groups-reparent', { id, parentId }),
  removeGroup: (id) => ipcRenderer.invoke('groups-remove', id),

  getStatus: (repoPath) => ipcRenderer.invoke('git-status', repoPath),
  getSyncStatus: (repoPath) => ipcRenderer.invoke('git-sync-status', repoPath),
  getBranches: (repoPath) => ipcRenderer.invoke('git-branches', repoPath),
  getCommits: (repoPath, limit) => ipcRenderer.invoke('git-commits', { path: repoPath, limit }),
  getChanges: (repoPath) => ipcRenderer.invoke('git-changes', repoPath),

  getTags: (repoPath) => ipcRenderer.invoke('git-tags', repoPath),
  createTag: (repoPath, name, message) => ipcRenderer.invoke('git-create-tag', { path: repoPath, name, message }),
  deleteTag: (repoPath, name) => ipcRenderer.invoke('git-delete-tag', { path: repoPath, name }),

  getStashes: (repoPath) => ipcRenderer.invoke('git-stashes', repoPath),
  stashSave: (repoPath, message) => ipcRenderer.invoke('git-stash-save', { path: repoPath, message }),
  stashApply: (repoPath, index) => ipcRenderer.invoke('git-stash-apply', { path: repoPath, index }),
  stashPop: (repoPath, index) => ipcRenderer.invoke('git-stash-pop', { path: repoPath, index }),
  stashDrop: (repoPath, index) => ipcRenderer.invoke('git-stash-drop', { path: repoPath, index }),

  stageFiles: (repoPath, files) => ipcRenderer.invoke('git-stage', { path: repoPath, files }),
  unstageFiles: (repoPath, files) => ipcRenderer.invoke('git-unstage', { path: repoPath, files }),
  commit: (repoPath, message) => ipcRenderer.invoke('git-commit', { path: repoPath, message }),

  push: (repoPath) => ipcRenderer.invoke('git-push', repoPath),
  pull: (repoPath) => ipcRenderer.invoke('git-pull', repoPath),
  fetch: (repoPath) => ipcRenderer.invoke('git-fetch', repoPath),

  checkout: (repoPath, branch) => ipcRenderer.invoke('git-checkout', { path: repoPath, branch }),
  createBranch: (repoPath, branch) => ipcRenderer.invoke('git-create-branch', { path: repoPath, branch }),
  deleteBranch: (repoPath, branch, force) =>
    ipcRenderer.invoke('git-delete-branch', { path: repoPath, branch, force }),

  getFileContent: (repoPath, file) => ipcRenderer.invoke('git-file-content', { path: repoPath, file }),
  getFileContentHead: (repoPath, file) => ipcRenderer.invoke('git-file-content-head', { path: repoPath, file }),
  getFileDiff: (repoPath, file, staged) => ipcRenderer.invoke('git-file-diff', { path: repoPath, file, staged })
});
