const fs = require('fs');
const path = require('path');

// Grupos são hierárquicos: cada grupo tem um `parentId` (null = topo), o que
// permite subgrupos aninhados em qualquer profundidade. Ficam num arquivo
// próprio (não junto dos projetos) pra que grupos vazios persistam — o usuário
// pode criar um grupo e só depois arrastar repositórios pra dentro dele.

function genId() {
  return 'g_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

function parentMap(groups) {
  return new Map(groups.map((g) => [g.id, g.parentId || null]));
}

// true se `nodeId` é o próprio `ancestorId` ou está abaixo dele na árvore.
function isSelfOrDescendant(groups, ancestorId, nodeId) {
  const parentOf = parentMap(groups);
  let cur = nodeId;
  while (cur) {
    if (cur === ancestorId) return true;
    cur = parentOf.get(cur);
  }
  return false;
}

function normalizeName(name) {
  return (name || '').trim().toLowerCase();
}

// true se já existe outro grupo com esse nome sob o mesmo pai (comparação sem
// diferenciar maiúsculas/minúsculas). `exceptId` ignora o próprio grupo (usado
// ao renomear). Nomes iguais são permitidos em pais diferentes.
function siblingNameTaken(groups, parentId, name, exceptId = null) {
  const target = normalizeName(name);
  const pid = parentId || null;
  return groups.some(
    (g) => g.id !== exceptId && (g.parentId || null) === pid && normalizeName(g.name) === target
  );
}

function createGroupStore(storeFilePath) {
  function load() {
    if (!fs.existsSync(storeFilePath)) return [];
    try {
      const data = JSON.parse(fs.readFileSync(storeFilePath, 'utf-8'));
      return Array.isArray(data) ? data : [];
    } catch {
      return [];
    }
  }

  function save(groups) {
    fs.mkdirSync(path.dirname(storeFilePath), { recursive: true });
    fs.writeFileSync(storeFilePath, JSON.stringify(groups, null, 2));
  }

  function add({ name, parentId }) {
    const finalName = (name || '').trim();
    if (!finalName) throw new Error('O nome do grupo não pode ser vazio.');
    const groups = load();
    const pid = parentId || null;
    if (pid && !groups.some((g) => g.id === pid)) {
      throw new Error('Grupo pai não encontrado.');
    }
    if (siblingNameTaken(groups, pid, finalName)) {
      throw new Error(`Já existe um grupo chamado "${finalName}" aqui.`);
    }
    const group = { id: genId(), name: finalName, parentId: pid };
    groups.push(group);
    save(groups);
    return group;
  }

  function rename(id, name) {
    const finalName = (name || '').trim();
    if (!finalName) throw new Error('O nome do grupo não pode ser vazio.');
    const groups = load();
    const group = groups.find((g) => g.id === id);
    if (!group) throw new Error('Grupo não encontrado.');
    if (siblingNameTaken(groups, group.parentId || null, finalName, id)) {
      throw new Error(`Já existe um grupo chamado "${finalName}" aqui.`);
    }
    group.name = finalName;
    save(groups);
    return group;
  }

  function reparent(id, parentId) {
    const groups = load();
    const group = groups.find((g) => g.id === id);
    if (!group) throw new Error('Grupo não encontrado.');
    const pid = parentId || null;
    if (pid) {
      if (!groups.some((g) => g.id === pid)) throw new Error('Grupo pai não encontrado.');
      // Impede criar ciclos (mover um grupo pra dentro de si mesmo ou de um
      // descendente seu).
      if (isSelfOrDescendant(groups, id, pid)) {
        throw new Error('Não é possível mover um grupo para dentro de si mesmo.');
      }
    }
    // Mover para um pai que já tem um filho com o mesmo nome criaria duplicata.
    if (siblingNameTaken(groups, pid, group.name, id)) {
      throw new Error(`Já existe um grupo chamado "${group.name}" no destino.`);
    }
    group.parentId = pid;
    save(groups);
    return group;
  }

  // Remove um grupo "dissolvendo-o": os subgrupos e (via project-store) os
  // repositórios diretos dele sobem para o grupo pai. Retorna para onde as
  // coisas foram reatribuídas, pra que o chamador reatribua os projetos.
  function remove(id) {
    const groups = load();
    const target = groups.find((g) => g.id === id);
    if (!target) return { removedId: id, reparentTo: null };
    const reparentTo = target.parentId || null;
    const updated = groups
      .filter((g) => g.id !== id)
      .map((g) => (g.parentId === id ? { ...g, parentId: reparentTo } : g));
    save(updated);
    return { removedId: id, reparentTo };
  }

  return { load, save, add, rename, reparent, remove };
}

module.exports = { createGroupStore };
