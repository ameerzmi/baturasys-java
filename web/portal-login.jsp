<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (c.isStaff())   { c.redirect(c.BASE + "staff/dashboard.jsp"); return; }
if (c.isManager()) { c.redirect(c.BASE + "manager/dashboard.jsp"); return; }

String error = "";
String role = c.get("role", "staff");
if (!role.equals("staff") && !role.equals("manager")) role = "staff";

if (c.isPost()) {
    role = c.has("role") ? c.post("role") : "staff";
    // Only two real roles. Anything else is treated as staff, so the failed-login
    // lockout (keyed on ID + role) can't be bypassed by sending role=foo1, foo2, ...
    if (!role.equals("manager")) role = "staff";
    String userId = c.postTrim("id");
    String pw     = c.post("pw");
    String lockMsg;

    if (Fn.empty(userId) || Fn.empty(pw)) {
        error = "Please enter your ID and password to continue.";
    } else if ((lockMsg = Fn.checkLoginLockout(userId, role)) != null) {
        error = lockMsg;
    } else if (role.equals("manager")) {
        Row mgr = Db.one("SELECT * FROM managers WHERE manager_id=? OR email=?", userId, userId);
        if (mgr != null && BCrypt.verify(pw, mgr.s("password_hash"))) {
            Fn.resetLoginAttempts(userId, role);
            Row m = new Row();
            m.put("id", mgr.i("id"));
            m.put("manager_id", mgr.s("manager_id"));
            m.put("name", mgr.s("name"));
            c.loginManager(m);
            c.sessSet("portal_welcome", mgr.s("name"));
            c.redirect(c.BASE + "manager/dashboard.jsp");
            return;
        } else {
            Fn.recordFailedLogin(userId, role);
            error = "Invalid Manager ID or password.";
        }
    } else {
        Row sf = Db.one("SELECT * FROM staff WHERE staff_id=? AND status='Active'", userId);
        if (sf != null && BCrypt.verify(pw, sf.s("password_hash"))) {
            Fn.resetLoginAttempts(userId, role);
            Db.exec("UPDATE staff SET last_login=CURRENT_TIMESTAMP WHERE id=?", sf.i("id"));
            Row s = new Row();
            s.put("id", sf.i("id"));
            s.put("staff_id", sf.s("staff_id"));
            s.put("name", sf.s("name"));
            s.put("role", sf.s("role"));
            c.loginStaff(s);
            c.sessSet("portal_welcome", sf.s("name"));
            c.redirect(c.BASE + "staff/dashboard.jsp");
            return;
        } else {
            Fn.recordFailedLogin(userId, role);
            error = sf == null ? "Staff ID not found or account deactivated." : "Incorrect password.";
        }
    }
}
%><%= c.pageHead("Staff & Manager Login") %>

<div class="portal-login-wrap">
  <div class="portal-login-card">
    <a href="<%= c.BASE %>index.jsp" style="background:none;border:none;color:var(--muted);font-weight:700;font-size:13.5px;display:block;margin-bottom:22px;text-decoration:none">← Back to booking site</a>

    <div style="display:flex;align-items:center;gap:11px;margin-bottom:6px">
      <div style="width:40px;height:40px;border-radius:11px;background:var(--brand);display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;font-size:18px;box-shadow:0 6px 18px rgba(13,127,142,.35)">≈</div>
      <div style="font-size:21px;font-weight:800;letter-spacing:-.4px">BaturaSys</div>
    </div>
    <div class="fs-14 text-muted mb-22">Staff &amp; Manager sign in · internal access</div>

    <div class="card card-p">
      <!-- Role tabs -->
      <div class="role-tabs">
        <button class="role-tab bsy-tap" data-role="staff" onclick="updateLoginRole('staff')" id="tab-staff"
          style="background:#fff;color:var(--brand-dark);box-shadow:0 1px 3px rgba(15,38,44,.12)">🦺 Staff</button>
        <button class="role-tab bsy-tap" data-role="manager" onclick="updateLoginRole('manager')" id="tab-manager"
          style="background:transparent;color:var(--muted)">📊 Manager</button>
      </div>

      <form method="POST" id="login-form">
        <input type="hidden" name="role" id="login-role" value="staff">

        <div class="field">
          <label id="id-label">Staff ID</label>
          <input type="text" name="id" id="id-input" placeholder="BS-0002" value="BS-0002" class="mono" autocomplete="off">
        </div>
        <div class="field">
          <label>Password</label>
          <input type="password" name="pw" placeholder="••••••••" value="batura123">
        </div>
        <% if (!error.isEmpty()) { %>
          <div class="error-box"><%= Fn.h(error) %></div>
        <% } %>
        <button type="submit" class="btn btn-brand w-full mt-20" id="submit-btn">Sign in as Staff</button>
      </form>

      <div class="demo-hint">
        Demo access — any ID and password. Suggested:
        <span class="mono" style="color:var(--ink)" id="hint-id">BS-0002</span> / <span class="mono" style="color:var(--ink)">batura123</span>
      </div>
    </div>

    <div style="margin-top:22px;text-align:center;font-size:12px;color:var(--faint)">Dev Dynamos · ISP501 System Requirements &amp; Analysis</div>
  </div>
</div>

<script>
// Wraps the shared setRole() (from app.js) to also update the submit button label.
// Must be a distinct name — app.js loads after this inline script and would
// otherwise silently overwrite a same-named function declaration.
function updateLoginRole(role) {
  setRole(role);
  const btn = document.getElementById('submit-btn');
  if (btn) btn.textContent = 'Sign in as ' + (role === 'manager' ? 'Manager' : 'Staff');
}
// Init with correct role
document.addEventListener('DOMContentLoaded', () => updateLoginRole('staff'));
</script>

<%= c.pageFoot() %>
