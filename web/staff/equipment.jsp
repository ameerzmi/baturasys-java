<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;

List<Row> equipment = Db.all("SELECT * FROM equipment WHERE status <> 'Retired' ORDER BY type, size, equipment_id");

// Equipment IDs currently checked out
Set<String> takenIds = Fn.takenEquipmentIds();
%><%= c.pageHead("Equipment") %>
<div class="portal-wrap">
<%= c.staffSidebar("equipment") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:960px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">Equipment inventory</h1>
  <p class="fs-14 text-muted mb-22">View and update the condition of safety equipment. Flag items for replacement.</p>

  <div class="data-table">
    <div class="data-table-head" style="grid-template-columns:0.7fr 1.2fr 0.8fr 0.8fr 1fr">
      <span>ID</span><span>Item</span><span>Condition</span><span>Status</span><span style="text-align:right">Action</span>
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
      else                               { stBg = "#eee";             stFg = "#888"; }
      String stLabel = inUse ? "In Use" : status;
    %>
    <div class="data-table-row bsy-row" style="grid-template-columns:0.7fr 1.2fr 0.8fr 0.8fr 1fr">
      <span class="fs-12 mono"><%= Fn.h(q.s("equipment_id")) %></span>
      <div><div class="fw-800 fs-13"><%= Fn.h(q.s("type")) %></div><div class="fs-12 text-muted"><%= Fn.h(q.s("size")) %></div></div>
      <span class="badge" style="background:<%= cond[0] %>;color:<%= cond[1] %>"><%= Fn.h(q.s("condition_status")) %></span>
      <span class="badge" style="background:<%= stBg %>;color:<%= stFg %>"><%= Fn.h(stLabel) %></span>
      <div class="flex gap-10 justify-end">
        <button class="btn btn-ghost btn-xs" onclick="openEquipModal(<%= q.i("id") %>, '<%= Fn.jsAttr(q.s("equipment_id")) %>', '<%= Fn.jsAttr(q.s("type")) %>', '<%= Fn.jsAttr(q.s("condition_status")) %>')">Update</button>
        <% if (status.equals("Active")) { %>
        <button class="btn btn-xs" style="background:var(--warn-bg);color:var(--warn);border:none" onclick="flagEquipment(<%= q.i("id") %>)">Flag</button>
        <% } %>
      </div>
    </div>
    <% } %>
  </div>
</div>
</main>
</div>

<!-- Equipment Update Modal -->
<div class="bsy-overlay" id="modal-equip">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Update equipment</div>
    <div class="fs-12 mono text-muted mb-18" id="equip-update-info"></div>
    <form id="equip-form">
      <input type="hidden" name="equip_id" id="equip-update-id">
      <input type="hidden" name="action" value="equip_update">
      <div class="field sm">
        <label>New condition</label>
        <select name="cond" id="equip-update-cond" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
          <option value="Good">Good</option>
          <option value="Worn">Worn</option>
          <option value="Damaged">Damaged</option>
          <option value="Missing">Missing</option>
        </select>
      </div>
      <div class="field sm">
        <label>Notes <span class="text-faint" style="font-weight:500">(required for Damaged / Missing)</span></label>
        <textarea name="note" rows="2" placeholder="Explain the reason for the change" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;resize:vertical"></textarea>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-equip')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitModalForm('equip-form','equip_update','Equipment condition updated')">Save change</button>
      </div>
    </form>
  </div>
</div>

<script>
async function flagEquipment(equipId) {
  try {
    const res = await postJson(BASE_URL + 'api/staff-action', { action:'flag_equip', equip_id: equipId });
    if (res.success) { showToast('Flagged — manager alerted', 'warn'); setTimeout(()=>location.reload(), 900); }
    else showToast(res.message || 'Flag failed', 'danger');
  } catch (e) { showToast('Network error — try again', 'danger'); }
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
