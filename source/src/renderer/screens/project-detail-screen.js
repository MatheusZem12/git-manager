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
const historyView = new Map(); // repoPath -> 'graph' | 'list'

// Parâmetros do grafo de histórico
const GRAPH_COLORS = ['#6366f1', '#10b981', '#f59e0b', '#06b6d4', '#ec4899', '#a78bfa', '#ef4444', '#84cc16'];
const ROW_H = 34;
const COL_W = 16;
const PAD_X = 12;
const NODE_R = 4;

function laneColor(colorId) {
  const n = GRAPH_COLORS.length;
  return GRAPH_COLORS[((colorId % n) + n) % n];
}

// Escolhe um índice de cor pra uma linha de branch nova. Prefere uma cor da
// paleta que não esteja em uso por nenhuma lane ativa (evita duas branches
// vizinhas com a mesma cor); se todas as 8 estiverem ocupadas, cai num
// contador rotativo. `counter` é passado por referência via objeto.
function allocColor(laneColors, counter) {
  const used = new Set();
  for (const c of laneColors) {
    if (c != null) used.add(((c % GRAPH_COLORS.length) + GRAPH_COLORS.length) % GRAPH_COLORS.length);
  }
  for (let i = 0; i < GRAPH_COLORS.length; i++) {
    if (!used.has(i)) return i;
  }
  return counter.next++ % GRAPH_COLORS.length;
}

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

export async function renderProjectDetail(container, repoPath, onRemoved, onRefreshSidebar) {
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
      renderProjectDetail(container, repoPath, onRemoved, onRefreshSidebar);
    });
  });

  // "Atualizar" é o único ponto que re-renderiza tudo: recarrega o painel do
  // repo atual e também a nav (re-valida o status de todos os repos).
  container.querySelector('#refresh-btn').addEventListener('click', () => {
    if (onRefreshSidebar) onRefreshSidebar();
    renderProjectDetail(container, repoPath, onRemoved, onRefreshSidebar);
  });

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
  const view = historyView.get(repoPath) || 'graph';

  container.innerHTML = `
    <div class="card history-card">
      <div class="card-row history-head">
        <h3 style="margin: 0;">Histórico de commits (branch atual)</h3>
        <span style="flex: 1;"></span>
        <div class="seg">
          <button class="seg-btn ${view === 'graph' ? 'active' : ''}" data-view="graph">⑂ Gráfico</button>
          <button class="seg-btn ${view === 'list' ? 'active' : ''}" data-view="list">☰ Lista</button>
        </div>
      </div>
      <div class="history-body">
        ${
          commits.length === 0
            ? '<p class="hint">Nenhum commit ainda.</p>'
            : view === 'graph'
              ? renderHistoryGraph(commits)
              : renderHistoryList(commits)
        }
      </div>
    </div>
  `;

  container.querySelectorAll('[data-view]').forEach((btn) => {
    btn.addEventListener('click', () => {
      historyView.set(repoPath, btn.dataset.view);
      renderHistoryTab(container, repoPath);
    });
  });
}

function renderHistoryList(commits) {
  return commits
    .map(
      (c) => `
    <div class="list-item">
      <span style="font-size: 18px; color: ${laneColor(0)};">●</span>
      <div class="list-item-main">
        <div class="list-item-title">${renderRefs(c.refs)}${escapeHtml(c.message)}</div>
        <div class="list-item-sub">${c.shortId} · ${escapeHtml(c.authorName)} · ${formatDate(c.date)}</div>
      </div>
    </div>
  `
    )
    .join('');
}

// Atribui uma "lane" (coluna) a cada commit para desenhar o DAG estilo gitk.
// Percorre os commits (mais novos primeiro); cada lane guarda o hash do próximo
// commit esperado nela. O primeiro pai continua na mesma lane; pais extras
// (merges) abrem novas lanes.
//
// A COR segue a *linha da branch*, não a coluna: cada lane carrega um `color`
// persistente (`laneColors`) que nasce quando a linha aparece, é herdado pela
// continuação do primeiro pai e viaja com a lane. Assim o merge e toda a cadeia
// da branch de origem ficam com uma única cor, mesmo que mudem de coluna.
function computeGraph(commits) {
  const idToRow = new Map(commits.map((c, i) => [c.id, i]));
  const lanes = []; // lanes[i] = hash esperado, ou null se livre
  const laneColors = []; // laneColors[i] = id de cor da branch na lane i (ou null)
  const counter = { next: 0 }; // fallback quando a paleta toda está em uso
  let maxLanes = 1;
  const rows = [];

  for (const commit of commits) {
    let lane = lanes.indexOf(commit.id);
    let color;
    if (lane === -1) {
      // Nenhuma lane esperava este commit: é um tip de branch (ex.: HEAD na
      // primeira linha). Abre uma lane com uma cor nova.
      lane = lanes.indexOf(null);
      if (lane === -1) {
        lane = lanes.length;
        lanes.push(null);
        laneColors.push(null);
      }
      color = allocColor(laneColors, counter);
      laneColors[lane] = color;
    } else {
      color = laneColors[lane]; // herda a cor da linha que chegou até aqui
    }
    lanes[lane] = commit.id;

    // Outras lanes que também esperavam este commit convergem aqui (merge alvo).
    for (let li = 0; li < lanes.length; li++) {
      if (li !== lane && lanes[li] === commit.id) {
        lanes[li] = null;
        laneColors[li] = null;
      }
    }

    const parentAssignments = [];
    const parents = commit.parents;
    if (parents.length === 0) {
      lanes[lane] = null;
      laneColors[lane] = null;
    } else {
      // Primeiro pai continua na mesma lane com a MESMA cor.
      lanes[lane] = parents[0];
      parentAssignments.push({ parent: parents[0], lane, color });
      for (let pi = 1; pi < parents.length; pi++) {
        let pl = lanes.indexOf(parents[pi]);
        let pcolor;
        if (pl === -1) {
          pl = lanes.indexOf(null);
          if (pl === -1) {
            pl = lanes.length;
            lanes.push(null);
            laneColors.push(null);
          }
          lanes[pl] = parents[pi];
          pcolor = allocColor(laneColors, counter); // cor dedicada da branch mesclada
          laneColors[pl] = pcolor;
        } else {
          pcolor = laneColors[pl];
        }
        parentAssignments.push({ parent: parents[pi], lane: pl, color: pcolor });
      }
    }

    while (lanes.length > 0 && lanes[lanes.length - 1] === null) {
      lanes.pop();
      laneColors.pop();
    }
    maxLanes = Math.max(maxLanes, lanes.length, lane + 1);

    rows.push({ commit, lane, color, parents: parentAssignments });
  }

  const edges = [];
  rows.forEach((row, i) => {
    for (const pa of row.parents) {
      const j = idToRow.get(pa.parent);
      edges.push({
        fromRow: i,
        fromLane: row.lane,
        toRow: j === undefined ? null : j,
        toLane: j === undefined ? pa.lane : rows[j].lane,
        color: pa.color
      });
    }
  });

  return { rows, edges, laneCount: maxLanes };
}

