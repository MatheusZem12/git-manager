const fs = require('fs');
const path = require('path');
const os = require('os');

const LEGACY_REPOS_TXT = path.join(os.homedir(), '.git-manager', 'repos.txt');

// Replica o split(regex, limit) do Java: no máximo `limit-1` cortes, o resto
// (incluindo separadores literais) fica inteiro no último elemento.
function splitLimit(str, sep, limit) {
  const parts = [];
  let rest = str;
  while (parts.length < limit - 1) {
    const idx = rest.indexOf(sep);
    if (idx === -1) break;
    parts.push(rest.slice(0, idx));
    rest = rest.slice(idx + 1);
  }
  parts.push(rest);
  return parts;
}

// Replica o unescape do Java: uma barra invertida seguida de char desconhecido
// é descartada (não é um bug nosso, é o formato legado que estamos lendo).
function unescapeLegacy(value) {
  let result = '';
  for (let i = 0; i < value.length; i++) {
    if (value[i] === '\\' && i + 1 < value.length) {
      const next = value[i + 1];
      if (next === '\\' || next === '|' || next === 'n') {
        result += next === 'n' ? '\n' : next;
        i++;
        continue;
      }
      continue; // descarta a barra, char seguinte é processado na próxima iteração
    }
    result += value[i];
  }
  return result;
}

function importLegacyReposTxt() {
  if (!fs.existsSync(LEGACY_REPOS_TXT)) return [];
  const lines = fs.readFileSync(LEGACY_REPOS_TXT, 'utf-8').split('\n');
  const projects = [];
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const parts = splitLimit(line, '|', 4);
    if (parts.length < 2) continue;
    const name = parts[0];
    const repoPath = parts[1];
    let group = '';
    let notes = '';
    if (parts.length === 3) {
      notes = unescapeLegacy(parts[2]);
    } else if (parts.length === 4) {
      group = unescapeLegacy(parts[2]);
      notes = unescapeLegacy(parts[3]);
    }
    projects.push({ name, path: repoPath, group, notes });
  }
  return projects;
}

function createProjectStore(storeFilePath) {
  function load() {
    if (!fs.existsSync(storeFilePath)) {
      const migrated = importLegacyReposTxt();
      save(migrated);
      return migrated;
    }
    return JSON.parse(fs.readFileSync(storeFilePath, 'utf-8'));
  }

  function save(projects) {
    fs.mkdirSync(path.dirname(storeFilePath), { recursive: true });
    fs.writeFileSync(storeFilePath, JSON.stringify(projects, null, 2));
  }

  function add({ name, path: repoPath, group, groupId, notes }) {
    const projects = load();
    if (projects.some((p) => p.path === repoPath)) {
      throw new Error('Este diretório já está cadastrado.');
    }
    const project = { name, path: repoPath, group: group || '', groupId: groupId || '', notes: notes || '' };
    projects.push(project);
    save(projects);
    return project;
  }

  // Move todos os projetos de um grupo para outro (ou pra "sem grupo" se
  // toGroupId for vazio). Usado quando um grupo é dissolvido/removido.
  function reassignGroup(fromGroupId, toGroupId) {
    const projects = load();
    let changed = false;
    for (const p of projects) {
      if ((p.groupId || '') === (fromGroupId || '')) {
        p.groupId = toGroupId || '';
        changed = true;
      }
    }
    if (changed) save(projects);
  }

  function update(repoPath, updates) {
    const projects = load();
    const index = projects.findIndex((p) => p.path === repoPath);
    if (index === -1) throw new Error('Projeto não encontrado.');
    projects[index] = { ...projects[index], ...updates, path: repoPath };
    save(projects);
    return projects[index];
  }

  function remove(repoPath) {
    const projects = load().filter((p) => p.path !== repoPath);
    save(projects);
  }

  return { load, save, add, update, remove, reassignGroup };
}

module.exports = { createProjectStore };
