<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.security.SecureRandom, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireCustomer()) return;
Row customer = c.currentCustomer();

Row profile = Db.one("SELECT * FROM customers WHERE id=?", customer.i("id"));

String profileError = "", pwError = "";

if (c.isPost()) {
    String action = c.post("_action");

    if (action.equals("update_profile")) {
        String name  = c.postTrim("name");
        String phone = c.postTrim("phone");
        String email = c.postTrim("email");

        String phoneDigits = phone.replaceAll("\\D", "");
        if (Fn.empty(name) || Fn.empty(email)) {
            profileError = "Name and email are required.";
        } else if (!phone.isEmpty() && phoneDigits.length() != 10) {
            profileError = "Phone number must be in the format 012-3456789.";
        } else {
            if (Db.one("SELECT id FROM customers WHERE email=? AND id <> ?", email, customer.i("id")) != null) {
                profileError = "This email has already been registered.";
            } else {
                phone = !phoneDigits.isEmpty() ? phoneDigits.substring(0, 3) + "-" + phoneDigits.substring(3) : "";
                Db.exec("UPDATE customers SET name=?,phone=?,email=? WHERE id=?", name, phone, email, customer.i("id"));
                customer.put("name", name);
                customer.put("email", email);
                customer.put("phone", phone);
                c.sessSet("customer", customer);
                c.setFlash("Profile updated", "ok");
                c.redirect(c.BASE + "customer/profile.jsp");
                return;
            }
        }
    } else if (action.equals("change_password")) {
        String oldPw = c.post("old_pw");
        String newPw = c.post("new_pw");
        if (!BCrypt.verify(oldPw, profile.s("password_hash"))) {
            pwError = "Current password is incorrect.";
        } else if (newPw.length() < 8 || !newPw.matches("(?s).*[a-zA-Z].*") || !newPw.matches("(?s).*[0-9].*")) {
            pwError = "New password must be 8+ characters with letters and numbers.";
        } else {
            Db.exec("UPDATE customers SET password_hash=? WHERE id=?", BCrypt.hash(newPw), customer.i("id"));
            c.setFlash("Password updated.", "ok");
            c.redirect(c.BASE + "customer/profile.jsp");
            return;
        }
    } else if (action.equals("delete_account")) {
        // Check no active confirmed bookings
        if (Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE customer_id=? AND status='CONFIRMED'", customer.i("id")) > 0) {
            profileError = "You have an upcoming confirmed booking. Cancel it first.";
        } else {
            // Scrub personal details but keep the row so past bookings
            // (which store their own name/phone snapshot) still tally up.
            String anonEmail = "deactivated-" + customer.i("id") + "@deleted.local";
            byte[] rnd = new byte[32];
            new SecureRandom().nextBytes(rnd);
            StringBuilder hex = new StringBuilder();
            for (byte bt : rnd) hex.append(String.format("%02x", bt));
            String randomPw = BCrypt.hash(hex.toString());
            Db.exec("UPDATE customers SET name='Deactivated User', email=?, phone=NULL, ic_number=NULL, password_hash=?, status='Deactivated' WHERE id=?",
                    anonEmail, randomPw, customer.i("id"));
            c.logoutAll();
            c.setFlash("Account deactivated", "ok");
            c.redirect(c.BASE + "index.jsp");
            return;
        }
    }
}
%><%= c.pageHead("Profile") %><%= c.customerNav() %>

<div class="bsy-screen" style="max-width:700px;margin:0 auto;padding:34px 24px 80px">
  <h2 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">My profile</h2>
  <p class="fs-14 text-muted mb-22">Manage your account details and password.</p>

  <% if (!profileError.isEmpty()) { %>
    <div class="error-box mb-18"><%= Fn.h(profileError) %></div>
  <% } %>

  <!-- Profile form -->
  <form method="POST" class="card card-p mb-18">
    <input type="hidden" name="_action" value="update_profile">
    <div class="fw-800 fs-14 mb-14">Personal information</div>
    <div class="field"><label>Full name</label><input type="text" name="name" value="<%= Fn.h(profile.s("name")) %>" required></div>
    <div class="field"><label>Phone</label><input type="text" name="phone" placeholder="012-3456789" value="<%= Fn.h(profile.str("phone")) %>"></div>
    <div class="field"><label>Email</label><input type="email" name="email" value="<%= Fn.h(profile.s("email")) %>" required></div>
    <button type="submit" class="btn btn-brand">Save profile</button>
  </form>

  <!-- Password form -->
  <form method="POST" class="card card-p mb-18">
    <input type="hidden" name="_action" value="change_password">
    <div class="fw-800 fs-14 mb-14">Change password</div>
    <div class="field"><label>Current password</label><input type="password" name="old_pw" placeholder="••••••••" required></div>
    <div class="field"><label>New password</label><input type="password" name="new_pw" placeholder="8+ letters &amp; numbers" required></div>
    <% if (!pwError.isEmpty()) { %><div class="error-box mb-14"><%= Fn.h(pwError) %></div><% } %>
    <button type="submit" class="btn btn-brand">Update password</button>
  </form>

  <!-- Danger zone -->
  <div class="card card-p" style="border-color:var(--danger)">
    <div class="fw-800 fs-14 mb-6" style="color:var(--danger)">Danger zone</div>
    <div class="fs-13 text-muted mb-14">Deactivating your account will sign you out and remove your personal details (name, email, phone, IC number). Past booking records are kept for audit purposes.</div>
    <form method="POST" id="deactivate-form">
      <input type="hidden" name="_action" value="delete_account">
      <button type="button" class="btn" style="background:var(--danger-bg);color:var(--danger);border:none" onclick="openModal('modal-deactivate')">Deactivate account</button>
    </form>
  </div>

  <div class="mt-18">
    <form method="POST" action="<%= c.BASE %>logout.jsp">
      <button class="btn btn-ghost">Log out</button>
    </form>
  </div>
</div>

<!-- Deactivate confirm modal -->
<div class="bsy-overlay" id="modal-deactivate">
  <div class="bsy-modal" style="max-width:400px">
    <div class="fw-800" style="font-size:17px;margin-bottom:6px">Deactivate account?</div>
    <div class="fs-13 text-muted mb-18">Are you sure you want to deactivate your account? Your personal details will be removed. This action cannot be undone.</div>
    <div class="flex gap-10">
      <button class="btn btn-ghost flex-1" onclick="closeModal('modal-deactivate')">Cancel</button>
      <button class="btn flex-1" style="background:var(--danger);color:#fff;border:none" onclick="document.getElementById('deactivate-form').submit()">Yes, deactivate</button>
    </div>
  </div>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
