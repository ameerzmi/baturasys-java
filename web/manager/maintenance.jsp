<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

List<Row> tasks = Db.all("SELECT t.*, w.name as wc_name, s.name as staff_name FROM maintenance_tasks t "
    + "LEFT JOIN watercraft w ON t.watercraft_id = w.identifier "
    + "LEFT JOIN staff s ON t.assignee_id = s.staff_id "
    + "ORDER BY CASE WHEN t.status='OVERDUE' THEN 1 WHEN t.status='IN_PROGRESS' THEN 2 WHEN t.status='SCHEDULED' THEN 3 WHEN t.status='COMPLETED' THEN 4 WHEN t.status='APPROVED' THEN 5 ELSE 0 END, t.scheduled_date");

List<Row> staff = Db.all("SELECT staff_id, name FROM staff WHERE status='Active' ORDER BY name");
List<Row> watercraft = Db.all("SELECT identifier, name FROM watercraft WHERE status <> 'RETIRED' ORDER BY identifier");

Map<String, String[]> stMap = new HashMap<String, String[]>();
stMap.put("SCHEDULED",   new String[]{"Scheduled", "#eef1f1", "#56646a"});
stMap.put("IN_PROGRESS", new String[]{"In progress", "var(--info-bg)", "var(--info)"});
stMap.put("COMPLETED",   new String[]{"Pending approval", "var(--warn-bg)", "var(--warn)"});
stMap.put("OVERDUE",     new String[]{"Overdue", "var(--danger-bg)", "var(--danger)"});
stMap.put("APPROVED",    new String[]{"Approved", "var(--ok-bg)", "var(--ok)"});
%><%= c.pageHead("Maintenance") %>
<div class="portal-wrap">
<%= c.managerSidebar("maintenance") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:1020px">
  <div class="flex items-center gap-14 mb-22">
    <div style="flex:1">
      <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Maintenance schedule</h1>
      <p class="fs-14 text-muted">Schedule tasks, review completed work, and approve or reopen maintenance reports.</p>
    </div>
    <button class="btn btn-brand" onclick="openModal('modal-schedule')">+ Schedule task</button>
  </div>

  <% if (tasks.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">🔧</div>
    <div class="fw-800 fs-16 mb-6">No maintenance tasks</div>
    <div class="fs-13 text-muted">Schedule a task to get started.</div>
  </div>
  <% } else { %>
  <div style="display:flex;flex-direction:column;gap:13px">
    <% for (Row t : tasks) {
      String status = t.str("status");
      String[] st = stMap.containsKey(status) ? stMap.get(status) : new String[]{status, "#eee", "#555"};
    %>
    <div class="card card-p">
      <div class="flex items-center gap-14">
        <span style="width:44px;height:44px;border-radius:11px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font-size:20px;flex:none">🔧</span>
        <div style="flex:1">
          <div class="fw-800 fs-14"><%= Fn.h(t.s("type")) %> · <%= Fn.h(Fn.coalesce(t.s("wc_name"), t.s("watercraft_id"))) %></div>
          <div class="fs-12 text-muted mt-4">
            Assigned to <b><%= Fn.h(Fn.coalesce(t.s("staff_name"), t.s("assignee_id"))) %></b> ·
            <%= Fn.h(Fn.dateLabel(t.s("scheduled_date"))) %> ·
            <%= t.i("recurring_days") > 0 ? "Every " + t.i("recurring_days") + " days" : "One-off" %>
          </div>
        </div>
        <span class="badge" style="background:<%= st[1] %>;color:<%= st[2] %>"><%= Fn.h(st[0]) %></span>
        <div class="flex gap-10">
          <% if (status.equals("COMPLETED")) { %>
          <button class="btn btn-ok btn-sm" onclick="approveTask(<%= t.i("id") %>)">Approve</button>
          <button class="btn btn-sm" style="background:var(--warn-bg);color:var(--warn);border:none" onclick="reopenTask(<%= t.i("id") %>)">Reopen</button>
          <% } else if (status.equals("APPROVED")) { %>
          <button class="btn btn-ghost btn-sm" onclick="reopenTask(<%= t.i("id") %>)">Reopen</button>
          <% } %>
        </div>
      </div>
      <% if (t.truthy("notes")) { %>
      <div style="margin-top:11px;background:var(--surface-2);border-radius:9px;padding:10px 12px;font-size:12.5px;color:var(--muted)">
        <b style="color:var(--ink)">Notes:</b> <%= Fn.h(t.s("notes")) %>
      </div>
      <% } %>
    </div>
    <% } %>
  </div>
  <% } %>
</div>
</main>
</div>

<!-- Schedule Task Modal -->
<div class="bsy-overlay" id="modal-schedule">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:16px">Schedule maintenance task</div>
    <form id="schedule-form">
      <input type="hidden" name="action" value="schedule_task">
      <div class="field sm">
        <label>Task type <span style="color:var(--danger)">*</span></label>
        <input type="text" name="type" placeholder="e.g. Hull inspection, Engine check" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Watercraft <span style="color:var(--danger)">*</span></label>
        <select name="watercraft_id" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff" required>
          <option value="">— Select watercraft —</option>
          <% for (Row w : watercraft) { %>
          <option value="<%= Fn.h(w.s("identifier")) %>"><%= Fn.h(w.s("identifier")) %> · <%= Fn.h(w.s("name")) %></option>
          <% } %>
        </select>
      </div>
      <div class="field sm">
        <label>Assign to <span style="color:var(--danger)">*</span></label>
        <select name="assignee_id" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff" required>
          <option value="">— Select staff —</option>
          <% for (Row s : staff) { %>
          <option value="<%= Fn.h(s.s("staff_id")) %>"><%= Fn.h(s.s("staff_id")) %> · <%= Fn.h(s.s("name")) %></option>
          <% } %>
        </select>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="field sm">
          <label>Scheduled date <span style="color:var(--danger)">*</span></label>
          <input type="date" name="scheduled_date" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
        </div>
        <div class="field sm">
          <label>Repeat every (days)</label>
          <input type="number" name="recurring_days" min="0" value="0" placeholder="0 = one-off" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
        </div>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-schedule')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('schedule-form','schedule_task','Task scheduled')">Schedule</button>
      </div>
    </form>
  </div>
</div>

<script>
async function approveTask(taskId) {
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'approve_task', task_id: taskId });
  if (res.success) { showToast('Task approved', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
async function reopenTask(taskId) {
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'reopen_task', task_id: taskId });
  if (res.success) { showToast('Task reopened', 'warn'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
