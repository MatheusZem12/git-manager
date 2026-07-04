import * as api from '../services/git-api.js';
import { toastSuccess, toastError } from '../services/toast.js';

const selUnstaged = new Map();
const selStaged = new Map();
const activeFile = new Map();
const activeDiffTab = new Map();
const filterText = new Map();
const changesCache = new Map();

const TYPE_LABELS = {
  ADDED: 'Novo',
  MODIFIED: 'Modificado',
  DELETED: 'Deletado',
  RENAMED: 'Renomeado',
  CONFLICTING: 'Conflito',
  UNTRACKED: 'Não rastreado'
};

function getSet(map, repoPath) {
  if (!map.has(repoPath)) map.set(repoPath, new Set());
  return map.get(repoPath);
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

export async function renderStagingTab(container, repoPath) {
  container.innerHTML = `<div class="card">Carregando...</div>`;
  const changes = await api.getChanges(repoPath);
  changesCache.set(repoPath, changes);
  renderLayout(container, repoPath);
}

function renderLayout(container, repoPath) {
  const changes = changesCache.get(repoPath) || [];
  const filter = (filterText.get(repoPath) || '').toLowerCase();
  const filtered = filter ? changes.filter((c) => c.path.toLowerCase().includes(filter)) : changes;
  const unstaged = filtered.filter((c) => !c.staged);
  const staged = filtered.filter((c) => c.staged);
  const active = activeFile.get(repoPath);

  container.innerHTML = `
    <div class="staging-layout">
      <div class="staging-files">
        <div class="staging-filter">
          <input type="text" id="filter-input" placeholder="Filtrar arquivos..." value="${escapeHtml(filterText.get(repoPath) || '')}">
        </div>
        <div class="staging-sections">
          ${renderSection('unstaged', 'Não staged', unstaged, repoPath, active)}
          ${staged.length > 0 ? renderSection('staged', 'Staged', staged, repoPath, active) : ''}
        </div>
      </div>
      <div class="diff-panel" id="diff-panel"></div>
    </div>
    <div class="commit-bar">
      <input type="text" id="commit-message" placeholder="Mensagem de commit">
      <button class="btn btn-success" id="commit-btn" ${staged.length === 0 ? 'disabled' : ''}>Commit${staged.length > 0 ? ` (${staged.length})` : ''}</button>
    </div>
  `;

  wireEvents(container, repoPath);
  renderDiffPanel(container.querySelector('#diff-panel'), repoPath);
}

function renderSection(kind, title, files, repoPath, active) {
  const selSet = getSet(kind === 'unstaged' ? selUnstaged : selStaged, repoPath);
  const selectedCount = files.filter((f) => selSet.has(f.path)).length;
  const bulkAction = kind === 'unstaged' ? 'bulk-stage' : 'bulk-unstage';
  const bulkLabel = kind === 'unstaged' ? '↑ Stage' : '↓ Unstage';
  const bulkClass = kind === 'unstaged' ? 'btn-success' : 'btn-warning';

  return `
    <div class="file-section" data-kind="${kind}">
      <div class="file-section-header ${kind}">
        <span>${title} (${files.length})</span>
        ${
          files.length > 0
            ? `<button class="link-btn" data-action="select-all" data-kind="${kind}">Todos</button>
               <button class="link-btn" data-action="select-none" data-kind="${kind}">Nenhum</button>`
            : ''
        }
        <span style="flex: 1;"></span>
        ${
          selectedCount > 0
            ? `<button class="btn ${bulkClass} tiny" data-action="${bulkAction}">${bulkLabel} (${selectedCount})</button>`
            : ''
        }
      </div>
      ${files.map((f) => renderFileRow(f, kind, selSet.has(f.path), active)).join('')}
    </div>
  `;
}

function renderFileRow(f, kind, checked, active) {
  const isActive = active && active.path === f.path && active.staged === f.staged;
  return `
    <div class="file-row ${isActive ? 'active' : ''}" data-path="${escapeHtml(f.path)}" data-staged="${f.staged}">
      <input type="checkbox" data-check="${kind}" data-path="${escapeHtml(f.path)}" ${checked ? 'checked' : ''}>
      <span class="file-path ${f.type}">${escapeHtml(f.path)}</span>
      <span class="type-badge ${f.type}">${TYPE_LABELS[f.type] || f.type}</span>
    </div>
  `;
}

function wireEvents(container, repoPath) {
  const rerender = () => renderLayout(container, repoPath);
  const refetch = () => renderStagingTab(container, repoPath);

  container.querySelector('#filter-input').addEventListener('input', (e) => {
    filterText.set(repoPath, e.target.value);
    rerender();
  });

  container.querySelectorAll('[data-check]').forEach((cb) => {
    cb.addEventListener('click', (e) => e.stopPropagation());
    cb.addEventListener('change', () => {
      const kind = cb.dataset.check;
      const set = getSet(kind === 'unstaged' ? selUnstaged : selStaged, repoPath);
      if (cb.checked) set.add(cb.dataset.path);
      else set.delete(cb.dataset.path);
      rerender();
    });
  });

  container.querySelectorAll('[data-action="select-all"]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const kind = btn.dataset.kind;
      const changes = changesCache.get(repoPath) || [];
      const files = changes.filter((c) => (kind === 'unstaged' ? !c.staged : c.staged));
      const set = getSet(kind === 'unstaged' ? selUnstaged : selStaged, repoPath);
      files.forEach((f) => set.add(f.path));
      rerender();
    });
  });

  container.querySelectorAll('[data-action="select-none"]').forEach((btn) => {
    btn.addEventListener('click', () => {
      getSet(btn.dataset.kind === 'unstaged' ? selUnstaged : selStaged, repoPath).clear();
      rerender();
    });
  });

  container.querySelectorAll('.file-row').forEach((row) => {
    row.addEventListener('click', () => {
      activeFile.set(repoPath, { path: row.dataset.path, staged: row.dataset.staged === 'true' });
      activeDiffTab.set(repoPath, 'diff');
      rerender();
    });
  });

  const bulkStageBtn = container.querySelector('[data-action="bulk-stage"]');
  if (bulkStageBtn) {
    bulkStageBtn.addEventListener('click', async () => {
      const files = [...getSet(selUnstaged, repoPath)];
      try {
        await api.stageFiles(repoPath, files);
        getSet(selUnstaged, repoPath).clear();
        toastSuccess(`${files.length} arquivo(s) staged`);
      } catch (err) {
        toastError('Erro ao dar stage', err.message);
      }
      refetch();
    });
  }

  const bulkUnstageBtn = container.querySelector('[data-action="bulk-unstage"]');
  if (bulkUnstageBtn) {
    bulkUnstageBtn.addEventListener('click', async () => {
      const files = [...getSet(selStaged, repoPath)];
      try {
        await api.unstageFiles(repoPath, files);
        getSet(selStaged, repoPath).clear();
        toastSuccess(`${files.length} arquivo(s) unstaged`);
      } catch (err) {
        toastError('Erro ao dar unstage', err.message);
      }
      refetch();
    });
  }

  const commitBtn = container.querySelector('#commit-btn');
  const messageInput = container.querySelector('#commit-message');
  const doCommit = async () => {
    const message = messageInput.value.trim();
    if (!message) {
      toastError('Escreva uma mensagem de commit');
      return;
    }
    try {
      await api.commit(repoPath, message);
      toastSuccess('Commit realizado');
      activeFile.delete(repoPath);
      refetch();
    } catch (err) {
      toastError('Erro ao commitar', err.message);
    }
  };
  commitBtn.addEventListener('click', doCommit);
  messageInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doCommit();
  });
}

