import * as api from '../services/git-api.js';
import { confirmDialog, promptDialog } from '../services/dialogs.js';
import { toastSuccess, toastError } from '../services/toast.js';

let searchQuery = '';
// Collapse state per group id. The "No group" section uses the key '' (real group
// ids are never empty).
const collapsedGroups = new Set();
const UNGROUPED = '';

function isAvailable(p) {
  return p.existsOnDisk && p.hasGit;
}

function hasChanges(p) {
  return isAvailable(p) && (p.statusSummary !== 'Clean' || p.ahead > 0 || p.behind > 0);
}

function statusClass(p) {
  if (!isAvailable(p)) return 'danger';
  if (hasChanges(p)) return 'warn';
  return 'ok';
}

function matchesSearch(p) {
  if (!searchQuery) return true;
  const q = searchQuery.toLowerCase();
  return p.name.toLowerCase().includes(q) || p.path.toLowerCase().includes(q);
}

function escapeHtml(s) {
  return String(s).replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );
}

export async function renderSidebar(container, { selectedPath, onSelect, onRemoved }) {
  // Keeps the list scroll position across re-renders (e.g. on refresh).
  const prevScroll = container.querySelector('.project-list')?.scrollTop || 0;
  // "Loading..." only on the first load. On later refreshes we keep the current
  // content visible during the fetch and swap it in one go — no flicker.
  if (!container.querySelector('.project-list')) {
    container.innerHTML = `<div class="empty-state">Loading...</div>`;
  }
  let projects;
  let groups;
  try {
    [projects, groups] = await Promise.all([api.listProjects(), api.listGroups()]);
  } catch (err) {
    container.innerHTML = `<div class="empty-state">Error loading projects: ${escapeHtml(err.message)}</div>`;
    return;
  }

  // `currentSelected` tracks the selected repo without a re-render: clicking a
  // card only updates the highlight in place (keeps the nav scroll and avoids
  // re-validating every repo). A full refresh only happens on group/add/remove
  // actions or the "Refresh" button.
  let currentSelected = selectedPath;
  const refresh = () => renderSidebar(container, { selectedPath: currentSelected, onSelect, onRemoved });

  const total = projects.length;
  const ok = projects.filter((p) => isAvailable(p) && !hasChanges(p)).length;
  const warn = projects.filter((p) => hasChanges(p)).length;
  const danger = projects.filter((p) => !isAvailable(p)).length;

  // --- Indexes of the group + project tree ---
  const filtered = projects.filter(matchesSearch);

  const childrenMap = new Map(); // parentId ('' = top level) -> [group]
  for (const g of groups) {
    const key = g.parentId || '';
    if (!childrenMap.has(key)) childrenMap.set(key, []);
    childrenMap.get(key).push(g);
  }
  for (const arr of childrenMap.values()) arr.sort((a, b) => a.name.localeCompare(b.name));

  const projectsByGroup = new Map(); // groupId ('' = no group) -> [project]
  for (const p of filtered) {
    const key = p.groupId || '';
    if (!projectsByGroup.has(key)) projectsByGroup.set(key, []);
    projectsByGroup.get(key).push(p);
  }

  const parentOf = new Map(groups.map((g) => [g.id, g.parentId || '']));

  const childGroupsOf = (groupId) => childrenMap.get(groupId || '') || [];
  const projectsIn = (groupId) => projectsByGroup.get(groupId || '') || [];

  function countRepos(groupId) {
    let n = projectsIn(groupId).length;
    for (const c of childGroupsOf(groupId)) n += countRepos(c.id);
    return n;
  }
  function subtreeHasMatch(groupId) {
    if (projectsIn(groupId).length > 0) return true;
    return childGroupsOf(groupId).some((c) => subtreeHasMatch(c.id));
  }
  // Avoids cycles when moving groups: the target can't be the group itself or
  // one of its descendants.
  function wouldCreateCycle(movingId, targetId) {
    let cur = targetId;
    while (cur) {
      if (cur === movingId) return true;
      cur = parentOf.get(cur) || '';
    }
    return false;
  }

  function renderGroupNode(group) {
    // While searching, everything shows expanded to make results easy to see.
    const collapsed = !searchQuery && collapsedGroups.has(group.id);
    const count = countRepos(group.id);
    const subGroups = childGroupsOf(group.id).filter((g) => !searchQuery || subtreeHasMatch(g.id));
    // Children are always rendered (only hidden with `hidden` when collapsed),
    // so collapsing/expanding is an instant toggle in the DOM, with no
    // re-render or re-fetch (which made the sidebar flicker).
    const childrenHtml = `<div class="group-children"${collapsed ? ' hidden' : ''}>
          ${subGroups.map(renderGroupNode).join('')}
          ${projectsIn(group.id)
            .map((p) => renderCard(p, selectedPath))
            .join('')}
        </div>`;
    return `
      <div class="group-node" data-group-id="${group.id}">
        <div class="group-header" data-group-id="${group.id}" draggable="true">
          <span class="group-caret">${collapsed ? '▸' : '▾'}</span>
          <span class="group-name">${escapeHtml(group.name)}</span>
          <span class="pill">${count}</span>
          <span class="group-actions">
            <button class="icon-btn" data-group-action="add-sub" data-group-id="${group.id}" title="New subgroup">＋</button>
            <button class="icon-btn" data-group-action="rename" data-group-id="${group.id}" title="Rename group">✎</button>
            <button class="icon-btn" data-group-action="remove" data-group-id="${group.id}" title="Delete group">🗑</button>
          </span>
        </div>
        ${childrenHtml}
      </div>
    `;
  }

  function renderUngrouped() {
    const ps = projectsIn(UNGROUPED);
    // While searching, it only shows if there is an ungrouped result. Without a
    // search, it shows whenever there are loose repos or groups (to serve as the
    // "drag out" target).
    if (searchQuery && ps.length === 0) return '';
    if (!searchQuery && ps.length === 0 && groups.length === 0) return '';
    const collapsed = !searchQuery && collapsedGroups.has(UNGROUPED);
    return `
      <div class="group-node" data-group-id="">
        <div class="group-header" data-group-id="" draggable="false">
          <span class="group-caret">${collapsed ? '▸' : '▾'}</span>
          <span class="group-name">No group</span>
          <span class="pill">${ps.length}</span>
        </div>
        <div class="group-children"${collapsed ? ' hidden' : ''}>${ps
          .map((p) => renderCard(p, selectedPath))
          .join('')}</div>
      </div>
    `;
  }

  const topGroups = childGroupsOf('').filter((g) => !searchQuery || subtreeHasMatch(g.id));

  container.innerHTML = `
    <div class="sidebar-header">
      <div class="sidebar-title">
        <div class="logo">📁</div>
        <h1>Git Manager</h1>
        <button class="icon-btn sidebar-collapse-btn" id="collapse-sidebar-btn" title="Collapse sidebar">⯇</button>
      </div>
      <div class="search-box">
        <input type="text" id="search-input" placeholder="Search by name or path..." value="${escapeHtml(searchQuery)}">
      </div>
    </div>
    <div class="stats-bar">
      <div class="stat"><div class="stat-value">${total}</div><div class="stat-label">Total</div></div>
      <div class="stat ok"><div class="stat-value">${ok}</div><div class="stat-label">OK</div></div>
      <div class="stat warn"><div class="stat-value">${warn}</div><div class="stat-label">Changes</div></div>
      <div class="stat danger"><div class="stat-value">${danger}</div><div class="stat-label">Unavailable</div></div>
    </div>
    <div class="project-list">
      ${
        total === 0 && groups.length === 0
          ? `<div class="empty-state"><div class="empty-icon">📭</div>No repositories yet.<br>Click "Add repository" below.</div>`
          : topGroups.map(renderGroupNode).join('') + renderUngrouped()
      }
    </div>
    <div class="sidebar-footer">
      <button class="btn btn-ghost" id="add-group-btn" style="width: 100%; margin-bottom: 8px;">+ New group</button>
      <button class="btn btn-primary" id="add-repo-btn" style="width: 100%;">+ Add repository</button>
    </div>
  `;

  const listEl = container.querySelector('.project-list');
  if (listEl) listEl.scrollTop = prevScroll;

  container.querySelector('#search-input').addEventListener('input', (e) => {
    searchQuery = e.target.value;
    refresh();
  });

  container
    .querySelector('#collapse-sidebar-btn')
    .addEventListener('click', () => document.getElementById('app').classList.add('sidebar-collapsed'));

  // --- Collapse/expand groups (click on the header, except on the actions) ---
  // A direct DOM toggle: hides/shows the children and flips the arrow, with no
  // re-render or re-fetch (which caused the flicker). Keeps scroll and state intact.
  container.querySelectorAll('.group-header').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (e.target.closest('.group-actions')) return;
      const id = el.dataset.groupId;
      const collapsed = !collapsedGroups.has(id); // state after the toggle
      if (collapsed) collapsedGroups.add(id);
      else collapsedGroups.delete(id);

      const node = el.closest('.group-node');
      const children = node.querySelector(':scope > .group-children');
      const caret = el.querySelector('.group-caret');
      if (caret) caret.textContent = collapsed ? '▸' : '▾';
      if (children) children.hidden = collapsed;
    });
  });

  // --- Group actions: new subgroup, rename, delete ---
  container.querySelectorAll('[data-group-action="add-sub"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const name = await promptDialog({ title: 'New subgroup', label: 'Subgroup name', placeholder: 'e.g. client X' });
      if (!name) return;
      try {
        await api.addGroup(name, el.dataset.groupId);
        collapsedGroups.delete(el.dataset.groupId); // expand the parent to show the new one
        toastSuccess('Subgroup created');
        refresh();
      } catch (err) {
        toastError('Error creating subgroup', err.message);
      }
    });
  });

  container.querySelectorAll('[data-group-action="rename"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const g = groups.find((grp) => grp.id === el.dataset.groupId);
      const name = await promptDialog({ title: 'Rename group', label: 'Name', initialValue: g ? g.name : '' });
      if (!name) return;
      try {
        await api.renameGroup(el.dataset.groupId, name);
        toastSuccess('Group renamed');
        refresh();
      } catch (err) {
        toastError('Error renaming group', err.message);
      }
    });
  });

  container.querySelectorAll('[data-group-action="remove"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const g = groups.find((grp) => grp.id === el.dataset.groupId);
      const ok2 = await confirmDialog({
        title: 'Delete group',
        message: `Delete the group "${g ? g.name : ''}"? The repositories and subgroups inside it move up to the parent group (or "No group"). No file is deleted from disk.`,
        confirmLabel: 'Delete'
      });
      if (!ok2) return;
      try {
        await api.removeGroup(el.dataset.groupId);
        toastSuccess('Group deleted');
        refresh();
      } catch (err) {
        toastError('Error deleting group', err.message);
      }
    });
  });

  container.querySelector('#add-group-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'New group', label: 'Group name', placeholder: 'e.g. work' });
    if (!name) return;
    try {
      await api.addGroup(name, null);
      toastSuccess('Group created');
      refresh();
    } catch (err) {
      toastError('Error creating group', err.message);
    }
  });

  // --- Project cards: select, rename, remove ---
  container.querySelectorAll('.project-card').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (e.target.closest('.project-card-menu')) return;
      // Only moves the highlight and updates the right panel — no nav re-render
      // (keeps the scroll and doesn't re-validate every repo).
      currentSelected = el.dataset.path;
      container.querySelectorAll('.project-card.active').forEach((c) => c.classList.remove('active'));
      el.classList.add('active');
      onSelect(el.dataset.path);
    });
  });

  container.querySelectorAll('[data-action="rename"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const p = projects.find((proj) => proj.path === el.dataset.path);
      const newName = await promptDialog({ title: 'Rename project', label: 'Name', initialValue: p.name });
      if (!newName) return;
      try {
        await api.updateProject(p.path, { name: newName });
        toastSuccess('Project renamed');
        refresh();
      } catch (err) {
        toastError('Error renaming', err.message);
      }
    });
  });

  container.querySelectorAll('[data-action="remove"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const p = projects.find((proj) => proj.path === el.dataset.path);
      const ok2 = await confirmDialog({
        title: 'Remove project',
        message: `Remove "${p.name}" from the list? This doesn't delete the files from disk, it only unlinks them from Git Manager.`,
        confirmLabel: 'Remove'
      });
      if (!ok2) return;
      try {
        await api.removeProject(p.path);
        toastSuccess('Project removed');
        if (selectedPath === p.path && onRemoved) {
          await onRemoved();
        } else {
          refresh();
        }
      } catch (err) {
        toastError('Error removing', err.message);
      }
    });
  });

  wireDragAndDrop(container, { wouldCreateCycle, refresh });

  container.querySelector('#add-repo-btn').addEventListener('click', () => openAddRepoModal(groups, projects, refresh));
}

