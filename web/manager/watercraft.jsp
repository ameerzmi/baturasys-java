<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

List<Row> watercraft = Db.all("SELECT * FROM watercraft ORDER BY identifier");
%><%= c.pageHead("Watercraft") %>
<div class="portal-wrap">
<%= c.managerSidebar("watercraft") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:1060px">
  <div class="flex items-center gap-14 mb-22">
    <div style="flex:1">
      <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Watercraft fleet</h1>
      <p class="fs-14 text-muted">Manage your fleet — kayaks, canoes, paddleboards, and cruise boats.</p>
    </div>
    <button class="btn btn-brand" onclick="openModal('modal-add-wc')">+ Add watercraft</button>
  </div>

  <div class="wc-grid">
    <% for (Row w : watercraft) {
      Activity meta = Fn.activityMeta(w.s("activity_id"));
      String status = w.str("status");
      String stBg, stFg, stLabel;
      if (status.equals("AVAILABLE"))              { stBg = "var(--ok-bg)";   stFg = "var(--ok)";   stLabel = "Available"; }
      else if (status.equals("IN_USE"))            { stBg = "var(--info-bg)"; stFg = "var(--info)"; stLabel = "In use"; }
      else if (status.equals("UNDER_MAINTENANCE")) { stBg = "var(--warn-bg)"; stFg = "var(--warn)"; stLabel = "Under maintenance"; }
      else if (status.equals("RETIRED"))           { stBg = "#f0f0f0";        stFg = "#999";        stLabel = "Retired"; }
      else                                         { stBg = "#eee";           stFg = "#888";        stLabel = status; }
      String year = w.str("year_acquired");
    %>
    <div class="card card-p" style="display:flex;flex-direction:column;gap:14px">
      <div class="flex items-center gap-12">
        <div style="width:46px;height:46px;border-radius:12px;background:<%= Fn.h(meta.swatch) %>;display:flex;align-items:center;justify-content:center;font-size:22px;flex:none"><%= meta.emoji %></div>
        <div style="flex:1;min-width:0">
          <div class="fw-800 fs-14"><%= Fn.h(w.s("name")) %></div>
          <div class="fs-12 mono text-muted"><%= Fn.h(w.s("identifier")) %></div>
        </div>
        <span class="badge" style="background:<%= stBg %>;color:<%= stFg %>"><%= Fn.h(stLabel) %></span>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">
        <div style="background:var(--surface-2);border-radius:8px;padding:9px 11px">
          <div class="fs-11 text-faint fw-700 mb-2">Activity</div>
          <div class="fs-13 fw-700"><%= Fn.h(meta.name) %></div>
        </div>
        <div style="background:var(--surface-2);border-radius:8px;padding:9px 11px">
          <div class="fs-11 text-faint fw-700 mb-2">Capacity</div>
          <div class="fs-13 fw-700"><%= w.i("capacity") %> pax</div>
        </div>
        <div style="background:var(--surface-2);border-radius:8px;padding:9px 11px">
          <div class="fs-11 text-faint fw-700 mb-2">Rate</div>
          <div class="fs-13 fw-700"><%= Fn.h(Fn.fmt(w.d("rate_per_unit"))) %>/<%= Fn.h(meta.unit) %></div>
        </div>
        <div style="background:var(--surface-2);border-radius:8px;padding:9px 11px">
          <div class="fs-11 text-faint fw-700 mb-2">Year</div>
          <div class="fs-13 fw-700"><%= Fn.h(Fn.coalesce(w.s("year_acquired"), "—")) %></div>
        </div>
      </div>
      <% if (!status.equals("RETIRED")) { %>
      <div class="flex gap-10">
        <button class="btn btn-ghost btn-sm flex-1" onclick="openEditWc(
          <%= w.i("id") %>,
          '<%= Fn.jsAttr(w.s("identifier")) %>',
          '<%= Fn.jsAttr(w.s("name")) %>',
          '<%= Fn.jsAttr(w.s("activity_id")) %>',
          <%= w.i("capacity") %>,
          <%= w.s("rate_per_unit") %>,
          '<%= Fn.jsAttr(status) %>',
          '<%= Fn.jsAttr(year) %>'
        )">Edit</button>
        <button class="btn btn-sm flex-1" style="background:var(--danger-bg);color:var(--danger);border:none" onclick="retireWc(<%= w.i("id") %>, '<%= Fn.jsAttr(w.s("identifier")) %>')">Retire</button>
      </div>
      <% } else { %>
      <div class="fs-12 text-faint" style="text-align:center">Retired — no longer in fleet</div>
      <% } %>
    </div>
    <% } %>
  </div>
