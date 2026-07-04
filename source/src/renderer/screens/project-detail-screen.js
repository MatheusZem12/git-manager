import * as api from '../services/git-api.js';
import { promptDialog, confirmDialog } from '../services/dialogs.js';
import { toastSuccess, toastError } from '../services/toast.js';
import { renderStagingTab } from './staging-tab.js';

const TABS = [
  { id: 'overview', label: 'Visão Geral' },
  { id: 'commit', label: 'Commit' },
  { id: 'history', label: 'Histórico' },
  { id: 'tags', label: 'Tags' },
  { id: 'stash', label: 'Stash' }
];

const tabState = new Map();
const outputLog = new Map();

function appendLog(repoPath, line) {
  if (!outputLog.has(repoPath)) outputLog.set(repoPath, []);
  const lines = outputLog.get(repoPath);
  lines.push(line);
  if (lines.length > 300) lines.shift();
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

function formatDate(isoString) {
  const d = new Date(isoString);
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function renderWelcome(container) {
  container.innerHTML = `
    <div class="welcome">
      <div>
        <div class="welcome-icon">⑂</div>
        <div>Selecione um repositório à esquerda</div>
      </div>
    </div>
  `;
}

export async function renderProjectDetail(container, repoPath, onRemoved) {
  const projectName = repoPath.split('/').filter(Boolean).pop();
  const activeTab = tabState.get(repoPath) || 'overview';

  container.innerHTML = `
    <div class="detail-header">
      <h2>${escapeHtml(projectName)}</h2>
      <span class="detail-path">${escapeHtml(repoPath)}</span>
      <span class="spacer"></span>
      <button class="btn btn-ghost compact" id="refresh-btn">⟳ Atualizar</button>
    </div>
    <div class="tabs">
      ${TABS.map(
        (t) => `<button class="tab-btn ${t.id === activeTab ? 'active' : ''}" data-tab="${t.id}">${t.label}</button>`
      ).join('')}
    </div>
    <div class="tab-content ${activeTab === 'commit' ? 'no-scroll' : ''}" id="tab-body"></div>
  `;

  const tabBody = container.querySelector('#tab-body');

  container.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      tabState.set(repoPath, btn.dataset.tab);
      renderProjectDetail(container, repoPath, onRemoved);
    });
  });

  container
    .querySelector('#refresh-btn')
    .addEventListener('click', () => renderProjectDetail(container, repoPath, onRemoved));

  const check = await api.checkProject(repoPath).catch(() => null);
  if (check && (!check.existsOnDisk || !check.hasGit)) {
    tabBody.innerHTML = `
      <div class="card">
        <h3>Repositório indisponível</h3>
        <p class="hint">${
          !check.existsOnDisk
            ? 'A pasta não existe mais nesse caminho.'
            : 'A pasta existe, mas não contém um repositório Git válido (.git).'
        }</p>
        <div class="card-row" style="margin-top: 16px;">
          <button class="btn btn-danger compact" id="remove-unavailable-btn">Remover da lista</button>
        </div>
      </div>
    `;
    tabBody.querySelector('#remove-unavailable-btn').addEventListener('click', async () => {
      const ok = await confirmDialog({
        title: 'Remover projeto',
        message: `Remover "${projectName}" da lista? Isso não apaga nada do disco.`
      });
      if (!ok) return;
      await api.removeProject(repoPath);
      toastSuccess('Projeto removido');
      if (onRemoved) onRemoved();
    });
    return;
  }

  try {
    switch (activeTab) {
      case 'overview':
        await renderOverviewTab(tabBody, repoPath);
        break;
      case 'commit':
        await renderStagingTab(tabBody, repoPath);
        break;
      case 'history':
        await renderHistoryTab(tabBody, repoPath);
        break;
      case 'tags':
        await renderTagsTab(tabBody, repoPath);
        break;
      case 'stash':
        await renderStashTab(tabBody, repoPath);
        break;
    }
  } catch (err) {
    tabBody.innerHTML = `<div class="card">Erro ao carregar: ${escapeHtml(err.message)}</div>`;
  }
}

