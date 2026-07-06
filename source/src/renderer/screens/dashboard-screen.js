import * as api from '../services/git-api.js';
import { confirmDialog, promptDialog } from '../services/dialogs.js';
import { toastSuccess, toastError } from '../services/toast.js';

let searchQuery = '';
// Estado de colapso por id de grupo. A seção "Sem grupo" usa a chave '' (ids de
// grupos reais nunca são vazios).
const collapsedGroups = new Set();
const UNGROUPED = '';

function isAvailable(p) {
  return p.existsOnDisk && p.hasGit;
}

function hasChanges(p) {
  return isAvailable(p) && (p.statusSummary !== 'Limpo' || p.ahead > 0 || p.behind > 0);
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
  // Preserva a posição de scroll da lista entre re-renders (ex: ao atualizar).
  const prevScroll = container.querySelector('.project-list')?.scrollTop || 0;
  // "Carregando..." só no primeiro load. Nos refreshes seguintes mantemos o
  // conteúdo atual visível durante o fetch e trocamos de uma vez só — sem piscar.
  if (!container.querySelector('.project-list')) {
    container.innerHTML = `<div class="empty-state">Carregando...</div>`;
  }
  let projects;
  let groups;
  try {
    [projects, groups] = await Promise.all([api.listProjects(), api.listGroups()]);
  } catch (err) {
    container.innerHTML = `<div class="empty-state">Erro ao carregar projetos: ${escapeHtml(err.message)}</div>`;
    return;
  }

  // `currentSelected` acompanha o repo selecionado sem depender de re-render: ao
  // clicar num card só atualizamos o destaque no lugar (mantém o scroll da nav e
  // evita re-validar todos os repos). Um refresh completo só acontece em ações
  // de grupo/add/remove ou no botão "Atualizar".
  let currentSelected = selectedPath;
  const refresh = () => renderSidebar(container, { selectedPath: currentSelected, onSelect, onRemoved });

  const total = projects.length;
  const ok = projects.filter((p) => isAvailable(p) && !hasChanges(p)).length;
  const warn = projects.filter((p) => hasChanges(p)).length;
  const danger = projects.filter((p) => !isAvailable(p)).length;

  // --- Índices da árvore de grupos + projetos ---
  const filtered = projects.filter(matchesSearch);

  const childrenMap = new Map(); // parentId ('' = topo) -> [grupo]
  for (const g of groups) {
    const key = g.parentId || '';
    if (!childrenMap.has(key)) childrenMap.set(key, []);
    childrenMap.get(key).push(g);
  }
  for (const arr of childrenMap.values()) arr.sort((a, b) => a.name.localeCompare(b.name));

  const projectsByGroup = new Map(); // groupId ('' = sem grupo) -> [projeto]
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
  // Evita ciclos ao mover grupos: alvo não pode ser o próprio grupo nem um
  // descendente dele.
  function wouldCreateCycle(movingId, targetId) {
    let cur = targetId;
    while (cur) {
      if (cur === movingId) return true;
      cur = parentOf.get(cur) || '';
    }
    return false;
  }

  function renderGroupNode(group) {
    // Ao buscar, tudo aparece expandido pra facilitar ver os resultados.
    const collapsed = !searchQuery && collapsedGroups.has(group.id);
    const count = countRepos(group.id);
    const subGroups = childGroupsOf(group.id).filter((g) => !searchQuery || subtreeHasMatch(g.id));
    // Os filhos são sempre renderizados (só escondidos com `hidden` quando
    // recolhido), pra que recolher/expandir seja um toggle instantâneo no DOM,
    // sem re-render nem re-fetch (que causavam a piscada na barra).
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
            <button class="icon-btn" data-group-action="add-sub" data-group-id="${group.id}" title="Novo subgrupo">＋</button>
            <button class="icon-btn" data-group-action="rename" data-group-id="${group.id}" title="Renomear grupo">✎</button>
            <button class="icon-btn" data-group-action="remove" data-group-id="${group.id}" title="Excluir grupo">🗑</button>
          </span>
        </div>
        ${childrenHtml}
      </div>
    `;
  }

  function renderUngrouped() {
    const ps = projectsIn(UNGROUPED);
    // Ao buscar, só mostra se houver resultado sem grupo. Sem busca, mostra
    // sempre que existirem repos soltos ou grupos (pra servir de alvo de
    // "arrastar pra fora").
    if (searchQuery && ps.length === 0) return '';
    if (!searchQuery && ps.length === 0 && groups.length === 0) return '';
    const collapsed = !searchQuery && collapsedGroups.has(UNGROUPED);
    return `
      <div class="group-node" data-group-id="">
        <div class="group-header" data-group-id="" draggable="false">
          <span class="group-caret">${collapsed ? '▸' : '▾'}</span>
          <span class="group-name">Sem grupo</span>
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
        <button class="icon-btn sidebar-collapse-btn" id="collapse-sidebar-btn" title="Recolher barra lateral">⯇</button>
      </div>
      <div class="search-box">
        <input type="text" id="search-input" placeholder="Buscar por nome ou caminho..." value="${escapeHtml(searchQuery)}">
      </div>
    </div>
    <div class="stats-bar">
      <div class="stat"><div class="stat-value">${total}</div><div class="stat-label">Total</div></div>
      <div class="stat ok"><div class="stat-value">${ok}</div><div class="stat-label">OK</div></div>
      <div class="stat warn"><div class="stat-value">${warn}</div><div class="stat-label">Alterações</div></div>
      <div class="stat danger"><div class="stat-value">${danger}</div><div class="stat-label">Indisponível</div></div>
    </div>
    <div class="project-list">
      ${
        total === 0 && groups.length === 0
          ? `<div class="empty-state"><div class="empty-icon">📭</div>Nenhum repositório cadastrado.<br>Clique em "Adicionar repositório" abaixo.</div>`
          : topGroups.map(renderGroupNode).join('') + renderUngrouped()
      }
    </div>
    <div class="sidebar-footer">
      <button class="btn btn-ghost" id="add-group-btn" style="width: 100%; margin-bottom: 8px;">+ Novo grupo</button>
      <button class="btn btn-primary" id="add-repo-btn" style="width: 100%;">+ Adicionar repositório</button>
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

  // --- Colapsar/expandir grupos (clique no header, exceto nas ações) ---
  // Toggle direto no DOM: esconde/mostra os filhos e vira a seta, sem re-render
  // nem re-fetch (que causavam a piscada). Mantém scroll e estado intactos.
  container.querySelectorAll('.group-header').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (e.target.closest('.group-actions')) return;
      const id = el.dataset.groupId;
      const collapsed = !collapsedGroups.has(id); // estado após o toggle
      if (collapsed) collapsedGroups.add(id);
      else collapsedGroups.delete(id);

      const node = el.closest('.group-node');
      const children = node.querySelector(':scope > .group-children');
      const caret = el.querySelector('.group-caret');
      if (caret) caret.textContent = collapsed ? '▸' : '▾';
      if (children) children.hidden = collapsed;
    });
  });

  // --- Ações de grupo: novo subgrupo, renomear, excluir ---
  container.querySelectorAll('[data-group-action="add-sub"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const name = await promptDialog({ title: 'Novo subgrupo', label: 'Nome do subgrupo', placeholder: 'ex: cliente X' });
      if (!name) return;
      try {
        await api.addGroup(name, el.dataset.groupId);
        collapsedGroups.delete(el.dataset.groupId); // expande o pai pra mostrar o novo
        toastSuccess('Subgrupo criado');
        refresh();
      } catch (err) {
        toastError('Erro ao criar subgrupo', err.message);
      }
    });
  });

  container.querySelectorAll('[data-group-action="rename"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const g = groups.find((grp) => grp.id === el.dataset.groupId);
      const name = await promptDialog({ title: 'Renomear grupo', label: 'Nome', initialValue: g ? g.name : '' });
      if (!name) return;
      try {
        await api.renameGroup(el.dataset.groupId, name);
        toastSuccess('Grupo renomeado');
        refresh();
      } catch (err) {
        toastError('Erro ao renomear grupo', err.message);
      }
    });
  });

  container.querySelectorAll('[data-group-action="remove"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const g = groups.find((grp) => grp.id === el.dataset.groupId);
      const ok2 = await confirmDialog({
        title: 'Excluir grupo',
        message: `Excluir o grupo "${g ? g.name : ''}"? Os repositórios e subgrupos dentro dele sobem para o grupo pai (ou "Sem grupo"). Nenhum arquivo é apagado do disco.`,
        confirmLabel: 'Excluir'
      });
      if (!ok2) return;
      try {
        await api.removeGroup(el.dataset.groupId);
        toastSuccess('Grupo excluído');
        refresh();
      } catch (err) {
        toastError('Erro ao excluir grupo', err.message);
      }
    });
  });

  container.querySelector('#add-group-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'Novo grupo', label: 'Nome do grupo', placeholder: 'ex: trabalho' });
    if (!name) return;
    try {
      await api.addGroup(name, null);
      toastSuccess('Grupo criado');
      refresh();
    } catch (err) {
      toastError('Erro ao criar grupo', err.message);
    }
  });

  // --- Cartões de projeto: selecionar, renomear, remover ---
  container.querySelectorAll('.project-card').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (e.target.closest('.project-card-menu')) return;
      // Só troca o destaque e atualiza o painel da direita — sem re-render da
      // nav (mantém o scroll e não re-valida todos os repos).
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
      const newName = await promptDialog({ title: 'Renomear projeto', label: 'Nome', initialValue: p.name });
      if (!newName) return;
      try {
        await api.updateProject(p.path, { name: newName });
        toastSuccess('Projeto renomeado');
        refresh();
      } catch (err) {
        toastError('Erro ao renomear', err.message);
      }
    });
  });

  container.querySelectorAll('[data-action="remove"]').forEach((el) => {
    el.addEventListener('click', async (e) => {
      e.stopPropagation();
      const p = projects.find((proj) => proj.path === el.dataset.path);
      const ok2 = await confirmDialog({
        title: 'Remover projeto',
        message: `Remover "${p.name}" da lista? Isso não apaga os arquivos do disco, só desassocia do Git Manager.`,
        confirmLabel: 'Remover'
      });
      if (!ok2) return;
      try {
        await api.removeProject(p.path);
        toastSuccess('Projeto removido');
        if (selectedPath === p.path && onRemoved) {
          await onRemoved();
        } else {
          refresh();
        }
      } catch (err) {
        toastError('Erro ao remover', err.message);
      }
    });
  });

  wireDragAndDrop(container, { wouldCreateCycle, refresh });

  container.querySelector('#add-repo-btn').addEventListener('click', () => openAddRepoModal(groups, projects, refresh));
}