async function renderDiffPanel(panel, repoPath) {
  const active = activeFile.get(repoPath);
  if (!active) {
    panel.innerHTML = `<div class="diff-empty">Selecione um arquivo para ver o diff</div>`;
    return;
  }

  const tab = activeDiffTab.get(repoPath) || 'diff';
  panel.innerHTML = `
    <div class="diff-panel-header">
      <span class="file-path ${active.staged ? '' : ''}">${escapeHtml(active.path)}</span>
      <button class="btn btn-ghost tiny" id="open-external-btn">Abrir arquivo</button>
    </div>
    <div class="diff-tabs">
      <button class="diff-tab ${tab === 'diff' ? 'active' : ''}" data-difftab="diff">Diff</button>
      <button class="diff-tab ${tab === 'file' ? 'active' : ''}" data-difftab="file">Arquivo</button>
    </div>
    <div class="diff-body" id="diff-body">Carregando...</div>
  `;

  panel.querySelector('#open-external-btn').addEventListener('click', () => {
    api.openPath(`${repoPath}/${active.path}`);
  });

  panel.querySelectorAll('.diff-tab').forEach((btn) => {
    btn.addEventListener('click', () => {
      activeDiffTab.set(repoPath, btn.dataset.difftab);
      renderDiffPanel(panel, repoPath);
    });
  });

  const body = panel.querySelector('#diff-body');
  if (tab === 'diff') {
    const diffText = await api.getFileDiff(repoPath, active.path, active.staged);
    body.innerHTML = renderDiffHtml(diffText);
  } else {
    const content = await api.getFileContent(repoPath, active.path);
    body.innerHTML = renderFileHtml(content);
  }
}