async function renderOverviewTab(container, repoPath) {
  const [status, sync, branches] = await Promise.all([
    api.getStatus(repoPath),
    api.getSyncStatus(repoPath),
    api.getBranches(repoPath)
  ]);

  const localBranches = branches.filter((b) => !b.remote);
  const logLines = outputLog.get(repoPath) || [];

  container.innerHTML = `
    <div class="card">
      <div class="card-row" style="justify-content: space-between;">
        <div>
          <div class="hint">Branch atual</div>
          <div style="font-size: 20px; font-weight: 700;">${escapeHtml(status.branch)}</div>
        </div>
        <div>
          <div class="hint">HEAD</div>
          <div style="font-family: monospace;">${status.head ? status.head.slice(0, 7) : 'N/A'}</div>
        </div>
      </div>
    </div>

    <div class="card">
      <h3>Trocar de branch</h3>
      <div class="card-row">
        <select id="branch-select" style="flex: 1;">
          ${localBranches
            .map((b) => `<option value="${b.name}" ${b.name === status.branch ? 'selected' : ''}>${b.name}</option>`)
            .join('')}
        </select>
        <button class="btn btn-primary compact" id="checkout-btn">Checkout</button>
        <button class="btn btn-success compact" id="new-branch-btn">+ Nova branch</button>
      </div>
    </div>

    <div class="card">
      <h3>Sincronização</h3>
      <p class="hint" style="margin-bottom: 12px;">
        ${
          !sync.hasRemote
            ? 'Nenhum remote configurado.'
            : sync.ahead === 0 && sync.behind === 0
              ? '✓ Atualizado com o remote.'
              : `${sync.ahead > 0 ? `${sync.ahead} commit(s) à frente` : ''} ${sync.behind > 0 ? `${sync.behind} commit(s) atrás` : ''}`
        }
      </p>
      <div class="card-row">
        <button class="btn btn-primary compact" id="push-btn" ${!sync.hasRemote || sync.ahead <= 0 ? 'disabled' : ''}>↑ Push</button>
        <button class="btn btn-success compact" id="pull-btn" ${!sync.hasRemote || sync.behind <= 0 ? 'disabled' : ''}>↓ Pull</button>
        <button class="btn btn-info compact" id="fetch-btn" ${!sync.hasRemote ? 'disabled' : ''}>⟲ Fetch</button>
      </div>
    </div>

    <div class="card">
      <h3>Output</h3>
      <div class="terminal" id="terminal">${escapeHtml(logLines.join('\n')) || '(nenhum comando executado ainda)'}</div>
      <div class="card-row" style="margin-top: 8px;">
        <button class="btn btn-ghost tiny" id="copy-output-btn">Copiar</button>
        <button class="btn btn-ghost tiny" id="clear-output-btn">Limpar</button>
      </div>
    </div>
  `;

  const rerender = () => renderOverviewTab(container, repoPath);

  container.querySelector('#checkout-btn').addEventListener('click', async () => {
    const branch = container.querySelector('#branch-select').value;
    try {
      await api.checkout(repoPath, branch);
      appendLog(repoPath, `$ git checkout ${branch}\nOK`);
      toastSuccess('Checkout realizado');
    } catch (err) {
      appendLog(repoPath, `❌ Erro: ${err.message}`);
      toastError('Erro no checkout', err.message);
    }
    rerender();
  });

  container.querySelector('#new-branch-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'Nova branch', label: 'Nome da branch' });
    if (!name) return;
    try {
      await api.createBranch(repoPath, name);
      appendLog(repoPath, `$ git checkout -b ${name}\nOK`);
      toastSuccess('Branch criada');
    } catch (err) {
      appendLog(repoPath, `❌ Erro: ${err.message}`);
      toastError('Erro ao criar branch', err.message);
    }
    rerender();
  });

  container.querySelector('#push-btn').addEventListener('click', () => runSyncAction(repoPath, 'push', rerender));
  container.querySelector('#pull-btn').addEventListener('click', () => runSyncAction(repoPath, 'pull', rerender));
  container.querySelector('#fetch-btn').addEventListener('click', () => runSyncAction(repoPath, 'fetch', rerender));

  container.querySelector('#copy-output-btn').addEventListener('click', () => {
    navigator.clipboard.writeText(logLines.join('\n'));
    toastSuccess('Output copiado');
  });
  container.querySelector('#clear-output-btn').addEventListener('click', () => {
    outputLog.set(repoPath, []);
    rerender();
  });
}

async function runSyncAction(repoPath, action, rerender) {
  try {
    await api[action](repoPath);
    appendLog(repoPath, `$ git ${action}\nOK: concluído.`);
    toastSuccess(`${action} concluído`);
  } catch (err) {
    let detail = err.message;
    if (/permission denied|publickey/i.test(detail)) {
      detail += '\nDica: verifique sua chave SSH (~/.ssh) e se ela está configurada no serviço remoto.';
    }
    appendLog(repoPath, `$ git ${action}\n❌ Erro: ${detail}`);
    toastError(`Erro no ${action}`, err.message);
  }
  rerender();
}

