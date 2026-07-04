export const listProjects = () => window.gitManagerAPI.listProjects();
export const addProject = (project) => window.gitManagerAPI.addProject(project);
export const updateProject = (repoPath, updates) => window.gitManagerAPI.updateProject(repoPath, updates);
export const removeProject = (repoPath) => window.gitManagerAPI.removeProject(repoPath);
export const checkProject = (repoPath) => window.gitManagerAPI.checkProject(repoPath);
export const selectDirectories = () => window.gitManagerAPI.selectDirectories();
export const openPath = (targetPath) => window.gitManagerAPI.openPath(targetPath);

export const listGroups = () => window.gitManagerAPI.listGroups();
export const addGroup = (name, parentId) => window.gitManagerAPI.addGroup(name, parentId);
export const renameGroup = (id, name) => window.gitManagerAPI.renameGroup(id, name);
export const reparentGroup = (id, parentId) => window.gitManagerAPI.reparentGroup(id, parentId);
export const removeGroup = (id) => window.gitManagerAPI.removeGroup(id);

export const getStatus = (repoPath) => window.gitManagerAPI.getStatus(repoPath);
export const getSyncStatus = (repoPath) => window.gitManagerAPI.getSyncStatus(repoPath);
export const getBranches = (repoPath) => window.gitManagerAPI.getBranches(repoPath);
export const getCommits = (repoPath, limit) => window.gitManagerAPI.getCommits(repoPath, limit);
export const getChanges = (repoPath) => window.gitManagerAPI.getChanges(repoPath);

export const getTags = (repoPath) => window.gitManagerAPI.getTags(repoPath);
export const createTag = (repoPath, name, message) => window.gitManagerAPI.createTag(repoPath, name, message);
export const deleteTag = (repoPath, name) => window.gitManagerAPI.deleteTag(repoPath, name);

export const getStashes = (repoPath) => window.gitManagerAPI.getStashes(repoPath);
export const stashSave = (repoPath, message) => window.gitManagerAPI.stashSave(repoPath, message);
export const stashApply = (repoPath, index) => window.gitManagerAPI.stashApply(repoPath, index);
export const stashPop = (repoPath, index) => window.gitManagerAPI.stashPop(repoPath, index);
export const stashDrop = (repoPath, index) => window.gitManagerAPI.stashDrop(repoPath, index);

export const stageFiles = (repoPath, files) => window.gitManagerAPI.stageFiles(repoPath, files);
export const unstageFiles = (repoPath, files) => window.gitManagerAPI.unstageFiles(repoPath, files);
export const commit = (repoPath, message) => window.gitManagerAPI.commit(repoPath, message);

export const push = (repoPath) => window.gitManagerAPI.push(repoPath);
export const pull = (repoPath) => window.gitManagerAPI.pull(repoPath);
export const fetch = (repoPath) => window.gitManagerAPI.fetch(repoPath);

export const checkout = (repoPath, branch) => window.gitManagerAPI.checkout(repoPath, branch);
export const createBranch = (repoPath, branch) => window.gitManagerAPI.createBranch(repoPath, branch);
export const deleteBranch = (repoPath, branch, force) =>
  window.gitManagerAPI.deleteBranch(repoPath, branch, force);

export const getFileContent = (repoPath, file) => window.gitManagerAPI.getFileContent(repoPath, file);
export const getFileContentHead = (repoPath, file) => window.gitManagerAPI.getFileContentHead(repoPath, file);
export const getFileDiff = (repoPath, file, staged) => window.gitManagerAPI.getFileDiff(repoPath, file, staged);
