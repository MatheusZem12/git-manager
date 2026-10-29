const fs = require('fs');
const path = require('path');

// Groups are hierarchical: each group has a `parentId` (null = top level), which
// allows subgroups nested to any depth. They live in their own file (not
// alongside the projects) so that empty groups persist — the user can create
// a group and only later drag repositories into it.

function genId() {
  return 'g_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

function parentMap(groups) {
  return new Map(groups.map((g) => [g.id, g.parentId || null]));
}

// true if `nodeId` is `ancestorId` itself or sits below it in the tree.
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

// true if another group with this name already exists under the same parent
// (case-insensitive). `exceptId` skips the group itself (used when
// renaming). Equal names are allowed under different parents.
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
    if (!finalName) throw new Error('The group name cannot be empty.');
    const groups = load();
    const pid = parentId || null;
    if (pid && !groups.some((g) => g.id === pid)) {
      throw new Error('Parent group not found.');
    }
    if (siblingNameTaken(groups, pid, finalName)) {
      throw new Error(`A group named "${finalName}" already exists here.`);
    }
    const group = { id: genId(), name: finalName, parentId: pid };
    groups.push(group);
    save(groups);
    return group;
  }

  function rename(id, name) {
    const finalName = (name || '').trim();
    if (!finalName) throw new Error('The group name cannot be empty.');
    const groups = load();
    const group = groups.find((g) => g.id === id);
    if (!group) throw new Error('Group not found.');
    if (siblingNameTaken(groups, group.parentId || null, finalName, id)) {
      throw new Error(`A group named "${finalName}" already exists here.`);
    }
    group.name = finalName;
    save(groups);
    return group;
  }

  function reparent(id, parentId) {
    const groups = load();
    const group = groups.find((g) => g.id === id);
    if (!group) throw new Error('Group not found.');
    const pid = parentId || null;
    if (pid) {
      if (!groups.some((g) => g.id === pid)) throw new Error('Parent group not found.');
      // Prevents cycles (moving a group into itself or into one of its
      // descendants).
      if (isSelfOrDescendant(groups, id, pid)) {
        throw new Error('A group cannot be moved into itself.');
      }
    }
    // Moving to a parent that already has a child with the same name would create a duplicate.
    if (siblingNameTaken(groups, pid, group.name, id)) {
      throw new Error(`A group named "${group.name}" already exists at the destination.`);
    }
    group.parentId = pid;
    save(groups);
    return group;
  }

  // Removes a group by "dissolving" it: its subgroups and (via project-store) its
  // direct repositories move up to the parent group. Returns where things were
  // reassigned to, so the caller can reassign the projects.
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
