const ICONS = { success: '✓', error: '✕', warning: '!', info: 'i' };
const MAX_VISIBLE = 3;

function getHost() {
  let host = document.getElementById('toast-host');
  if (!host) {
    host = document.createElement('div');
    host.id = 'toast-host';
    document.body.appendChild(host);
  }
  return host;
}

export function showToast(type, title, detail) {
  const host = getHost();
  while (host.children.length >= MAX_VISIBLE) {
    host.removeChild(host.firstChild);
  }

  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <div class="toast-title">${ICONS[type] || ''} ${title}</div>
    ${detail ? `<div class="toast-detail">${detail}</div>` : ''}
    <div class="toast-life"></div>
  `;
  host.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

export const toastSuccess = (title, detail) => showToast('success', title, detail);
export const toastError = (title, detail) => showToast('error', title, detail);
export const toastInfo = (title, detail) => showToast('info', title, detail);
