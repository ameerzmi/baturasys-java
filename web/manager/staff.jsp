<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

List<Row> staffList = Db.all("SELECT * FROM staff ORDER BY staff_id");
%><%= c.pageHead("Staff Accounts") %>
<div class="portal-wrap">
<%= c.managerSidebar("staff") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:960px">
  <div class="flex items-center gap-14 mb-22">
    <div style="flex:1">
      <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Staff accounts</h1>
      <p class="fs-14 text-muted">Add and manage staff logins. Staff log in with their ID and password.</p>
    </div>
    <button class="btn btn-brand" onclick="openModal('modal-add-staff')">+ Add staff</button>
  </div>

  <div class="data-table">
    <div class="data-table-head" style="grid-template-columns:0.8fr 1.5fr 1.2fr 0.7fr 0.9fr 1fr">
      <span>Staff ID</span><span>Name</span><span>Email</span><span>Status</span><span>Last login</span><span style="text-align:right">Actions</span>
    </div>
    <% for (Row s : staffList) {
      boolean activeSt = "Active".equals(s.s("status"));
    %>
    <div class="data-table-row bsy-row" style="grid-template-columns:0.8fr 1.5fr 1.2fr 0.7fr 0.9fr 1fr">
      <span class="fs-12 mono fw-700"><%= Fn.h(s.s("staff_id")) %></span>
      <div>
        <div class="fw-800 fs-13"><%= Fn.h(s.s("name")) %></div>
        <div class="fs-12 text-muted"><%= Fn.h(Fn.coalesce(s.s("phone"), "—")) %></div>
      </div>
      <span class="fs-13"><%= Fn.h(Fn.coalesce(s.s("email"), "—")) %></span>
      <span class="badge" style="background:<%= activeSt ? "var(--ok-bg)" : "var(--danger-bg)" %>;color:<%= activeSt ? "var(--ok)" : "var(--danger)" %>"><%= Fn.h(s.s("status")) %></span>
      <span class="fs-12 text-muted"><%= s.truthy("last_login") ? Fn.h(Fn.dateLabel(Fn.substr(s.s("last_login"), 0, 10))) : "Never" %></span>
      <div class="flex gap-8 justify-end">
        <button class="btn btn-ghost btn-xs" onclick="openResetPw(<%= s.i("id") %>, '<%= Fn.jsAttr(s.s("staff_id")) %>', '<%= Fn.jsAttr(s.s("name")) %>')">Reset PW</button>
        <% if (activeSt) { %>
        <button class="btn btn-xs" style="background:var(--danger-bg);color:var(--danger);border:none" onclick="deactivateStaff(<%= s.i("id") %>, '<%= Fn.jsAttr(s.s("name")) %>')">Deactivate</button>
        <% } else { %>
        <button class="btn btn-xs" style="background:var(--ok-bg);color:var(--ok);border:none" onclick="activateStaff(<%= s.i("id") %>, '<%= Fn.jsAttr(s.s("name")) %>')">Activate</button>
        <% } %>
      </div>
    </div>
    <% } %>
  </div>
</div>
</main>
</div>

<!-- Add Staff Modal -->
<div class="bsy-overlay" id="modal-add-staff">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:16px">Add staff account</div>
    <form id="add-staff-form">
      <input type="hidden" name="action" value="add_staff">
      <div class="field sm">
        <label>Full name <span style="color:var(--danger)">*</span></label>
        <input type="text" name="name" placeholder="Staff member's full name" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required>
      </div>
      <div class="field sm">
        <label>Email</label>
        <input type="email" name="email" placeholder="staff@email.com" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="field sm">
        <label>Phone</label>
        <input type="text" name="phone" placeholder="01X-XXXXXXXX" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="field sm">
        <label>Password <span style="color:var(--danger)">*</span></label>
        <input type="password" name="password" placeholder="Minimum 8 characters" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required minlength="8">
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-add-staff')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('add-staff-form','add_staff','Staff account created')">Create account</button>
      </div>
    </form>
  </div>
</div>

<!-- Reset Password Modal -->
<div class="bsy-overlay" id="modal-reset-pw">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Reset password</div>
    <div class="fs-13 text-muted mb-18" id="reset-pw-info"></div>
    <form id="reset-pw-form">
      <input type="hidden" name="action" value="reset_staff_pw">
      <input type="hidden" name="staff_db_id" id="reset-pw-db-id">
      <div class="field sm">
        <label>New password <span style="color:var(--danger)">*</span></label>
        <input type="password" name="new_password" placeholder="Minimum 8 characters" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" required minlength="8">
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-reset-pw')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitManagerForm('reset-pw-form','reset_staff_pw','Password reset successfully')">Reset</button>
      </div>
    </form>
  </div>
</div>

<script>
function openResetPw(id, staffId, name) {
  document.getElementById('reset-pw-db-id').value = id;
  document.getElementById('reset-pw-info').textContent = staffId + ' · ' + name;
  openModal('modal-reset-pw');
}
async function deactivateStaff(id, name) {
  if (!confirm('Deactivate ' + name + '? They will no longer be able to log in.')) return;
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'deactivate_staff', staff_db_id: id });
  if (res.success) { showToast('Staff deactivated', 'warn'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
async function activateStaff(id, name) {
  if (!confirm('Reactivate ' + name + '?')) return;
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'activate_staff', staff_db_id: id });
  if (res.success) { showToast('Staff activated', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
