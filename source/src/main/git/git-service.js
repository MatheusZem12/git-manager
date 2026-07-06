const fs = require('fs');
const path = require('path');
const simpleGit = require('simple-git');

function git(repoPath) {
  if (!fs.existsSync(repoPath)) {
    throw new Error(`Diretório não encontrado: ${repoPath}`);
  }
  return simpleGit(repoPath);
}

async function isValidGitRepo(repoPath) {
  try {
    if (!fs.existsSync(repoPath) || !fs.existsSync(path.join(repoPath, '.git'))) return false;
    return await git(repoPath).checkIsRepo();
  } catch {
    return false;
  }
}

// Dado um diretório escolhido pelo usuário, resolve para a lista de repositórios
// Git que ele representa:
//   - se o próprio diretório é um repo, retorna [ele];
//   - senão, varre os subdiretórios imediatos (1 nível) e retorna todos os que
//     forem repos Git.
// É assim que "selecionar vários de uma vez" funciona de forma confiável no
// Linux: o usuário escolhe uma pasta-pai e todos os repos dentro dela entram
// juntos, sem depender do multi-select nativo do SO (que é quebrado pra pastas).
async function findGitReposUnder(dir) {
  if (await isValidGitRepo(dir)) return [dir];

  let entries;
  try {
    entries = await fs.promises.readdir(dir, { withFileTypes: true });
  } catch {
    return [];
  }

  const found = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const childPath = path.join(dir, entry.name);
    if (await isValidGitRepo(childPath)) found.push(childPath);
  }
  return found.sort((a, b) => a.localeCompare(b));
}

async function validateProject(project) {
  const result = {
    ...project,
    existsOnDisk: false,
    hasGit: false,
    currentBranch: 'N/A',
    statusSummary: 'Diretório não encontrado',
    ahead: 0,
    behind: 0,
    available: false
  };

  if (!fs.existsSync(project.path)) return result;
  result.existsOnDisk = true;

  if (!(await isValidGitRepo(project.path))) {
    result.statusSummary = 'Sem repositório git';
    return result;
  }
  result.hasGit = true;

  try {
    const status = await git(project.path).status();
    result.currentBranch = status.current || 'HEAD destacada';
    result.statusSummary = status.files.length > 0 ? `${status.files.length} alteração(ões)` : 'Limpo';
    result.ahead = status.ahead || 0;
    result.behind = status.behind || 0;
  } catch {
    result.currentBranch = 'Erro';
    result.statusSummary = 'Erro';
  }

  result.available = result.existsOnDisk && result.hasGit;
  return result;
}

async function getRemoteUrl(repoPath) {
  try {
    const url = await git(repoPath).raw(['config', '--get', 'remote.origin.url']);
    return url.trim() || null;
  } catch {
    return null;
  }
}

async function getStatus(repoPath) {
  const status = await git(repoPath).status();
  const remote = await getRemoteUrl(repoPath);
  return {
    branch: status.current || 'HEAD destacada',
    summary: status.files.length > 0 ? `${status.files.length} alteração(ões)` : 'Limpo',
    head: status.current || '',
    remote: remote || ''
  };
}

async function getSyncStatus(repoPath) {
  const status = await git(repoPath).status();
  const remoteUrl = await getRemoteUrl(repoPath);
  return {
    ahead: status.ahead || 0,
    behind: status.behind || 0,
    hasRemote: !!remoteUrl,
    remoteUrl: remoteUrl || ''
  };
}

async function getBranches(repoPath) {
  const summary = await git(repoPath).branch(['-a']);
  return Object.values(summary.branches)
    .filter((b) => !b.name.includes('HEAD ->'))
    .map((b) => ({
      name: b.name.replace(/^remotes\//, ''),
      commitId: b.commit,
      remote: b.name.startsWith('remotes/'),
      head: b.current
    }));
}

async function getCommits(repoPath, limit = 50) {
  // Formato custom pra obter também os hashes dos pais (%P) e as refs/decorações
  // (%D) — necessários pra montar o grafo do histórico. Campos separados por
  // Unit Separator (0x1f) e commits por linha (%s é só o assunto, sem quebras).
  const SEP = '\x1f';
  const fmt = ['%H', '%h', '%P', '%an', '%ae', '%ad', '%D', '%s'].join(SEP);
  const out = await git(repoPath).raw([
    'log',
    `--max-count=${limit}`,
    '--topo-order', // pais sempre abaixo dos filhos: grafo estável, sem cruzar colunas por data
    '--date=iso',
    `--pretty=format:${fmt}`
  ]);
  if (!out) return [];
  return out
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      const [hash, short, parents, authorName, authorEmail, date, refs, subject] = line.split(SEP);
      return {
        id: hash,
        shortId: short,
        parents: parents ? parents.split(' ').filter(Boolean) : [],
        message: subject || '',
        authorName,
        authorEmail,
        date,
        refs: refs || ''
      };
    });
}

