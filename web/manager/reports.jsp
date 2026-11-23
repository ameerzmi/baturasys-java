<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.time.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

String period = c.get("period", "month");
String from   = c.get("from");
String to     = c.get("to");

LocalDate today = LocalDate.now();
String dateFrom, dateTo;
if (period.equals("custom") && !Fn.empty(from) && !Fn.empty(to)) {
    dateFrom = from;
    dateTo   = to;
} else if (period.equals("week")) {
    dateFrom = today.with(DayOfWeek.MONDAY).toString();
    dateTo   = today.toString();
} else if (period.equals("year")) {
    dateFrom = today.withDayOfYear(1).toString();
    dateTo   = today.toString();
} else {
    dateFrom = today.withDayOfMonth(1).toString();
    dateTo   = today.toString();
}

double revenue  = Db.scalarDouble("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE type='Rental' AND transaction_date BETWEEN ? AND ?", dateFrom, dateTo);
double expenses = Db.scalarDouble("SELECT COALESCE(SUM(ABS(amount)),0) FROM transactions WHERE type='Expense' AND transaction_date BETWEEN ? AND ?", dateFrom, dateTo);
int txCount     = Db.scalarInt("SELECT COUNT(*) FROM transactions WHERE transaction_date BETWEEN ? AND ?", dateFrom, dateTo);

List<Row> transactions = Db.all("SELECT * FROM transactions WHERE transaction_date BETWEEN ? AND ? ORDER BY transaction_date DESC, created_at DESC", dateFrom, dateTo);

List<Row> byType = Db.all("SELECT type, SUM(amount) as total, COUNT(*) as cnt FROM transactions WHERE transaction_date BETWEEN ? AND ? GROUP BY type ORDER BY total DESC", dateFrom, dateTo);
%><%= c.pageHead("Financial Reports") %>
<div class="portal-wrap">
<%= c.managerSidebar("reports") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:1020px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Financial reports</h1>
  <p class="fs-14 text-muted mb-18">View revenue, expenses, and transaction history by period.</p>

  <!-- Period filter -->
  <form method="GET" class="card card-p mb-20" style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap">
    <div>
      <div class="fs-12 fw-700 mb-6">Period</div>
      <select name="period" onchange="this.form.submit()" style="padding:10px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
        <option value="week" <%= period.equals("week") ? "selected" : "" %>>This week</option>
        <option value="month" <%= period.equals("month") ? "selected" : "" %>>This month</option>
        <option value="year" <%= period.equals("year") ? "selected" : "" %>>This year</option>
        <option value="custom" <%= period.equals("custom") ? "selected" : "" %>>Custom range</option>
      </select>
    </div>
    <% if (period.equals("custom")) { %>
    <div>
      <div class="fs-12 fw-700 mb-6">From</div>
      <input type="date" name="from" value="<%= Fn.h(from) %>" style="padding:10px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
    </div>
    <div>
      <div class="fs-12 fw-700 mb-6">To</div>
      <input type="date" name="to" value="<%= Fn.h(to) %>" style="padding:10px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
    </div>
    <button type="submit" class="btn btn-brand">Apply</button>
    <% } %>
    <div class="fs-12 text-muted" style="align-self:center">
      <%= Fn.h(Fn.dateLabel(dateFrom)) %> – <%= Fn.h(Fn.dateLabel(dateTo)) %>
    </div>
  </form>

  <!-- KPI summary -->
  <div class="grid-4 mb-20">
    <div class="stat-card" style="background:linear-gradient(155deg,#0d7f8e,#0a6470);color:#fff">
      <div class="stat-label" style="opacity:.85">Revenue</div>
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
      <div class="stat-label text-muted">Transactions</div>
      <div class="stat-value"><%= txCount %></div>
    </div>
  </div>

  <div style="display:grid;grid-template-columns:1.6fr 1fr;gap:18px;margin-bottom:18px">
    <!-- Transaction log -->
    <div class="card" style="overflow:hidden">
      <div style="padding:15px 18px;border-bottom:1px solid var(--border-2);font-weight:800;font-size:14px">Transaction log</div>
      <% if (transactions.isEmpty()) { %>
      <div style="padding:28px;text-align:center;color:var(--muted);font-size:13px">No transactions in this period.</div>
      <% } %>
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

    <!-- Breakdown by type -->
    <div class="card" style="overflow:hidden">
      <div style="padding:15px 18px;border-bottom:1px solid var(--border-2);font-weight:800;font-size:14px">Breakdown</div>
      <% if (byType.isEmpty()) { %>
      <div style="padding:28px;text-align:center;color:var(--muted);font-size:13px">No data.</div>
      <% } %>
      <% for (Row bt : byType) {
        double btAmt = bt.d("total");
        String btBg = btAmt >= 0 ? "var(--ok-bg)" : "var(--danger-bg)";
        String btFg = btAmt >= 0 ? "var(--ok)" : "var(--danger)";
      %>
      <div class="bsy-row" style="padding:14px 18px;border-bottom:1px solid var(--border-2)">
        <div class="flex items-center gap-10">
          <span class="badge" style="background:<%= btBg %>;color:<%= btFg %>"><%= Fn.h(bt.s("type")) %></span>
          <span class="fs-13 text-muted"><%= bt.i("cnt") %> tx</span>
        </div>
        <div class="fw-800 fs-16 mt-8" style="color:<%= btFg %>">
          <%= Fn.signedMoney(btAmt) %>
        </div>
      </div>
      <% } %>
    </div>
  </div>
</div>
</main>
</div>

<%= c.logoutFab() %><%= c.pageFoot() %>
