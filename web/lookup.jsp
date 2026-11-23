<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

String error = "";
if (c.isPost()) {
    String ref = c.postTrim("ref").toUpperCase();
    if (Fn.empty(ref)) {
        error = "Please enter a booking reference.";
    } else {
        // Find by group_ref (customer-visible) or individual ref
        Row b = Db.one("SELECT id, ref, group_ref FROM bookings WHERE group_ref=? OR ref=? ORDER BY id FETCH FIRST 1 ROWS ONLY", ref, ref);
        if (b == null) {
            error = "No booking found with this reference number. Please check and try again.";
        } else {
            c.allowBookingGroup(Ctx.groupOf(b));   // knowing the reference grants access

            c.redirect(c.BASE + "booking/status.jsp?id=" + b.i("id"));
            return;
        }
    }
}
%><%= c.pageHead("Check booking") %><%= c.customerNav("lookup") %>

<div class="bsy-screen page-pad max-w-lg" style="max-width:520px">
  <h2 style="font-size:26px;font-weight:800;letter-spacing:-.5px;margin-bottom:8px">Check your booking</h2>
  <p class="text-muted" style="font-size:14.5px;margin:0 0 26px;line-height:1.5">Enter the reference number from your booking confirmation (format <span class="mono" style="font-size:13px">BSY-YYYYMMDD-XXXX</span>).</p>

  <form method="POST" class="card card-p">
    <div class="field">
      <label>Booking reference</label>
      <input type="text" name="ref" placeholder="BSY-20260618-0007" class="mono" style="text-transform:uppercase" value="<%= Fn.h(c.post("ref")) %>">
    </div>
    <% if (!error.isEmpty()) { %>
      <div class="error-box"><%= Fn.h(error) %></div>
    <% } %>
    <button type="submit" class="btn btn-brand w-full mt-18">Check status</button>
  </form>

  <div style="margin-top:16px;text-align:center;font-size:13.5px;color:var(--muted)">
    Have an account? <a href="<%= c.BASE %>login.jsp" style="font-weight:700">Log in to see all bookings</a>
  </div>
  <div style="margin-top:8px;text-align:center;font-size:12px;color:var(--faint)">
    Try <span class="mono">BSY-20260618-0007</span>
  </div>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
