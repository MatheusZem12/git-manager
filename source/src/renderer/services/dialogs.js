function openOverlay(innerHtml) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `<div class="modal">${innerHtml}</div>`;
  document.body.appendChild(overlay);
  return overlay;
}

export function confirmDialog({ title, message, confirmLabel = 'Confirmar', danger = true }) {
  return new Promise((resolve) => {
    const overlay = openOverlay(`
      <h3>${title}</h3>
      <p>${message}</p>
      <div class="modal-actions">
        <button class="btn btn-ghost" data-action="cancel">Cancelar</button>
        <button class="btn ${danger ? 'btn-danger' : 'btn-primary'}" data-action="confirm">${confirmLabel}</button>
      </div>
    `);

    const close = (result) => {
      overlay.remove();
      resolve(result);
    };

    overlay.querySelector('[data-action="cancel"]').addEventListener('click', () => close(false));
    overlay.querySelector('[data-action="confirm"]').addEventListener('click', () => close(true));
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) close(false);
    });
  });
}

export function promptDialog({ title, label = '', placeholder = '', initialValue = '', confirmLabel = 'Confirmar' }) {
  return new Promise((resolve) => {
    const overlay = openOverlay(`
      <h3>${title}</h3>
      <div class="form-group">
        ${label ? `<label>${label}</label>` : ''}
        <input type="text" id="prompt-input" placeholder="${placeholder}" value="${initialValue}">
      </div>
      <div class="modal-actions">
        <button class="btn btn-ghost" data-action="cancel">Cancelar</button>
        <button class="btn btn-primary" data-action="confirm">${confirmLabel}</button>
      </div>
    `);

    const input = overlay.querySelector('#prompt-input');
    input.focus();
    input.select();

    const close = (result) => {
      overlay.remove();
      resolve(result);
    };

    overlay.querySelector('[data-action="cancel"]').addEventListener('click', () => close(null));
    overlay.querySelector('[data-action="confirm"]').addEventListener('click', () => close(input.value.trim()));
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') close(input.value.trim());
      if (e.key === 'Escape') close(null);
    });
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) close(null);
    });
  });
}