// Drag & drop: arrasta um cartão de repositório (ou um grupo) e solta sobre um
// grupo (ou sobre "Sem grupo") para movê-lo. Cada `.group-node` é uma zona de
// soltura; usamos stopPropagation pra que só o nó mais interno sob o cursor
// reaja (nós aninhados).
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
            toastError('Movimento inválido', 'Não dá pra mover um grupo para dentro de si mesmo.');
            return;
          }
          await api.reparentGroup(payload.id, targetGroupId || null);
        }
        refresh();
      } catch (err) {
        toastError('Erro ao mover', err.message);
      }
    });
  });
}

// Achata a árvore de grupos numa lista com rótulos indentados ("Pai / Filho"),
// pra popular o combobox de grupo do modal de adicionar repositório.
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

// Multi-seleção de pastas é quebrada no Linux (o Chromium só ativa multi-select
// pra arquivos, nunca pra pastas), então não dependemos do diálogo nativo pra
// isso. Em vez disso, cada pasta escolhida é resolvida no processo principal
// para os repos Git que ela contém: se a própria pasta é um repo, entra ela; se
// não, entram todos os repos dos subdiretórios imediatos. Assim "selecionar
// vários" = escolher a pasta-pai. Só repos Git válidos entram na lista (o resto
// é rejeitado com aviso), e o usuário ainda pode chamar o seletor quantas vezes
// quiser, acumulando numa lista revisável antes de confirmar.
function openAddRepoModal(groups, projects, onDone) {
  const picked = [];
  // Combobox de grupo: o usuário pode escolher um grupo existente OU digitar um
  // nome novo. Se o que ele digitar casar com um grupo existente, o repo entra
  // nesse grupo; se não casar com nenhum, um novo grupo (de topo) é criado.
  let groupText = '';
  let selectedGroupId = null; // definido quando ele clica numa sugestão
  const groupOptions = flattenGroups(groups);

  // Nomes dos repos por grupo, pra mostrar nas sugestões o que já existe lá.
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
        <h3>Adicionar repositório(s)</h3>
        <p>Selecione uma pasta que já é um repositório Git, <strong>ou</strong> uma pasta que contenha vários repositórios (todos serão detectados de uma vez). Você pode repetir a seleção quantas vezes quiser antes de confirmar.</p>
        <div class="form-group">
          <label>Grupo (opcional, aplicado a todos)</label>
          <div class="combo">
            <input type="text" id="group-input" autocomplete="off" placeholder="Selecionar grupo existente ou digitar um novo..." value="${escapeHtml(groupText)}">
            <div class="combo-suggestions" id="group-suggestions"></div>
          </div>
          <div class="combo-hint" id="group-hint"></div>
        </div>
        <div class="modal-picked-list">
          ${
            picked.length === 0
              ? '<p class="hint">Nenhuma pasta selecionada ainda.</p>'
              : picked
                  .map(
                    (p, i) => `
            <div class="modal-picked-item">
              <span class="path">${escapeHtml(p)}</span>
              <button class="icon-btn" data-remove-index="${i}" title="Remover">✕</button>
            </div>
          `
                  )
                  .join('')
          }
        </div>
        <div class="modal-actions" style="justify-content: space-between;">
          <button class="btn btn-ghost compact" id="pick-folder-btn">+ Selecionar pasta(s)</button>
          <div style="display: flex; gap: 8px;">
            <button class="btn btn-ghost" data-action="cancel">Cancelar</button>
            <button class="btn btn-primary" data-action="confirm" ${picked.length === 0 ? 'disabled' : ''}>Adicionar (${picked.length})</button>
          </div>
        </div>
      </div>
    `;
  }

  // Atualiza só a lista de sugestões e a dica (sem re-renderizar o modal todo,
  // pra não perder o foco do input enquanto o usuário digita).
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
            ? 'grupo vazio'
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
      hintEl.textContent = 'Sem grupo. Selecione um existente ou digite para criar um novo.';
      hintEl.className = 'combo-hint';
    } else if (em) {
      const n = (reposByGroup.get(em.id) || []).length;
      hintEl.textContent = `Adicionar ao grupo existente "${em.label}" (${n} repo(s) hoje).`;
      hintEl.className = 'combo-hint exists';
    } else {
      hintEl.textContent = `Nenhum grupo com esse nome — será criado um novo grupo "${q}".`;
      hintEl.className = 'combo-hint create';
    }
  }

  function rerender() {
    const input = overlay.querySelector('#group-input');
    if (input) groupText = input.value;
    overlay.innerHTML = modalHtml();
    wire();
  }

  // Resolve o groupId final: sugestão clicada > grupo com nome exato > cria novo.
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

    // mousedown (não click) pra selecionar antes do blur do input.
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
          toastError('Pasta(s) ignorada(s)', `Não é um repositório Git nem contém repositórios Git: ${names}`);
        }
        if (addedCount > 0) {
          toastSuccess(`${addedCount} repositório(s) encontrado(s)`);
        }
      } catch (err) {
        toastError('Erro ao abrir o seletor de pastas', err.message);
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
          toastError('Erro ao definir o grupo', err.message);
          return;
        }
        let successCount = 0;
        for (const p of picked) {
          try {
            await api.addProject({ path: p, groupId });
            successCount++;
          } catch (err) {
            toastError(`Erro ao adicionar ${p}`, err.message);
          }
        }
        if (successCount > 0) toastSuccess(`${successCount} repositório(s) adicionado(s)`);
        overlay.remove();
        onDone();
      });
    }

    updateGroupUI();
  }

  overlay.innerHTML = modalHtml();
  wire();
}

// Card minimalista: só a cor do status (dot) e o nome. Os detalhes (branch,
// alterações, ahead/behind, caminho) ficam no painel da direita ao clicar. O
// caminho completo fica no tooltip; as ações (renomear/remover) só no hover.
function renderCard(p, selectedPath) {
  const active = p.path === selectedPath;
  const statusTitle =
    `${p.currentBranch}` + (p.statusSummary && p.statusSummary !== 'Limpo' ? ` • ${p.statusSummary}` : '');
  return `
    <div class="project-card ${active ? 'active' : ''}" data-path="${escapeHtml(p.path)}" draggable="true" title="${escapeHtml(p.path + ' — ' + statusTitle)}">
      <span class="status-dot ${statusClass(p)}" title="${escapeHtml(statusTitle)}"></span>
      <span class="project-card-name">${escapeHtml(p.name)}</span>
      <span class="project-card-menu">
        <button class="icon-btn" data-action="rename" data-path="${escapeHtml(p.path)}" title="Renomear">✎</button>
        <button class="icon-btn" data-action="remove" data-path="${escapeHtml(p.path)}" title="Remover">🗑</button>
      </span>
    </div>
  `;
}
