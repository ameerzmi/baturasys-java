<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (c.isCustomer()) { c.redirect(c.BASE + "customer/dashboard.jsp"); return; }

String error = "";
String prefillName = "", prefillPhone = "", prefillEmail = "";

// Pre-fill from guest booking
if (!Fn.empty(c.get("name"))) prefillName = c.get("name").trim();
if (!Fn.empty(c.get("phone"))) prefillPhone = c.get("phone").trim();

if (c.isPost()) {
    String name  = c.postTrim("name");
    String phone = c.postTrim("phone");
    String email = c.postTrim("email");
    String ic    = c.postTrim("ic");
    String pw    = c.post("pw");

    if (Fn.empty(name) || Fn.empty(email) || Fn.empty(pw)) {
        error = "Please fill in all required fields.";
    } else if (pw.length() < 8 || !pw.matches("(?s).*[a-zA-Z].*") || !pw.matches("(?s).*[0-9].*")) {
        error = "Password must be at least 8 characters with letters and numbers.";
    } else if (!Fn.empty(ic) && !ic.matches("\\d{12}")) {
        error = "IC number must be exactly 12 digits with no dashes.";
    } else {
        // Check duplicate email
        if (Db.one("SELECT id FROM customers WHERE email=?", email) != null) {
            error = "An account with this email already exists. Try logging in.";
        } else {
            String hash = BCrypt.hash(pw);
            long id = Db.insert("INSERT INTO customers (name,email,phone,ic_number,password_hash) VALUES (?,?,?,?,?)",
                    name, email, phone, Fn.empty(ic) ? null : ic, hash);
            Row sessCust = new Row();
            sessCust.put("id", (int) id);
            sessCust.put("name", name);
            sessCust.put("email", email);
            sessCust.put("phone", phone);
            c.loginCustomer(sessCust);
            c.setFlash("Account created — welcome to BaturaSys!", "ok");
            c.redirect(c.BASE + "customer/dashboard.jsp");
            return;
        }
    }
}
%><%= c.pageHead("Sign up") %><%= c.customerNav() %>

<div class="bsy-screen page-pad max-w-lg">
  <h2 style="font-size:26px;font-weight:800;letter-spacing:-.5px;margin-bottom:6px">Create your account</h2>
  <p class="text-muted" style="font-size:14.5px;margin:0 0 22px;line-height:1.5">Unlock full booking history and faster checkout. Takes under a minute.</p>

  <form method="POST" class="card card-p">
    <div class="grid-2">
      <div class="field sm">
        <label>Full name <span style="color:var(--danger)">*</span></label>
        <input type="text" name="name" placeholder="Nurul Aisyah" value="<%= Fn.h(prefillName) %>" required>
      </div>
      <div class="field sm">
        <label>Phone</label>
        <input type="text" name="phone" placeholder="012-3456789" value="<%= Fn.h(prefillPhone) %>">
      </div>
    </div>
    <div class="field sm mt-14">
      <label>Email <span style="color:var(--danger)">*</span></label>
      <input type="email" name="email" placeholder="you@email.com" value="<%= Fn.h(prefillEmail) %>" required>
    </div>
    <div class="grid-2 mt-14">
      <div class="field sm">
        <label>IC number</label>
        <input type="text" name="ic" placeholder="12 digits, no dashes" class="mono">
      </div>
      <div class="field sm">
        <label>Password <span style="color:var(--danger)">*</span></label>
        <input type="password" name="pw" placeholder="8+ letters &amp; numbers" required>
      </div>
    </div>
    <% if (!error.isEmpty()) { %>
      <div class="error-box"><%= Fn.h(error) %></div>
    <% } %>
    <button type="submit" class="btn btn-brand w-full mt-18">Create account</button>
    <p class="fs-12 text-faint mt-8" style="line-height:1.5">Each email may be linked to one account. Passwords are stored securely (bcrypt).</p>
  </form>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
