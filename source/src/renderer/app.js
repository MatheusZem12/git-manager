import { renderSidebar } from './screens/dashboard-screen.js';
import { renderProjectDetail, renderWelcome } from './screens/project-detail-screen.js';

const sidebar = document.getElementById('sidebar');
const content = document.getElementById('content');
const appEl = document.getElementById('app');

// A persistent button (outside the re-rendered content) that shows the sidebar
// again when it is collapsed. The collapse button lives in the sidebar
// header and is rewired on every render in dashboard-screen.
document
  .getElementById('expand-sidebar-btn')
  .addEventListener('click', () => appEl.classList.remove('sidebar-collapsed'));

const state = { selectedPath: null };

export async function selectProject(repoPath) {
  state.selectedPath = repoPath;
  await renderProjectDetail(content, repoPath, handleProjectRemoved, refreshSidebar);
}

async function handleProjectRemoved() {
  state.selectedPath = null;
  renderWelcome(content);
  await refreshSidebar();
}

async function refreshSidebar() {
  await renderSidebar(sidebar, {
    selectedPath: state.selectedPath,
    onSelect: selectProject,
    onRemoved: handleProjectRemoved
  });
}

async function init() {
  renderWelcome(content);
  await refreshSidebar();
}

init();
