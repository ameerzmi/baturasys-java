<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

double revenue  = Db.scalarDouble("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE type='Rental'");
double expenses = Db.scalarDouble("SELECT COALESCE(SUM(ABS(amount)),0) FROM transactions WHERE type='Expense'");
int fleetAvail  = Db.scalarInt("SELECT COUNT(*) FROM watercraft WHERE status='AVAILABLE'");
int fleetTotal  = Db.scalarInt("SELECT COUNT(*) FROM watercraft WHERE status<>'RETIRED'");

List<Row> transactions = Db.all("SELECT * FROM transactions ORDER BY created_at DESC FETCH FIRST 6 ROWS ONLY");
List<Row> alerts = Db.all("SELECT * FROM alerts WHERE is_read=0 ORDER BY created_at DESC FETCH FIRST 5 ROWS ONLY");
%><%= c.pageHead("Manager Dashboard") %>
<div class="portal-wrap">
<%= c.managerSidebar("dashboard") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Dashboard</h1>
  <p class="fs-14 text-muted mb-22">Antan Batura Watersports · <%= Fn.todayLong() %></p>

  <div class="grid-4 mb-20">
    <div class="stat-card" style="background:linear-gradient(155deg,#0d7f8e,#0a6470);color:#fff">
      <div class="stat-label" style="opacity:.85">Revenue (period)</div>
      <div class="stat-value"><%= Fn.h(Fn.fmt(revenue)) %></div>
    </div>
    <div class="stat-card card">
      <div class="stat-label text-muted">Expenses</div>
      <div class="stat-value" style="color:var(--danger)"><%= Fn.h(Fn.fmt(expenses)) %></div>
    </div>
    <div class="stat-card card">
      <div class="stat-label text-muted">Net</div>
      <div class="stat-value" style="color:var(--ok)"><%= Fn.h(Fn.fmt(revenue - expenses)) %></div>
    </div>
    <div class="stat-card card">
      <div class="stat-label text-muted">Fleet available</div>
      <div class="stat-value"><%= fleetAvail %><span style="font-size:16px;color:var(--faint)"> / <%= fleetTotal %></span></div>
    </div>
  </div>

  <div style="display:grid;grid-template-columns:1.3fr 1fr;gap:18px">
    <!-- Transactions -->
    <div class="card" style="overflow:hidden">
      <div style="padding:15px 18px;border-bottom:1px solid var(--border-2);font-weight:800;font-size:14px">Recent transactions</div>
      <% for (Row t : transactions) {
        boolean rental = "Rental".equals(t.s("type"));
        double amt = t.d("amount");
      %>
      <div class="flex items-center gap-12 bsy-row" style="padding:12px 18px;border-bottom:1px solid var(--border-2)">
        <span class="badge" style="background:<%= rental ? "var(--ok-bg)" : "var(--warn-bg)" %>;color:<%= rental ? "var(--ok)" : "var(--warn)" %>;font-size:11px"><%= Fn.h(t.s("type")) %></span>
        <div style="flex:1;min-width:0">
          <div class="fw-700 fs-13 mono" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis"><%= Fn.h(t.s("ref")) %></div>
          <div class="fs-12 text-muted"><%= Fn.h(Fn.dateLabel(t.s("transaction_date"))) %> · <%= Fn.h(t.s("method")) %></div>
        </div>
        <span class="fw-800 fs-14" style="color:<%= amt < 0 ? "var(--danger)" : "var(--ink)" %>"><%= Fn.h(Fn.signedMoney(amt)) %></span>
      </div>
      <% } %>
    </div>

    <!-- Alerts -->
    <div class="card" style="overflow:hidden">
      <div style="padding:15px 18px;border-bottom:1px solid var(--border-2);display:flex;justify-content:space-between;align-items:center">
        <span class="fw-800 fs-14">Alerts requiring attention</span>
        <a href="<%= c.BASE %>manager/alerts.jsp" class="fs-12 text-brand">View all</a>
      </div>
      <% if (alerts.isEmpty()) { %>
      <div style="padding:20px;text-align:center;color:var(--muted);font-size:13px">No unread alerts</div>
      <% } %>
      <% for (Row a : alerts) {
        String sev = a.str("severity");
        String dot = sev.equals("high") ? "var(--danger)" : sev.equals("medium") ? "var(--warn)" : "var(--brand)";
      %>
      <div class="flex gap-11 bsy-row" style="padding:13px 18px;border-bottom:1px solid var(--border-2)">
        <span style="width:8px;height:8px;border-radius:50%;background:<%= dot %>;margin-top:5px;flex:none"></span>
        <div style="flex:1">
          <div class="fs-12" style="line-height:1.5"><%= Fn.h(a.s("message")) %></div>
          <div class="fs-11 text-faint mt-4 fw-700"><%= Fn.h(a.s("kind")) %></div>
        </div>
      </div>
      <% } %>
    </div>
  </div>
</div>
</main>
</div>
<%= c.logoutFab() %><%= c.pageFoot() %>