function classifyFileEntries(f) {
  const entries = [];
  const { index, working_dir: workingDir, path: filePath } = f;

  if (index === '?' && workingDir === '?') {
    entries.push({ path: filePath, type: 'UNTRACKED', staged: false });
    return entries;
  }

  const indexMap = { A: 'ADDED', M: 'MODIFIED', D: 'DELETED', R: 'RENAMED', C: 'ADDED', U: 'CONFLICTING' };
  const workingDirMap = { M: 'MODIFIED', D: 'DELETED', U: 'CONFLICTING' };

  if (index && index !== ' ' && index !== '?') {
    entries.push({ path: filePath, type: indexMap[index] || 'MODIFIED', staged: true });
  }
  if (workingDir && workingDir !== ' ' && workingDir !== '?') {
    entries.push({ path: filePath, type: workingDirMap[workingDir] || 'MODIFIED', staged: false });
  }
  return entries;
}

async function getFileChanges(repoPath) {
  const status = await git(repoPath).status();
  return status.files.flatMap(classifyFileEntries);
}

async function getTags(repoPath) {
  const tags = await git(repoPath).tags();
  return tags.all;
}

async function createTag(repoPath, name, message) {
  if (message && message.trim()) {
    await git(repoPath).addAnnotatedTag(name, message);
  } else {
    await git(repoPath).addTag(name);
  }
}

async function deleteTag(repoPath, name) {
  await git(repoPath).raw(['tag', '-d', name]);
}

async function getStashes(repoPath) {
  const out = await git(repoPath).raw(['stash', 'list']);
  return out
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
}

async function stashSave(repoPath, message) {
  const args = ['stash', 'push'];
  if (message && message.trim()) args.push('-m', message);
  await git(repoPath).raw(args);
}

async function stashApply(repoPath, index = 0) {
  await git(repoPath).raw(['stash', 'apply', `stash@{${index}}`]);
}

async function stashPop(repoPath, index = 0) {
  await git(repoPath).raw(['stash', 'pop', `stash@{${index}}`]);
}

async function stashDrop(repoPath, index = 0) {
  await git(repoPath).raw(['stash', 'drop', `stash@{${index}}`]);
}

async function stageFiles(repoPath, files) {
  await git(repoPath).add(files);
}

async function unstageFiles(repoPath, files) {
  await git(repoPath).raw(['restore', '--staged', ...files]);
}

async function commitStaged(repoPath, message, authorName, authorEmail) {
  const options = {};
  if (authorName && authorEmail) {
    options['--author'] = `${authorName} <${authorEmail}>`;
  }
  const result = await git(repoPath).commit(message, undefined, options);
  return result;
}

async function push(repoPath) {
  return git(repoPath).push();
}

async function pull(repoPath) {
  return git(repoPath).pull();
}

async function fetch(repoPath) {
  return git(repoPath).fetch();
}

async function checkout(repoPath, branchName) {
  await git(repoPath).checkout(branchName);
}

async function createBranch(repoPath, branchName) {
  await git(repoPath).checkoutLocalBranch(branchName);
}

async function deleteBranch(repoPath, branchName, force = false) {
  await git(repoPath).deleteLocalBranch(branchName, force);
}

async function getFileContent(repoPath, filePath) {
  const full = path.join(repoPath, filePath);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, 'utf-8');
}

async function getFileContentAtHead(repoPath, filePath) {
  try {
    return await git(repoPath).show([`HEAD:${filePath}`]);
  } catch {
    return '';
  }
}

async function getFileDiff(repoPath, filePath, staged) {
  const args = staged ? ['diff', '--cached', '--', filePath] : ['diff', '--', filePath];
  const out = await git(repoPath).raw(args);
  return out || 'Nenhuma alteração detectada.';
}

module.exports = {
  isValidGitRepo,
  findGitReposUnder,
  validateProject,
  getStatus,
  getSyncStatus,
  getBranches,
  getCommits,
  getFileChanges,
  getTags,
  createTag,
  deleteTag,
  getStashes,
  stashSave,
  stashApply,
  stashPop,
  stashDrop,
  stageFiles,
  unstageFiles,
  commitStaged,
  push,
  pull,
  fetch,
  checkout,
  createBranch,
  deleteBranch,
  getFileContent,
  getFileContentAtHead,
  getFileDiff
};
