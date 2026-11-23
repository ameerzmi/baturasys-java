<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireCustomer()) return;
Row customer = c.currentCustomer();

// Group bookings by group_ref so multi-item carts show as one entry
List<Row> bookings = Fn.groupBookings(Db.all("SELECT * FROM bookings WHERE customer_id=? ORDER BY id", customer.i("id")));
Fn.sortByCreated(bookings, true);

int upcoming = 0, completed = 0;
double spent = 0;
for (Row b : bookings) {
    String s = b.s("status");
    if ("CONFIRMED".equals(s) || "AWAITING_VERIFICATION".equals(s) || "PENDING_PAYMENT".equals(s)) upcoming++;
    if ("COMPLETED".equals(s)) completed++;
    if ("COMPLETED".equals(s) || "CONFIRMED".equals(s)) spent += b.d("amount");
}
%><%= c.pageHead("My bookings") %><%= c.customerNav("dashboard") %>

<div class="bsy-screen" style="max-width:900px;margin:0 auto;padding:34px 24px 80px">
  <div class="flex items-center justify-between mb-20">
    <div>
      <h2 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">My bookings</h2>
      <div class="fs-14 text-muted">Welcome back, <%= Fn.h(Fn.firstName(customer.s("name"))) %></div>
    </div>
    <a href="<%= c.BASE %>booking/step1.jsp" class="btn btn-brand">+ New booking</a>
  </div>

  <!-- Stats -->
  <div class="grid-3 mb-22">
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Upcoming</div>
      <div style="font-size:28px;font-weight:800;color:var(--brand)"><%= upcoming %></div>
    </div>
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Completed</div>
      <div style="font-size:28px;font-weight:800"><%= completed %></div>
    </div>
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Total spent</div>
      <div style="font-size:28px;font-weight:800;color:var(--ok)"><%= Fn.h(Fn.fmt(spent)) %></div>
    </div>
  </div>

  <!-- Booking list -->
  <% if (bookings.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">🛶</div>
    <div class="fw-800 fs-16 mb-6">No bookings yet</div>
    <div class="fs-13 text-muted mb-18">Book your first watersports activity today.</div>
    <a href="<%= c.BASE %>booking/step1.jsp" class="btn btn-brand">Book an activity</a>
  </div>
  <% } else { %>
  <div style="display:flex;flex-direction:column;gap:12px">
    <% for (Row b : bookings) {
      String[] st = Fn.statusBadge(b.s("status"));
      Activity meta = Fn.activityMeta(b.s("activity_id"));
      // Build compact activity label for multi-item groups
      Map<String, Integer> actCounts = Fn.countValues(b.s("activity_ids"));
      String actTitle;
      if (actCounts.size() == 1 && actCounts.values().iterator().next() == 1) {
          actTitle = meta.name;
      } else {
          List<String> parts = new ArrayList<String>();
          for (Map.Entry<String, Integer> e : actCounts.entrySet()) {
              Activity am = Fn.activityMeta(e.getKey());
              parts.add(am.name + (e.getValue() > 1 ? " ×" + e.getValue() : ""));
          }
          actTitle = String.join(", ", parts);
      }
    %>
    <a href="<%= c.BASE %>booking/status.jsp?id=<%= b.i("first_id") %>" class="card bsy-row bsy-tap" style="display:flex;align-items:center;gap:14px;padding:16px 20px;text-decoration:none;color:var(--ink)">
      <div style="width:44px;height:44px;border-radius:10px;background:<%= Fn.h(meta.swatch) %>;display:flex;align-items:center;justify-content:center;font-size:20px;flex:none"><%= meta.emoji %></div>
      <div style="flex:1;min-width:0">
        <div class="fw-800 fs-14"><%= Fn.h(actTitle) %></div>
        <div class="fs-12 text-muted mono mt-4"><%= Fn.h(b.s("gref")) %></div>
        <div class="fs-12 text-muted mt-4"><%= Fn.h(Fn.dateLabel(b.s("booking_date"))) %></div>
      </div>
      <div style="text-align:right">
        <span class="badge mb-6" style="background:<%= st[1] %>;color:<%= st[2] %>;display:block;text-align:center"><%= Fn.h(st[0]) %></span>
        <div class="fw-800 fs-14" style="color:var(--brand)"><%= Fn.h(Fn.fmt(b.d("amount"))) %></div>
      </div>
    </a>
    <% } %>
  </div>
  <% } %>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