// Drag & drop: drag a repository card (or a group) and drop it on a group
// (or on "No group") to move it. Each `.group-node` is a drop zone; we use
// stopPropagation so only the innermost node under the cursor reacts
// (nested nodes).
function wireDragAndDrop(container, { wouldCreateCycle, refresh }) {
  container.querySelectorAll('.project-card').forEach((card) => {
    card.setAttribute('draggable', 'true');
    card.addEventListener('dragstart', (e) => {
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', JSON.stringify({ type: 'repo', path: card.dataset.path }));
    });
  });

  container.querySelectorAll('.group-header[draggable="true"]').forEach((header) => {
    header.addEventListener('dragstart', (e) => {
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', JSON.stringify({ type: 'group', id: header.dataset.groupId }));
    });
  });

  container.querySelectorAll('.group-node').forEach((node) => {
    node.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'move';
      node.classList.add('drag-over');
    });
    node.addEventListener('dragleave', (e) => {
      if (!node.contains(e.relatedTarget)) node.classList.remove('drag-over');
    });
    node.addEventListener('drop', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      node.classList.remove('drag-over');
      const targetGroupId = node.dataset.groupId || '';

      let payload;
      try {
        payload = JSON.parse(e.dataTransfer.getData('text/plain'));
      } catch {
        return;
      }

      try {
        if (payload.type === 'repo') {
          await api.updateProject(payload.path, { groupId: targetGroupId });
        } else if (payload.type === 'group') {
          if (payload.id === targetGroupId || wouldCreateCycle(payload.id, targetGroupId)) {
            toastError('Invalid move', 'A group cannot be moved into itself.');
            return;
          }
          await api.reparentGroup(payload.id, targetGroupId || null);
        }
        refresh();
      } catch (err) {
        toastError('Error moving', err.message);
      }
    });
  });
}

