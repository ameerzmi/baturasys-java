// BaturaSys — Global JavaScript

// ── Toast ──────────────────────────────────────────────────────────────────
function showToast(msg, type = 'ok') {
  const toast = document.getElementById('bsy-toast');
  if (!toast) return;
  const dotColors = { ok:'#3fd28b', warn:'#f1c152', danger:'#f08a7a', info:'#7fd9e4' };
  toast.querySelector('.dot').style.background = dotColors[type] || dotColors.ok;
  toast.querySelector('.msg').textContent = msg;
  toast.classList.add('show');
  clearTimeout(toast._tt);
  toast._tt = setTimeout(() => toast.classList.remove('show'), 2800);
}

// ── Modal ──────────────────────────────────────────────────────────────────
function openModal(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeModal(id) {
  const el = id ? document.getElementById(id) : document.querySelector('.bsy-overlay.open');
  if (!el) return;
  el.classList.remove('open');
  document.body.style.overflow = '';
}

// Close modal on overlay click
document.addEventListener('click', e => {
  if (e.target.classList.contains('bsy-overlay')) closeModal();
});

// ── AJAX helper ────────────────────────────────────────────────────────────
async function postJson(url, data) {
  const fd = data instanceof FormData ? data : (() => {
    const f = new FormData();
    Object.entries(data).forEach(([k,v]) => f.append(k, v));
    return f;
  })();
  const res = await fetch(url, { method: 'POST', body: fd });
  const text = await res.text();
  try { return JSON.parse(text); } catch { return { success: false, message: 'Server error (invalid response)' }; }
}

// ── Receipt upload preview ─────────────────────────────────────────────────
function initReceiptUpload() {
  const inp = document.getElementById('receipt-file');
  if (!inp) return;
  const drop = document.getElementById('receipt-drop');
  const icon = document.getElementById('receipt-icon');
  const lbl  = document.getElementById('receipt-label');
  const err  = document.getElementById('receipt-error');
  const sub  = document.getElementById('receipt-submit');
  const prev = document.getElementById('receipt-file-preview');

  inp.addEventListener('change', () => {
    const f = inp.files[0];
    if (!f) return;
    if (!/\.(jpg|jpeg|png)$/i.test(f.name)) {
      err.textContent = 'Only JPG, JPEG and PNG files are allowed.';
      err.style.display = 'block';
      inp.value = '';
      return;
    }
    if (f.size > 5 * 1024 * 1024) {
      err.textContent = 'File size exceeds the 5 MB limit.';
      err.style.display = 'block';
      inp.value = '';
      return;
    }
    err.style.display = 'none';
    lbl.textContent = f.name;
    icon.style.display = 'none';
    if (drop) { drop.style.borderColor = 'var(--brand)'; drop.style.background = 'var(--brand-tint)'; }
    if (sub) sub.style.opacity = '1';
    if (prev) {
      const reader = new FileReader();
      reader.onload = ev => { prev.src = ev.target.result; prev.style.display = 'block'; };
      reader.readAsDataURL(f);
    }
  });
}

// ── QR image upload preview ────────────────────────────────────────────────
function initQrUpload() {
  const inp = document.getElementById('qr-file');
  if (!inp) return;
  inp.addEventListener('change', async () => {
    const f = inp.files[0];
    if (!f) return;
    const fd = new FormData();
    fd.append('qr_file', f);
    const res = await postJson(BASE_URL + 'api/manager-action?action=upload_qr', fd);
    if (res.success) {
      showToast('Bank QR image updated', 'ok');
      const img = document.getElementById('qr-preview-img');
      const placeholder = document.getElementById('qr-placeholder');
      const reader = new FileReader();
      reader.onload = ev => {
        if (img) { img.src = ev.target.result; img.style.display = 'block'; }
        if (placeholder) placeholder.style.display = 'none';
      };
      reader.readAsDataURL(f);
    } else {
      showToast(res.message || 'Upload failed', 'danger');
    }
  });
}

// ── Staff: Approve / Reject modal ─────────────────────────────────────────
function openReviewModal(groupRef) {
  document.getElementById('review-booking-id').textContent = groupRef;
  const img = document.getElementById('receipt-preview');
  if (img) { img.src = BASE_URL + 'api/staff-action?action=receipt_img&group_ref=' + encodeURIComponent(groupRef); }
  const approveBtn = document.getElementById('approve-btn');
  if (approveBtn) approveBtn.onclick = () => approvePayment(groupRef);
  const rejectBtn = document.getElementById('reject-btn');
  if (rejectBtn) rejectBtn.onclick = () => {
    closeModal('modal-review');
    const ri = document.getElementById('reject-group-input');
    if (ri) ri.value = groupRef;
    openModal('modal-reject');
  };
  openModal('modal-review');
}

async function approvePayment(groupRef) {
  try {
    const res = await postJson(BASE_URL + 'api/staff-action?action=approve', { group_ref: groupRef });
    if (res.success) { showToast('Payment verified — booking confirmed', 'ok'); setTimeout(() => location.reload(), 900); }
    else showToast(res.message || 'Approval failed', 'danger');
  } catch (e) { showToast('Network error — try again', 'danger'); }
}

// ── Staff: Check-in search ─────────────────────────────────────────────────
async function doCheckinSearch(e) {
  e.preventDefault();
  const q = document.getElementById('checkin-search').value.trim();
  const box = document.getElementById('checkin-result');
  if (!q) return;
  const res = await postJson(BASE_URL + 'api/staff-action', { action: 'checkin_search', q });
  if (res.success) {
    box.innerHTML = '<div class="card mt-14" style="overflow:hidden">' + res.data.html + '</div>';
  } else {
    box.innerHTML = '<div style="padding:14px;font-size:13px;color:var(--danger)">' + (res.message || 'Search failed') + '</div>';
  }
}

async function openCheckinModal(id, ref, name) {
  document.getElementById('checkin-booking-id').value = id;
  document.getElementById('checkin-info').textContent = name;
  document.getElementById('checkin-ref').textContent = ref;

  const sel  = document.getElementById('checkin-watercraft');
  const warn = document.getElementById('checkin-wc-warn');
  if (sel) {
    sel.innerHTML = '<option value="">Loading…</option>';
    if (warn) warn.style.display = 'none';
  }
  document.querySelectorAll('#checkin-form input[type=checkbox]').forEach(cb => {
    if (!cb.disabled) cb.checked = false;
  });
  openModal('modal-checkin');
  if (!sel) return;
  try {
    const res = await postJson(BASE_URL + 'api/staff-action', { action: 'available_wc', booking_id: id });
    sel.innerHTML = '<option value="">— Select watercraft —</option>';
    if (res.success && res.data && res.data.watercraft.length > 0) {
      res.data.watercraft.forEach(w => {
        const opt = document.createElement('option');
        opt.value = w.identifier;
        opt.textContent = w.name + ' · ' + w.usage_hours + 'h · ' + w.condition_status;
        sel.appendChild(opt);
      });
    } else {
      if (warn) { warn.style.display = 'block'; warn.textContent = res.message || 'No available watercraft for this slot.'; }
    }
  } catch (e) {
    sel.innerHTML = '<option value="">— Select watercraft —</option>';
    if (warn) { warn.style.display = 'block'; warn.textContent = 'Could not load watercraft. Try again.'; }
  }
}

// ── Return modal ──────────────────────────────────────────────────────────
function openReturnModal(bookingId, customerName, watercraftName) {
  document.getElementById('return-booking-id').value = bookingId;
  document.getElementById('return-info').textContent = customerName + ' — ' + watercraftName;
  openModal('modal-return');
}

// ── Equipment modal ────────────────────────────────────────────────────────
function openEquipModal(id, equipId, type, cond) {
  document.getElementById('equip-update-id').value = id;
  document.getElementById('equip-update-info').textContent = equipId + ' · ' + type;
  const sel = document.getElementById('equip-update-cond');
  if (sel) sel.value = cond;
  openModal('modal-equip');
}

// ── Maintenance complete modal ─────────────────────────────────────────────
function openCompleteModal(taskId, taskType, wcName) {
  document.getElementById('complete-task-id').value = taskId;
  document.getElementById('complete-task-info').textContent = taskType + ' · ' + wcName;
  openModal('modal-complete');
}

// ── Generic AJAX form submit ───────────────────────────────────────────────
async function submitModalForm(formId, action, successMsg) {
  const form = document.getElementById(formId);
  if (!form) return;
  const fd = new FormData(form);
  fd.append('action', action);
  try {
    const res = await postJson(BASE_URL + 'api/staff-action', fd);
    if (res.success) {
      closeModal();
      showToast(successMsg || res.message, 'ok');
      setTimeout(() => location.reload(), 900);
    } else {
      showToast(res.message || 'Action failed', 'danger');
    }
  } catch (e) { showToast('Network error — try again', 'danger'); }
}

async function submitManagerForm(formId, action, successMsg) {
  const form = document.getElementById(formId);
  if (!form) return;
  const fd = new FormData(form);
  fd.append('action', action);
  const res = await postJson(BASE_URL + 'api/manager-action', fd);
  if (res.success) {
    closeModal();
    showToast(successMsg || res.message, 'ok');
    setTimeout(() => location.reload(), 900);
  } else {
    showToast(res.message, 'danger');
  }
}

// ── Copy to clipboard ─────────────────────────────────────────────────────
async function copyRef(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const inp = document.createElement('input');
    inp.value = text;
    document.body.appendChild(inp);
    inp.select();
    document.execCommand('copy');
    document.body.removeChild(inp);
  }
  showToast('Reference copied!', 'ok');
}