function renderHistoryGraph(commits) {
  const { rows, edges, laneCount } = computeGraph(commits);
  const x = (lane) => PAD_X + lane * COL_W + COL_W / 2;
  const y = (row) => row * ROW_H + ROW_H / 2;
  const svgW = PAD_X * 2 + laneCount * COL_W;
  const svgH = rows.length * ROW_H;

  const edgePaths = edges
    .map((e) => {
      const x1 = x(e.fromLane);
      const y1 = y(e.fromRow);
      const y2 = e.toRow === null ? svgH : y(e.toRow);
      const x2 = e.toRow === null ? x1 : x(e.toLane);
      let d;
      if (x1 === x2) {
        d = `M ${x1} ${y1} L ${x2} ${y2}`;
      } else {
        // Curva pra lane alvo dentro da primeira linha, depois desce reto.
        const yb = y1 + ROW_H;
        d = `M ${x1} ${y1} C ${x1} ${y1 + ROW_H * 0.45}, ${x2} ${yb - ROW_H * 0.45}, ${x2} ${yb} L ${x2} ${y2}`;
      }
      return `<path d="${d}" fill="none" stroke="${laneColor(e.color)}" stroke-width="1.6" opacity="0.85"/>`;
    })
    .join('');

  const nodes = rows
    .map((r, i) => {
      const c = laneColor(r.color);
      const isMerge = r.commit.parents.length > 1;
      return `<circle cx="${x(r.lane)}" cy="${y(i)}" r="${NODE_R}" fill="${isMerge ? 'var(--bg-elevated)' : c}" stroke="${c}" stroke-width="2"/>`;
    })
    .join('');

  const list = rows
    .map((r) => {
      const c = r.commit;
      return `
      <div class="graph-row" style="height: ${ROW_H}px;" title="${escapeHtml(c.message)}">
        <div class="graph-row-inner">
          ${renderRefs(c.refs)}
          <span class="graph-msg">${escapeHtml(c.message)}</span>
          <span class="graph-meta">${c.shortId} · ${escapeHtml(c.authorName)} · ${formatDate(c.date)}</span>
        </div>
      </div>`;
    })
    .join('');

  return `
    <div class="graph-view">
      <div class="graph-canvas-wrap" style="width: ${svgW}px;">
        <svg class="graph-canvas" width="${svgW}" height="${svgH}" viewBox="0 0 ${svgW} ${svgH}">
          ${edgePaths}
          ${nodes}
        </svg>
      </div>
      <div class="graph-list">${list}</div>
    </div>
  `;
}

function renderRefs(refs) {
  if (!refs) return '';
  return refs
    .split(',')
    .map((raw) => raw.trim())
    .filter(Boolean)
    .map((ref) => {
      if (ref.startsWith('tag: ')) return `<span class="ref-badge tag">🏷 ${escapeHtml(ref.slice(5))}</span>`;
      if (ref.startsWith('HEAD ->')) {
        return `<span class="ref-badge head">${escapeHtml(ref.replace('HEAD ->', 'HEAD →').trim())}</span>`;
      }
      if (ref === 'HEAD') return `<span class="ref-badge head">HEAD</span>`;
      if (ref.includes('/')) return `<span class="ref-badge remote">${escapeHtml(ref)}</span>`;
      return `<span class="ref-badge">${escapeHtml(ref)}</span>`;
    })
    .join('');
}

async function renderTagsTab(container, repoPath) {
  container.innerHTML = `<div class="card">Carregando...</div>`;
  const tags = await api.getTags(repoPath);
  container.innerHTML = `
    <div class="card">
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
    <div class="card">
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