// Flattens the group tree into a list with indented labels ("Parent / Child"),
// to fill the group combobox of the add-repository modal.
function flattenGroups(groups) {
  const childrenMap = new Map();
  for (const g of groups) {
    const key = g.parentId || '';
    if (!childrenMap.has(key)) childrenMap.set(key, []);
    childrenMap.get(key).push(g);
  }
  for (const arr of childrenMap.values()) arr.sort((a, b) => a.name.localeCompare(b.name));

  const out = [];
  const walk = (parentId, prefix) => {
    for (const g of childrenMap.get(parentId || '') || []) {
      out.push({ id: g.id, name: g.name, label: prefix + g.name });
      walk(g.id, prefix + g.name + ' / ');
    }
  };
  walk('', '');
  return out;
}

// Folder multi-selection is broken on Linux (Chromium only enables multi-select
// for files, never for folders), so we don't rely on the native dialog for
// it. Instead, each chosen folder is resolved in the main process into the
// Git repos it contains: if the folder itself is a repo, it goes in; if not,
// every repo in its immediate subdirectories goes in. So "select several" =
// picking the parent folder. Only valid Git repos join the list (the rest is
// rejected with a warning), and the user can still open the picker as many
// times as they like, building a reviewable list before confirming.
function openAddRepoModal(groups, projects, onDone) {
  const picked = [];
  // Group combobox: the user can pick an existing group OR type a new name.
  // If what they type matches an existing group, the repo goes into that
  // group; if it matches none, a new (top-level) group is created.
  let groupText = '';
  let selectedGroupId = null; // set when they click a suggestion
  const groupOptions = flattenGroups(groups);

  // Repo names per group, to show in the suggestions what's already there.
  const reposByGroup = new Map();
  for (const p of projects) {
    const key = p.groupId || '';
    if (!reposByGroup.has(key)) reposByGroup.set(key, []);
    reposByGroup.get(key).push(p.name);
  }

  const norm = (s) => (s || '').trim().toLowerCase();
  const matchingGroups = () => {
    const q = norm(groupText);
    if (!q) return groupOptions;
    return groupOptions.filter((g) => norm(g.label).includes(q) || norm(g.name).includes(q));
  };
  const exactMatch = () => {
    const q = norm(groupText);
    if (!q) return null;
    return groupOptions.find((g) => norm(g.label) === q || norm(g.name) === q) || null;
  };

  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  document.body.appendChild(overlay);

  function modalHtml() {
    return `
      <div class="modal">
        <h3>Add repository(ies)</h3>
        <p>Select a folder that is already a Git repository, <strong>or</strong> a folder holding several repositories (all of them are detected at once). You can repeat the selection as many times as you like before confirming.</p>
        <div class="form-group">
          <label>Group (optional, applied to all)</label>
          <div class="combo">
            <input type="text" id="group-input" autocomplete="off" placeholder="Pick an existing group or type a new one..." value="${escapeHtml(groupText)}">
            <div class="combo-suggestions" id="group-suggestions"></div>
          </div>
          <div class="combo-hint" id="group-hint"></div>
        </div>
        <div class="modal-picked-list">
          ${
            picked.length === 0
              ? '<p class="hint">No folder selected yet.</p>'
              : picked
                  .map(
                    (p, i) => `
            <div class="modal-picked-item">
              <span class="path">${escapeHtml(p)}</span>
              <button class="icon-btn" data-remove-index="${i}" title="Remove">✕</button>
            </div>
          `
                  )
                  .join('')
          }
        </div>
        <div class="modal-actions" style="justify-content: space-between;">
          <button class="btn btn-ghost compact" id="pick-folder-btn">+ Select folder(s)</button>
          <div style="display: flex; gap: 8px;">
            <button class="btn btn-ghost" data-action="cancel">Cancel</button>
            <button class="btn btn-primary" data-action="confirm" ${picked.length === 0 ? 'disabled' : ''}>Add (${picked.length})</button>
          </div>
        </div>
      </div>
    `;
  }

  // Updates only the suggestion list and the hint (without re-rendering the whole
  // modal, so the input keeps focus while the user types).
  function updateGroupUI() {
    const suggestionsEl = overlay.querySelector('#group-suggestions');
    const hintEl = overlay.querySelector('#group-hint');
    if (!suggestionsEl || !hintEl) return;

    const matches = matchingGroups();
    suggestionsEl.innerHTML = matches
      .map((g) => {
        const repos = reposByGroup.get(g.id) || [];
        const sub =
          repos.length === 0
            ? 'empty group'
            : repos.slice(0, 3).join(', ') + (repos.length > 3 ? ` +${repos.length - 3}` : '');
        return `
          <div class="combo-item ${g.id === selectedGroupId ? 'selected' : ''}" data-group-id="${g.id}">
            <span class="combo-item-name">${escapeHtml(g.label)}</span>
            <span class="combo-item-sub">${escapeHtml(sub)}</span>
          </div>`;
      })
      .join('');
    suggestionsEl.style.display = matches.length ? 'block' : 'none';

    const q = groupText.trim();
    const em = exactMatch();
    if (!q) {
      hintEl.textContent = 'No group. Pick an existing one or type to create a new one.';
      hintEl.className = 'combo-hint';
    } else if (em) {
      const n = (reposByGroup.get(em.id) || []).length;
      hintEl.textContent = `Add to the existing group "${em.label}" (${n} repo(s) today).`;
      hintEl.className = 'combo-hint exists';
    } else {
      hintEl.textContent = `No group with that name — a new group "${q}" will be created.`;
      hintEl.className = 'combo-hint create';
    }
  }

  function rerender() {
    const input = overlay.querySelector('#group-input');
    if (input) groupText = input.value;
    overlay.innerHTML = modalHtml();
    wire();
  }

  // Resolves the final groupId: clicked suggestion > group with the exact name > create a new one.
  async function resolveGroupId() {
    const q = groupText.trim();
    if (!q) return '';
    if (selectedGroupId) {
      const g = groupOptions.find((o) => o.id === selectedGroupId);
      if (g && norm(g.label) === norm(q)) return selectedGroupId;
    }
    const em = exactMatch();
    if (em) return em.id;
    const created = await api.addGroup(q, null);
    return created.id;
  }

  function wire() {
    const groupInput = overlay.querySelector('#group-input');
    const suggestionsEl = overlay.querySelector('#group-suggestions');

    groupInput.addEventListener('input', () => {
      groupText = groupInput.value;
      selectedGroupId = null;
      updateGroupUI();
    });

    // mousedown (not click) to select before the input blurs.
    suggestionsEl.addEventListener('mousedown', (e) => {
      const item = e.target.closest('[data-group-id]');
      if (!item) return;
      e.preventDefault();
      const g = groupOptions.find((o) => o.id === item.dataset.groupId);
      if (!g) return;
      selectedGroupId = g.id;
      groupText = g.label;
      groupInput.value = g.label;
      updateGroupUI();
      groupInput.focus();
    });

    overlay.querySelector('#pick-folder-btn').addEventListener('click', async () => {
      try {
        const { repos, rejected } = await api.selectDirectories();
        let addedCount = 0;
        for (const p of repos) {
          if (!picked.includes(p)) {
            picked.push(p);
            addedCount++;
          }
        }
        if (rejected.length > 0) {
          const names = rejected.map((p) => p.split('/').filter(Boolean).pop() || p).join(', ');
          toastError('Folder(s) skipped', `Not a Git repository and holds no Git repositories: ${names}`);
        }
        if (addedCount > 0) {
          toastSuccess(`${addedCount} repository(ies) found`);
        }
      } catch (err) {
        toastError('Error opening the folder picker', err.message);
      }
      rerender();
    });

    overlay.querySelectorAll('[data-remove-index]').forEach((btn) => {
      btn.addEventListener('click', () => {
        picked.splice(Number(btn.dataset.removeIndex), 1);
        rerender();
      });
    });

    overlay.querySelector('[data-action="cancel"]').addEventListener('click', () => overlay.remove());
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) overlay.remove();
    });

    const confirmBtn = overlay.querySelector('[data-action="confirm"]');
    if (confirmBtn) {
      confirmBtn.addEventListener('click', async () => {
        let groupId;
        try {
          groupId = await resolveGroupId();
        } catch (err) {
          toastError('Error setting the group', err.message);
          return;
        }
        let successCount = 0;
        for (const p of picked) {
          try {
            await api.addProject({ path: p, groupId });
            successCount++;
          } catch (err) {
            toastError(`Error adding ${p}`, err.message);
          }
        }
        if (successCount > 0) toastSuccess(`${successCount} repository(ies) added`);
        overlay.remove();
        onDone();
      });
    }

    updateGroupUI();
  }

  overlay.innerHTML = modalHtml();
  wire();
}

// A minimal card: just the status color (dot) and the name. The details (branch,
// changes, ahead/behind, path) live in the right panel on click. The full
// path is in the tooltip; the actions (rename/remove) only on hover.
function renderCard(p, selectedPath) {
  const active = p.path === selectedPath;
  const statusTitle =
    `${p.currentBranch}` + (p.statusSummary && p.statusSummary !== 'Clean' ? ` • ${p.statusSummary}` : '');
  return `
    <div class="project-card ${active ? 'active' : ''}" data-path="${escapeHtml(p.path)}" draggable="true" title="${escapeHtml(p.path + ' — ' + statusTitle)}">
      <span class="status-dot ${statusClass(p)}" title="${escapeHtml(statusTitle)}"></span>
      <span class="project-card-name">${escapeHtml(p.name)}</span>
      <span class="project-card-menu">
        <button class="icon-btn" data-action="rename" data-path="${escapeHtml(p.path)}" title="Rename">✎</button>
        <button class="icon-btn" data-action="remove" data-path="${escapeHtml(p.path)}" title="Remove">🗑</button>
      </span>
    </div>
  `;
}
