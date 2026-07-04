import { renderSidebar } from './screens/dashboard-screen.js';
import { renderProjectDetail, renderWelcome } from './screens/project-detail-screen.js';

const sidebar = document.getElementById('sidebar');
const content = document.getElementById('content');

const state = { selectedPath: null };

export async function selectProject(repoPath) {
  state.selectedPath = repoPath;
  await renderProjectDetail(content, repoPath, handleProjectRemoved);
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