function parseUnifiedDiff(diffText) {
  const lines = diffText.split('\n');
  const rows = [];
  let oldLine = 0;
  let newLine = 0;

  for (const line of lines) {
    if (
      line.startsWith('diff --git') ||
      line.startsWith('index ') ||
      line.startsWith('--- ') ||
      line.startsWith('+++ ')
    ) {
      continue;
    }
    const hunkMatch = line.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunkMatch) {
      oldLine = parseInt(hunkMatch[1], 10);
      newLine = parseInt(hunkMatch[2], 10);
      rows.push({ type: 'hunk', text: line });
      continue;
    }
    if (line.startsWith('+')) {
      rows.push({ type: 'add', oldNo: '', newNo: newLine++, text: line.slice(1) });
    } else if (line.startsWith('-')) {
      rows.push({ type: 'del', oldNo: oldLine++, newNo: '', text: line.slice(1) });
    } else if (line.startsWith(' ')) {
      rows.push({ type: 'ctx', oldNo: oldLine++, newNo: newLine++, text: line.slice(1) });
    }
  }
  return rows;
}

function renderDiffHtml(diffText) {
  if (!diffText || diffText.trim() === '') {
    return `<div class="diff-empty">Nenhuma alteração detectada.</div>`;
  }
  const rows = parseUnifiedDiff(diffText);
  if (rows.length === 0) {
    return `<div class="diff-empty">Sem diferenças textuais.</div>`;
  }
  return rows
    .map((r) => {
      if (r.type === 'hunk') {
        return `<div class="diff-line hunk"><span class="line-no"></span><span class="line-no"></span><span class="line-content">${escapeHtml(r.text)}</span></div>`;
      }
      return `<div class="diff-line ${r.type}"><span class="line-no">${r.oldNo}</span><span class="line-no">${r.newNo}</span><span class="line-content">${escapeHtml(r.text)}</span></div>`;
    })
    .join('');
}

function renderFileHtml(content) {
  if (content === null) {
    return `<div class="diff-empty">(arquivo não existe no disco)</div>`;
  }
  return content
    .split('\n')
    .map(
      (line, i) =>
        `<div class="diff-line ctx"><span class="line-no">${i + 1}</span><span class="line-content">${escapeHtml(line)}</span></div>`
    )
    .join('');
}
