import * as api from '../services/git-api.js';
import { promptDialog, confirmDialog } from '../services/dialogs.js';
import { toastSuccess, toastError } from '../services/toast.js';
import { renderStagingTab } from './staging-tab.js';

const TABS = [
  { id: 'overview', label: 'Overview' },
  { id: 'commit', label: 'Commit' },
  { id: 'history', label: 'History' },
  { id: 'tags', label: 'Tags' },
  { id: 'stash', label: 'Stash' }
];

const tabState = new Map();
const outputLog = new Map();
const historyView = new Map(); // repoPath -> 'graph' | 'list'

// History graph parameters
const GRAPH_COLORS = ['#6366f1', '#10b981', '#f59e0b', '#06b6d4', '#ec4899', '#a78bfa', '#ef4444', '#84cc16'];
const ROW_H = 34;
const COL_W = 16;
const PAD_X = 12;
const NODE_R = 4;

function laneColor(colorId) {
  const n = GRAPH_COLORS.length;
  return GRAPH_COLORS[((colorId % n) + n) % n];
}

// Picks a color index for a new branch line. It prefers a palette color
// that no active lane is using (avoids two neighboring branches with the
// same color); if all 8 are taken, it falls back to a rotating counter.
// `counter` is passed by reference through an object.
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
        <div>Select a repository on the left</div>
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
      <button class="btn btn-ghost compact" id="refresh-btn">⟳ Refresh</button>
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

  // "Refresh" is the only place that re-renders everything: it reloads the
  // current repo's panel and the nav too (re-validates every repo's status).
  container.querySelector('#refresh-btn').addEventListener('click', () => {
    if (onRefreshSidebar) onRefreshSidebar();
    renderProjectDetail(container, repoPath, onRemoved, onRefreshSidebar);
  });

  const check = await api.checkProject(repoPath).catch(() => null);
  if (check && (!check.existsOnDisk || !check.hasGit)) {
    tabBody.innerHTML = `
      <div class="card">
        <h3>Repository unavailable</h3>
        <p class="hint">${
          !check.existsOnDisk
            ? 'The folder no longer exists at this path.'
            : 'The folder exists, but holds no valid Git repository (.git).'
        }</p>
        <div class="card-row" style="margin-top: 16px;">
          <button class="btn btn-danger compact" id="remove-unavailable-btn">Remove from list</button>
        </div>
      </div>
    `;
    tabBody.querySelector('#remove-unavailable-btn').addEventListener('click', async () => {
      const ok = await confirmDialog({
        title: 'Remove project',
        message: `Remove "${projectName}" from the list? This deletes nothing from disk.`
      });
      if (!ok) return;
      await api.removeProject(repoPath);
      toastSuccess('Project removed');
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
    tabBody.innerHTML = `<div class="card">Error loading: ${escapeHtml(err.message)}</div>`;
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
          <div class="hint">Current branch</div>
          <div style="font-size: 20px; font-weight: 700;">${escapeHtml(status.branch)}</div>
        </div>
        <div>
          <div class="hint">HEAD</div>
          <div style="font-family: monospace;">${status.head ? status.head.slice(0, 7) : 'N/A'}</div>
        </div>
      </div>
    </div>

    <div class="card">
      <h3>Switch branch</h3>
      <div class="card-row">
        <select id="branch-select" style="flex: 1;">
          ${localBranches
            .map((b) => `<option value="${b.name}" ${b.name === status.branch ? 'selected' : ''}>${b.name}</option>`)
            .join('')}
        </select>
        <button class="btn btn-primary compact" id="checkout-btn">Checkout</button>
        <button class="btn btn-success compact" id="new-branch-btn">+ New branch</button>
      </div>
    </div>

    <div class="card">
      <h3>Sync</h3>
      <p class="hint" style="margin-bottom: 12px;">
        ${
          !sync.hasRemote
            ? 'No remote configured.'
            : sync.ahead === 0 && sync.behind === 0
              ? '✓ Up to date with the remote.'
              : `${sync.ahead > 0 ? `${sync.ahead} commit(s) ahead` : ''} ${sync.behind > 0 ? `${sync.behind} commit(s) behind` : ''}`
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
      <div class="terminal" id="terminal">${escapeHtml(logLines.join('\n')) || '(no command run yet)'}</div>
      <div class="card-row" style="margin-top: 8px;">
        <button class="btn btn-ghost tiny" id="copy-output-btn">Copy</button>
        <button class="btn btn-ghost tiny" id="clear-output-btn">Clear</button>
      </div>
    </div>
  `;

  const rerender = () => renderOverviewTab(container, repoPath);

  container.querySelector('#checkout-btn').addEventListener('click', async () => {
    const branch = container.querySelector('#branch-select').value;
    try {
      await api.checkout(repoPath, branch);
      appendLog(repoPath, `$ git checkout ${branch}\nOK`);
      toastSuccess('Checkout done');
    } catch (err) {
      appendLog(repoPath, `❌ Error: ${err.message}`);
      toastError('Checkout error', err.message);
    }
    rerender();
  });

  container.querySelector('#new-branch-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'New branch', label: 'Branch name' });
    if (!name) return;
    try {
      await api.createBranch(repoPath, name);
      appendLog(repoPath, `$ git checkout -b ${name}\nOK`);
      toastSuccess('Branch created');
    } catch (err) {
      appendLog(repoPath, `❌ Error: ${err.message}`);
      toastError('Error creating branch', err.message);
    }
    rerender();
  });

  container.querySelector('#push-btn').addEventListener('click', () => runSyncAction(repoPath, 'push', rerender));
  container.querySelector('#pull-btn').addEventListener('click', () => runSyncAction(repoPath, 'pull', rerender));
  container.querySelector('#fetch-btn').addEventListener('click', () => runSyncAction(repoPath, 'fetch', rerender));

  container.querySelector('#copy-output-btn').addEventListener('click', () => {
    navigator.clipboard.writeText(logLines.join('\n'));
    toastSuccess('Output copied');
  });
  container.querySelector('#clear-output-btn').addEventListener('click', () => {
    outputLog.set(repoPath, []);
    rerender();
  });
}

async function runSyncAction(repoPath, action, rerender) {
  try {
    await api[action](repoPath);
    appendLog(repoPath, `$ git ${action}\nOK: done.`);
    toastSuccess(`${action} done`);
  } catch (err) {
    let detail = err.message;
    if (/permission denied|publickey/i.test(detail)) {
      detail += '\nTip: check your SSH key (~/.ssh) and whether it is set up on the remote service.';
    }
    appendLog(repoPath, `$ git ${action}\n❌ Error: ${detail}`);
    toastError(`${action} error`, err.message);
  }
  rerender();
}

async function renderHistoryTab(container, repoPath) {
  container.innerHTML = `<div class="card">Loading...</div>`;
  const commits = await api.getCommits(repoPath, 100);
  const view = historyView.get(repoPath) || 'graph';

  container.innerHTML = `
    <div class="card history-card">
      <div class="card-row history-head">
        <h3 style="margin: 0;">Commit history (current branch)</h3>
        <span style="flex: 1;"></span>
        <div class="seg">
          <button class="seg-btn ${view === 'graph' ? 'active' : ''}" data-view="graph">⑂ Graph</button>
          <button class="seg-btn ${view === 'list' ? 'active' : ''}" data-view="list">☰ List</button>
        </div>
      </div>
      <div class="history-body">
        ${
          commits.length === 0
            ? '<p class="hint">No commits yet.</p>'
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

// Assigns a "lane" (column) to each commit to draw a gitk-style DAG.
// Walks the commits (newest first); each lane holds the hash of the next
// commit expected on it. The first parent continues on the same lane; extra
// parents (merges) open new lanes.
//
// The COLOR follows the *branch line*, not the column: each lane carries a
// persistent `color` (`laneColors`) born when the line appears, inherited by
// the first parent's continuation and traveling with the lane. So the merge and
// the source branch's whole chain keep a single color, even when they change column.
function computeGraph(commits) {
  const idToRow = new Map(commits.map((c, i) => [c.id, i]));
  const lanes = []; // lanes[i] = expected hash, or null if free
  const laneColors = []; // laneColors[i] = color id of the branch on lane i (or null)
  const counter = { next: 0 }; // fallback when the whole palette is in use
  let maxLanes = 1;
  const rows = [];

  for (const commit of commits) {
    let lane = lanes.indexOf(commit.id);
    let color;
    if (lane === -1) {
      // No lane was expecting this commit: it is a branch tip (e.g. HEAD on the
      // first row). Opens a lane with a new color.
      lane = lanes.indexOf(null);
      if (lane === -1) {
        lane = lanes.length;
        lanes.push(null);
        laneColors.push(null);
      }
      color = allocColor(laneColors, counter);
      laneColors[lane] = color;
    } else {
      color = laneColors[lane]; // inherits the color of the line that got here
    }
    lanes[lane] = commit.id;

    // Other lanes also expecting this commit converge here (merge target).
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
      // The first parent continues on the same lane with the SAME color.
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
          pcolor = allocColor(laneColors, counter); // a dedicated color for the merged branch
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
        // Curves to the target lane within the first row, then goes straight down.
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
  container.innerHTML = `<div class="card">Loading...</div>`;
  const tags = await api.getTags(repoPath);
  container.innerHTML = `
    <div class="card">
      <div class="card-row" style="justify-content: space-between; margin-bottom: 12px;">
        <h3 style="margin: 0;">Tags</h3>
        <button class="btn btn-primary compact" id="new-tag-btn">+ New tag</button>
      </div>
      ${
        tags.length === 0
          ? '<p class="hint">No tags.</p>'
          : tags
              .map(
                (t) => `
        <div class="list-item">
          <span>🏷</span>
          <div class="list-item-main"><div class="list-item-title">${escapeHtml(t)}</div></div>
          <button class="btn btn-danger tiny" data-action="delete-tag" data-name="${escapeHtml(t)}">Delete</button>
        </div>
      `
              )
              .join('')
      }
    </div>
  `;

  container.querySelector('#new-tag-btn').addEventListener('click', async () => {
    const name = await promptDialog({ title: 'New tag', label: 'Tag name' });
    if (!name) return;
    const message = await promptDialog({ title: 'Tag message (optional)', label: 'Message' });
    if (message === null) return;
    try {
      await api.createTag(repoPath, name, message);
      toastSuccess('Tag created');
    } catch (err) {
      toastError('Error creating tag', err.message);
    }
    renderTagsTab(container, repoPath);
  });

  container.querySelectorAll('[data-action="delete-tag"]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const ok = await confirmDialog({ title: 'Delete tag', message: `Delete the tag "${btn.dataset.name}"?` });
      if (!ok) return;
      try {
        await api.deleteTag(repoPath, btn.dataset.name);
        toastSuccess('Tag removed');
      } catch (err) {
        toastError('Error deleting tag', err.message);
      }
      renderTagsTab(container, repoPath);
    });
  });
}

async function renderStashTab(container, repoPath) {
  container.innerHTML = `<div class="card">Loading...</div>`;
  const stashes = await api.getStashes(repoPath);
  container.innerHTML = `
    <div class="card">
      <h3>Stash</h3>
      <div class="card-row" style="margin-bottom: 16px;">
        <button class="btn btn-primary compact" id="stash-save-btn">Save stash</button>
        <button class="btn btn-info compact" id="stash-apply-btn" ${stashes.length === 0 ? 'disabled' : ''}>Apply</button>
        <button class="btn btn-success compact" id="stash-pop-btn" ${stashes.length === 0 ? 'disabled' : ''}>Pop</button>
      </div>
      ${
        stashes.length === 0
          ? '<p class="hint">No stashes.</p>'
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
    const message = await promptDialog({ title: 'Save stash', label: 'Message (optional)' });
    if (message === null) return;
    try {
      await api.stashSave(repoPath, message);
      toastSuccess('Stash saved');
    } catch (err) {
      toastError('Error saving stash', err.message);
    }
    renderStashTab(container, repoPath);
  });

  const applyBtn = container.querySelector('#stash-apply-btn');
  if (applyBtn) {
    applyBtn.addEventListener('click', async () => {
      try {
        await api.stashApply(repoPath, 0);
        toastSuccess('Stash applied');
      } catch (err) {
        toastError('Error applying stash', err.message);
      }
      renderStashTab(container, repoPath);
    });
  }

  const popBtn = container.querySelector('#stash-pop-btn');
  if (popBtn) {
    popBtn.addEventListener('click', async () => {
      try {
        await api.stashPop(repoPath, 0);
        toastSuccess('Stash applied and dropped');
      } catch (err) {
        toastError('Stash pop error', err.message);
      }
      renderStashTab(container, repoPath);
    });
  }
}
