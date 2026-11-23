<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (c.isCustomer()) { c.redirect(c.BASE + "customer/dashboard.jsp"); return; }

String error = "";
if (c.isPost()) {
    String email = c.postTrim("email");
    String pw    = c.post("pw");
    String lockMsg;

    if (Fn.empty(email) || Fn.empty(pw)) {
        error = "Please enter your email and password.";
    } else if ((lockMsg = Fn.checkLoginLockout(email, "customer")) != null) {
        error = lockMsg;
    } else {
        Row cu = Db.one("SELECT * FROM customers WHERE email=?", email);
        if (cu == null || !BCrypt.verify(pw, cu.s("password_hash"))) {
            Fn.recordFailedLogin(email, "customer");
            error = "Incorrect email or password. Please try again.";
        } else if ("Deactivated".equals(cu.s("status"))) {
            error = "This account has been deactivated.";
        } else {
            Fn.resetLoginAttempts(email, "customer");
            Row sessCust = new Row();
            sessCust.put("id", cu.i("id"));
            sessCust.put("name", cu.s("name"));
            sessCust.put("email", cu.s("email"));
            sessCust.put("phone", cu.s("phone"));
            c.loginCustomer(sessCust);
            c.setFlash("Welcome back, " + Fn.firstName(cu.s("name")) + "!", "ok");
            String redirect = c.has("redirect") ? c.get("redirect") : (c.BASE + "customer/dashboard.jsp");
            c.redirect(redirect);
            return;
        }
    }
}
%><%= c.pageHead("Log in") %><%= c.customerNav() %>

<div class="bsy-screen page-pad max-w-md">
  <h2 style="font-size:26px;font-weight:800;letter-spacing:-.5px;margin-bottom:6px">Welcome back</h2>
  <p class="text-muted" style="font-size:14.5px;margin:0 0 22px">Log in to manage your bookings and rentals.</p>

  <form method="POST" class="card card-p">
    <div class="field">
      <label>Email address</label>
      <input type="email" name="email" placeholder="you@email.com" value="aisyah@email.com" required>
    </div>
    <div class="field">
      <label>Password</label>
      <input type="password" name="pw" placeholder="••••••••" value="demo1234">
    </div>
    <% if (!error.isEmpty()) { %>
      <div class="error-box"><%= Fn.h(error) %></div>
    <% } %>
    <button type="submit" class="btn btn-brand w-full mt-18">Log in</button>
  </form>

  <div class="mt-18" style="text-align:center;font-size:13.5px;color:var(--muted)">
    New here? <a href="<%= c.BASE %>register.jsp" style="font-weight:700">Create an account</a>
  </div>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