// ── Cancel booking confirm ─────────────────────────────────────────────────
function openCancelConfirm() { openModal('modal-cancel'); }

async function confirmCancel(bookingId) {
  const res = await postJson(BASE_URL + 'api/booking-action?action=cancel', { booking_id: bookingId });
  if (res.success) { showToast('Booking cancelled', 'ok'); setTimeout(() => location.reload(), 900); }
  else showToast(res.message, 'danger');
}

async function confirmCancelGroup(groupRef) {
  const res = await postJson(BASE_URL + 'api/booking-action?action=cancel', { group_ref: groupRef });
  if (res.success) { showToast('Booking cancelled', 'ok'); setTimeout(() => location.reload(), 900); }
  else showToast(res.message, 'danger');
}

// ── Role toggle (portal login) ─────────────────────────────────────────────
function setRole(role) {
  document.getElementById('login-role').value = role;
  document.querySelectorAll('.role-tab').forEach(t => {
    const active = t.dataset.role === role;
    t.style.background = active ? '#fff' : 'transparent';
    t.style.color = active ? 'var(--brand-dark)' : 'var(--muted)';
    t.style.boxShadow = active ? '0 1px 3px rgba(15,38,44,.12)' : 'none';
  });
  const idLabel = document.getElementById('id-label');
  const idInput = document.getElementById('id-input');
  if (idLabel) idLabel.textContent = role === 'manager' ? 'Manager ID or email' : 'Staff ID';
  if (idInput) {
    idInput.placeholder = role === 'manager' ? 'MGR-01' : 'BS-0002';
    idInput.value = role === 'manager' ? 'MGR-01' : 'BS-0002';
  }
  const hint = document.getElementById('hint-id');
  if (hint) hint.textContent = role === 'manager' ? 'MGR-01' : 'BS-0002';
}

// Init
document.addEventListener('DOMContentLoaded', () => {
  initReceiptUpload();
  initQrUpload();

  // Auto-dismiss flash message
  const flash = document.getElementById('bsy-flash');
  if (flash) {
    const type = flash.dataset.type || 'ok';
    showToast(flash.dataset.msg, type);
  }
});