</div>
</main>
</div>

<!-- Add Watercraft Modal -->
<div class="bsy-overlay" id="modal-add-wc">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:16px">Add watercraft</div>
    <form id="add-wc-form">
      <input type="hidden" name="action" value="add_watercraft">
      <div class="field sm">
        <label>Name <span style="color:var(--danger)">*</span></label>
        <input type="text" name="name" placeholder="e.g. Kayak Alpha" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Activity type <span style="color:var(--danger)">*</span></label>
        <select name="activity_id" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff" required>
          <option value="">— Select —</option>
          <option value="kayak">Kayak (solo)</option>
          <option value="kayak2">Kayak (tandem)</option>
          <option value="canoe">Canoe</option>
          <option value="paddle">Stand-up Paddleboard</option>
          <option value="cruise">Lake Cruise</option>
        </select>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="field sm">
          <label>Capacity (pax) <span style="color:var(--danger)">*</span></label>
          <input type="number" name="capacity" min="1" value="1" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
        </div>
        <div class="field sm">
          <label>Rate (RM/unit) <span style="color:var(--danger)">*</span></label>
          <input type="number" name="rate_per_unit" min="0" step="0.01" placeholder="10.00" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
        </div>
      </div>
      <div class="field sm">
        <label>Year acquired</label>
        <input type="number" name="year_acquired" min="2000" max="2099" placeholder="2024" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-add-wc')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('add-wc-form','add_watercraft','Watercraft added')">Add</button>
      </div>
    </form>
  </div>
</div>

<!-- Edit Watercraft Modal -->
<div class="bsy-overlay" id="modal-edit-wc">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Edit watercraft</div>
    <div class="fs-12 mono text-muted mb-16" id="edit-wc-label"></div>
    <form id="edit-wc-form">
      <input type="hidden" name="action" value="edit_watercraft">
      <input type="hidden" name="wc_id" id="edit-wc-id">
      <div class="field sm">
        <label>Name</label>
        <input type="text" name="name" id="edit-wc-name" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Activity type</label>
        <select name="activity_id" id="edit-wc-activity" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
          <option value="kayak">Kayak (solo)</option>
          <option value="kayak2">Kayak (tandem)</option>
          <option value="canoe">Canoe</option>
          <option value="paddle">Stand-up Paddleboard</option>
          <option value="cruise">Lake Cruise</option>
        </select>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="field sm">
          <label>Capacity (pax)</label>
          <input type="number" name="capacity" id="edit-wc-capacity" min="1" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
        </div>
        <div class="field sm">
          <label>Rate (RM/unit)</label>
          <input type="number" name="rate_per_unit" id="edit-wc-rate" min="0" step="0.01" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
        </div>
      </div>
      <div class="field sm">
        <label>Status</label>
        <select name="status" id="edit-wc-status" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
          <option value="AVAILABLE">Available</option>
          <option value="UNDER_MAINTENANCE">Under Maintenance</option>
        </select>
      </div>
      <div class="field sm">
        <label>Year acquired</label>
        <input type="number" name="year_acquired" id="edit-wc-year" min="2000" max="2099" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-edit-wc')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('edit-wc-form','edit_watercraft','Watercraft updated')">Save</button>
      </div>
    </form>
  </div>
</div>

<script>
function openEditWc(id, identifier, name, activity, capacity, rate, status, year) {
  document.getElementById('edit-wc-id').value = id;
  document.getElementById('edit-wc-label').textContent = identifier;
  document.getElementById('edit-wc-name').value = name;
  document.getElementById('edit-wc-activity').value = activity;
  document.getElementById('edit-wc-capacity').value = capacity;
  document.getElementById('edit-wc-rate').value = rate;
  document.getElementById('edit-wc-status').value = status;
  document.getElementById('edit-wc-year').value = year;
  openModal('modal-edit-wc');
}
async function retireWc(id, identifier) {
  if (!confirm('Retire ' + identifier + '? This cannot be undone.')) return;
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'retire_watercraft', wc_id: id });
  if (res.success) { showToast('Watercraft retired', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
