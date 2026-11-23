<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

List<Row> equipment = Db.all("SELECT * FROM equipment ORDER BY type, size, equipment_id");

// Equipment IDs currently checked out in active bookings
Set<String> takenIds = Fn.takenEquipmentIds();
%><%= c.pageHead("Equipment") %>
<div class="portal-wrap">
<%= c.managerSidebar("equipment") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:1000px">
  <div class="flex items-center gap-14 mb-22">
    <div style="flex:1">
      <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Equipment</h1>
      <p class="fs-14 text-muted">Each row is one physical item. Add individual pieces or batch-add multiple of the same type.</p>
    </div>
    <button class="btn btn-brand" onclick="openModal('modal-add-equip')">+ Add equipment</button>
  </div>

  <div class="data-table">
    <div class="data-table-head" style="grid-template-columns:0.7fr 1.3fr 0.8fr 0.8fr 0.9fr 1fr">
      <span>ID</span><span>Item</span><span>Condition</span><span>Status</span><span>Last updated</span><span style="text-align:right">Action</span>
    </div>
    <% for (Row q : equipment) {
      boolean inUse = takenIds.contains(q.s("equipment_id"));
      String[] cond = Fn.condBadge(q.s("condition_status"));
      String status = q.str("status");
      String stBg, stFg;
      if (inUse) { stBg = "var(--info-bg)"; stFg = "var(--info)"; }
      else if (status.equals("Active"))  { stBg = "#eef1f1";          stFg = "#56646a"; }
      else if (status.equals("Flagged")) { stBg = "var(--warn-bg)";   stFg = "var(--warn)"; }
      else if (status.equals("Missing")) { stBg = "var(--danger-bg)"; stFg = "var(--danger)"; }
      else if (status.equals("Retired")) { stBg = "#f0f0f0";          stFg = "#999"; }
      else                               { stBg = "#eee";             stFg = "#888"; }
      String stLabel = inUse ? "In Use" : status;
    %>
    <div class="data-table-row bsy-row" style="grid-template-columns:0.7fr 1.3fr 0.8fr 0.8fr 0.9fr 1fr">
      <span class="fs-12 mono"><%= Fn.h(q.s("equipment_id")) %></span>
      <div>
        <div class="fw-800 fs-13"><%= Fn.h(q.s("type")) %></div>
        <div class="fs-12 text-muted"><%= Fn.h(q.s("size")) %></div>
      </div>
      <span class="badge" style="background:<%= cond[0] %>;color:<%= cond[1] %>"><%= Fn.h(q.s("condition_status")) %></span>
      <span class="badge" style="background:<%= stBg %>;color:<%= stFg %>"><%= Fn.h(stLabel) %></span>
      <span class="fs-12 text-muted"><%= q.truthy("updated_at") ? Fn.h(Fn.dateLabel(Fn.substr(q.s("updated_at"), 0, 10))) : "—" %></span>
      <div class="flex gap-10 justify-end">
        <% if (!status.equals("Retired")) { %>
        <button class="btn btn-ghost btn-xs" onclick="openEditEquip(<%= q.i("id") %>, '<%= Fn.jsAttr(q.s("equipment_id")) %>', '<%= Fn.jsAttr(q.s("type")) %>', '<%= Fn.jsAttr(q.s("size")) %>', '<%= Fn.jsAttr(q.s("condition_status")) %>')">Edit</button>
        <button class="btn btn-xs" style="background:var(--danger-bg);color:var(--danger);border:none" onclick="retireEquip(<%= q.i("id") %>, '<%= Fn.jsAttr(q.s("equipment_id")) %>')">Retire</button>
        <% } else { %>
        <span class="fs-12 text-faint">Retired</span>
        <% } %>
      </div>
    </div>
    <% } %>
  </div>
</div>
</main>
</div>

<!-- Add Equipment Modal -->
<div class="bsy-overlay" id="modal-add-equip">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:16px">Add equipment</div>
    <form id="add-equip-form">
      <input type="hidden" name="action" value="add_equipment">
      <div class="field sm">
        <label>Type <span style="color:var(--danger)">*</span></label>
        <input type="text" name="type" placeholder="e.g. Life Jacket, Paddle, Helmet" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Size / variant <span style="color:var(--danger)">*</span></label>
        <input type="text" name="size" placeholder="e.g. Adult M, Universal" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Number of items to add <span style="color:var(--danger)">*</span></label>
        <input type="number" name="count" min="1" max="50" value="1" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-add-equip')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('add-equip-form','add_equipment','Equipment added')">Add</button>
      </div>
    </form>
  </div>
</div>

<!-- Edit Equipment Modal -->
<div class="bsy-overlay" id="modal-edit-equip">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Edit equipment</div>
    <div class="fs-12 mono text-muted mb-16" id="edit-equip-label"></div>
    <form id="edit-equip-form">
      <input type="hidden" name="action" value="edit_equipment">
      <input type="hidden" name="equip_db_id" id="edit-equip-db-id">
      <div class="field sm">
        <label>Type</label>
        <input type="text" name="type" id="edit-equip-type" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Size / variant</label>
        <input type="text" name="size" id="edit-equip-size" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="field sm">
        <label>Condition</label>
        <select name="condition_status" id="edit-equip-cond" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
          <option value="Good">Good</option>
          <option value="Worn">Worn</option>
          <option value="Damaged">Damaged</option>
          <option value="Missing">Missing</option>
        </select>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-edit-equip')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('edit-equip-form','edit_equipment','Equipment updated')">Save</button>
      </div>
    </form>
  </div>
</div>

<script>
function openEditEquip(id, equipId, type, size, cond) {
  document.getElementById('edit-equip-db-id').value = id;
  document.getElementById('edit-equip-label').textContent = equipId;
  document.getElementById('edit-equip-type').value = type;
  document.getElementById('edit-equip-size').value = size;
  document.getElementById('edit-equip-cond').value = cond;
  openModal('modal-edit-equip');
}
async function retireEquip(id, equipId) {
  if (!confirm('Retire ' + equipId + '? This cannot be undone.')) return;
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'retire_equipment', equip_db_id: id });
  if (res.success) { showToast('Equipment retired', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
