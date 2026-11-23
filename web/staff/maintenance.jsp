<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;
Row staff = c.currentStaff();

List<Row> tasks = Db.all("SELECT t.*, w.name as wc_name FROM maintenance_tasks t "
    + "LEFT JOIN watercraft w ON t.watercraft_id = w.identifier "
    + "WHERE t.assignee_id = ? AND t.status NOT IN ('APPROVED') "
    + "ORDER BY CASE WHEN t.status='OVERDUE' THEN 1 WHEN t.status='IN_PROGRESS' THEN 2 WHEN t.status='SCHEDULED' THEN 3 WHEN t.status='COMPLETED' THEN 4 WHEN t.status='APPROVED' THEN 5 ELSE 0 END, t.scheduled_date", staff.s("staff_id"));

Map<String, String[]> stMap = new HashMap<String, String[]>();
stMap.put("SCHEDULED",   new String[]{"Scheduled", "#eef1f1", "#56646a"});
stMap.put("IN_PROGRESS", new String[]{"In progress", "var(--info-bg)", "var(--info)"});
stMap.put("COMPLETED",   new String[]{"Completed (awaiting approval)", "var(--warn-bg)", "var(--warn)"});
stMap.put("OVERDUE",     new String[]{"Overdue", "var(--danger-bg)", "var(--danger)"});
stMap.put("APPROVED",    new String[]{"Approved", "var(--ok-bg)", "var(--ok)"});
%><%= c.pageHead("Maintenance") %>
<div class="portal-wrap">
<%= c.staffSidebar("maintenance") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:860px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">My maintenance tasks</h1>
  <p class="fs-14 text-muted mb-22">Start scheduled tasks, log notes, and submit completed work for manager approval.</p>

  <% if (tasks.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">🔧</div>
    <div class="fw-800 fs-16 mb-6">No tasks assigned</div>
    <div class="fs-13 text-muted">You have no pending maintenance tasks.</div>
  </div>
  <% } else { %>
  <div style="display:flex;flex-direction:column;gap:13px">
    <% for (Row t : tasks) {
      String status = t.str("status");
      String[] st = stMap.containsKey(status) ? stMap.get(status) : new String[]{status, "#eee", "#555"};
      boolean canStart    = status.equals("SCHEDULED") || status.equals("OVERDUE");
      boolean canComplete = status.equals("IN_PROGRESS");
      String wcName = Fn.coalesce(t.s("wc_name"), t.s("watercraft_id"));
    %>
    <div class="card card-p">
      <div class="flex items-center gap-14">
        <span style="width:42px;height:42px;border-radius:11px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;font-size:19px;flex:none">🔧</span>
        <div style="flex:1">
          <div class="fw-800 fs-14"><%= Fn.h(t.s("type")) %> · <%= Fn.h(wcName) %></div>
          <div class="fs-12 text-muted mt-4">
            <%= Fn.h(Fn.dateLabel(t.s("scheduled_date"))) %> ·
            <%= t.i("recurring_days") > 0 ? "Every " + t.i("recurring_days") + " days" : "One-off" %>
          </div>
        </div>
        <span class="badge" style="background:<%= st[1] %>;color:<%= st[2] %>"><%= Fn.h(st[0]) %></span>
        <div class="flex gap-10">
          <% if (canStart) { %>
          <button class="btn btn-brand btn-sm" onclick="startTask(<%= t.i("id") %>)">Start task</button>
          <% } else if (canComplete) { %>
          <button class="btn btn-sm" style="background:var(--ok);color:#fff;border:none" onclick="openCompleteModal(<%= t.i("id") %>, '<%= Fn.jsAttr(t.s("type")) %>', '<%= Fn.jsAttr(wcName) %>')">Mark done</button>
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

<!-- Complete Modal -->
<div class="bsy-overlay" id="modal-complete">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Mark task complete</div>
    <div class="fs-13 text-muted mb-18" id="complete-task-info"></div>
    <form id="complete-form">
      <input type="hidden" name="task_id" id="complete-task-id">
      <input type="hidden" name="action" value="task_complete">
      <div class="field sm">
        <label>Maintenance notes <span style="color:var(--danger)">*</span></label>
        <textarea name="note" rows="3" placeholder="Describe what was done" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;resize:vertical" required></textarea>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-complete')">Cancel</button>
        <button type="button" class="btn btn-ok flex-1" onclick="submitModalForm('complete-form','task_complete','Task submitted for approval')">Mark completed</button>
      </div>
    </form>
  </div>
</div>

<script>
async function startTask(taskId) {
  try {
    const res = await postJson(BASE_URL + 'api/staff-action', { action:'task_start', task_id: taskId });
    if (res.success) { showToast('Task started — watercraft under maintenance', 'ok'); setTimeout(()=>location.reload(), 900); }
    else showToast(res.message || 'Start failed', 'danger');
  } catch (e) { showToast('Network error — try again', 'danger'); }
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