async function renderHistoryTab(container, repoPath) {
  container.innerHTML = `<div class="card">Carregando...</div>`;
  const commits = await api.getCommits(repoPath, 100);
  container.innerHTML = `
    <div class="card" style="max-width: 900px;">
      <h3>Histórico de commits (branch atual)</h3>
      ${
        commits.length === 0
          ? '<p class="hint">Nenhum commit ainda.</p>'
          : commits
              .map(
                (c) => `
        <div class="list-item">
          <span style="font-size: 18px;">●</span>
          <div class="list-item-main">
            <div class="list-item-title">${escapeHtml(c.message)}</div>
            <div class="list-item-sub">${c.shortId} · ${escapeHtml(c.authorName)} · ${formatDate(c.date)}</div>
          </div>
        </div>
      `
              )
              .join('')
      }
    </div>
  `;
}

async function renderTagsTab(container, repoPath) {
  container.innerHTML = `<div class="card">Carregando...</div>`;
  const tags = await api.getTags(repoPath);
  container.innerHTML = `
    <div class="card" style="max-width: 900px;">
      <div class="card-row" style="justify-content: space-between; margin-bottom: 12px;">
        <h3 style="margin: 0;">Tags</h3>
        <button class="btn btn-primary compact" id="new-tag-btn">+ Nova tag</button>
      </div>
      ${
        tags.length === 0
          ? '<p class="hint">Nenhuma tag.</p>'
          : tags
              .map(
                (t) => `
        <div class="list-item">
          <span>🏷</span>
          <div class="list-item-main"><div class="list-item-title">${escapeHtml(t)}</div></div>
          <button class="btn btn-danger tiny" data-action="delete-tag" data-name="${escapeHtml(t)}">Excluir</button>
        </div>
      `
              )
              .join('')
      }
    </div>
  `;

  container.querySelector('#new-tag-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'Nova tag', label: 'Nome da tag' });
    if (!name) return;
    const message = await promptDialog({ title: 'Mensagem da tag (opcional)', label: 'Mensagem' });
    if (message === null) return;
    try {
      await api.createTag(repoPath, name, message);
      toastSuccess('Tag criada');
    } catch (err) {
      toastError('Erro ao criar tag', err.message);
    }
    renderTagsTab(container, repoPath);
  });

  container.querySelectorAll('[data-action="delete-tag"]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const ok = await confirmDialog({ title: 'Excluir tag', message: `Excluir a tag "${btn.dataset.name}"?` });
      if (!ok) return;
      try {
        await api.deleteTag(repoPath, btn.dataset.name);
        toastSuccess('Tag removida');
      } catch (err) {
        toastError('Erro ao excluir tag', err.message);
      }
      renderTagsTab(container, repoPath);
    });
  });
}

async function renderStashTab(container, repoPath) {
  container.innerHTML = `<div class="card">Carregando...</div>`;
  const stashes = await api.getStashes(repoPath);
  container.innerHTML = `
    <div class="card" style="max-width: 900px;">
      <h3>Stash</h3>
      <div class="card-row" style="margin-bottom: 16px;">
        <button class="btn btn-primary compact" id="stash-save-btn">Salvar stash</button>
        <button class="btn btn-info compact" id="stash-apply-btn" ${stashes.length === 0 ? 'disabled' : ''}>Aplicar</button>
        <button class="btn btn-success compact" id="stash-pop-btn" ${stashes.length === 0 ? 'disabled' : ''}>Pop</button>
      </div>
      ${
        stashes.length === 0
          ? '<p class="hint">Nenhum stash.</p>'
          : stashes
              .map(
                (s) => `
        <div class="list-item"><span>📦</span><div class="list-item-main"><div class="list-item-title">${escapeHtml(s)}</div></div></div>
      `
              )
              .join('')
      }
    </div>
  `;

  container.querySelector('#stash-save-btn').addEventListener('click', async () => {
    const message = await promptDialog({ title: 'Salvar stash', label: 'Mensagem (opcional)' });
    if (message === null) return;
    try {
      await api.stashSave(repoPath, message);
      toastSuccess('Stash salvo');
    } catch (err) {
      toastError('Erro ao salvar stash', err.message);
    }
    renderStashTab(container, repoPath);
  });

  const applyBtn = container.querySelector('#stash-apply-btn');
  if (applyBtn) {
    applyBtn.addEventListener('click', async () => {
      try {
        await api.stashApply(repoPath, 0);
        toastSuccess('Stash aplicado');
      } catch (err) {
        toastError('Erro ao aplicar stash', err.message);
      }
      renderStashTab(container, repoPath);
    });
  }

  const popBtn = container.querySelector('#stash-pop-btn');
  if (popBtn) {
    popBtn.addEventListener('click', async () => {
      try {
        await api.stashPop(repoPath, 0);
        toastSuccess('Stash aplicado e removido');
      } catch (err) {
        toastError('Erro no stash pop', err.message);
      }
      renderStashTab(container, repoPath);
    });
  }
}
