<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%!
// renderAlertCard() from the PHP version
static String renderAlertCard(Row a) {
    String sev = a.str("severity");
    String dot   = sev.equals("high") ? "var(--danger)"    : sev.equals("medium") ? "var(--warn)"    : "var(--brand)";
    String sevBg = sev.equals("high") ? "var(--danger-bg)" : sev.equals("medium") ? "var(--warn-bg)" : "var(--info-bg)";
    String sevFg = sev.equals("high") ? "var(--danger)"    : sev.equals("medium") ? "var(--warn)"    : "var(--info)";
    boolean read = a.truthy("is_read");
    String created = a.str("created_at");
    StringBuilder sb = new StringBuilder();
    sb.append("    <div class=\"card card-p flex gap-14 items-start\" style=\"").append(read ? "opacity:.65" : "").append("\">\n")
      .append("      <span style=\"width:10px;height:10px;border-radius:50%;background:").append(dot).append(";margin-top:4px;flex:none\"></span>\n")
      .append("      <div style=\"flex:1\">\n")
      .append("        <div class=\"flex items-center gap-10 mb-4\">\n")
      .append("          <span class=\"badge\" style=\"background:").append(sevBg).append(";color:").append(sevFg).append(";font-size:11px\">")
      .append(Fn.h(Fn.ucfirst(sev))).append("</span>\n");
    if (read) sb.append("          <span class=\"fs-11 text-faint\">Read</span>\n");
    sb.append("        </div>\n")
      .append("        <div class=\"fs-13\" style=\"line-height:1.55\">").append(Fn.h(a.s("message"))).append("</div>\n")
      .append("        <div class=\"fs-11 text-faint mt-6\">").append(Fn.h(Fn.dateLabel(Fn.substr(created, 0, 10))))
      .append(" · ").append(Fn.h(Fn.substr(created, 11, 5))).append("</div>\n")
      .append("      </div>\n");
    if (!read) {
        sb.append("      <button class=\"btn btn-ghost btn-xs\" style=\"flex:none\" onclick=\"markRead(").append(a.i("id")).append(", this)\">Mark read</button>\n");
    }
    sb.append("    </div>\n");
    return sb.toString();
}
%><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

Fn.checkOverdueMaintenance();
Fn.checkReplacementReminders();
Fn.checkExpiredPendingPayments();

String filter = c.get("filter", "unread");
String where  = filter.equals("all") ? "" : "WHERE is_read=0";
List<Row> alerts = Db.all("SELECT * FROM alerts " + where + " ORDER BY created_at DESC");

int unreadCount = Db.scalarInt("SELECT COUNT(*) FROM alerts WHERE is_read=0");

// Group into the categories managers need to act on, so nothing gets missed.
// Each section: {label, icon}
LinkedHashMap<String, String[]> sectionInfo = new LinkedHashMap<String, String[]>();
sectionInfo.put("Replacement",               new String[]{"Replacement", "♻️"});
sectionInfo.put("Flagged Equipment",         new String[]{"Flagged equipment", "🏳️"});
sectionInfo.put("Overdue Maintenance",       new String[]{"Overdue maintenance", "🔧"});
sectionInfo.put("Damaged/Missing Equipment", new String[]{"Damaged or missing equipment", "⚠️"});
sectionInfo.put("Flagged Booking",           new String[]{"Flagged bookings", "🚩"});
LinkedHashMap<String, List<Row>> sectionItems = new LinkedHashMap<String, List<Row>>();
for (String k : sectionInfo.keySet()) sectionItems.put(k, new ArrayList<Row>());
List<Row> otherAlerts = new ArrayList<Row>();
for (Row a : alerts) {
    String kind = a.s("kind");
    if (kind != null && sectionItems.containsKey(kind)) sectionItems.get(kind).add(a);
    else otherAlerts.add(a);
}
sectionInfo.put("Other", new String[]{"Other", "📌"});
sectionItems.put("Other", otherAlerts);

String category = c.get("category");
if (!category.isEmpty() && !sectionInfo.containsKey(category)) category = "";
%><%= c.pageHead("Alerts") %>
<div class="portal-wrap">
<%= c.managerSidebar("alerts") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:800px">

  <% if (category.isEmpty()) { %>
  <!-- ── Category overview ── -->
  <div class="flex items-center gap-14 mb-18">
    <div style="flex:1">
      <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Alerts</h1>
      <p class="fs-14 text-muted">Pick a category to see its alerts.</p>
    </div>
    <% if (unreadCount > 0) { %>
    <button class="btn btn-ghost" onclick="markAllRead()">Mark all read</button>
    <% } %>
  </div>

  <div class="flex gap-8 mb-18">
    <a href="?filter=unread" class="btn <%= filter.equals("unread") ? "btn-brand" : "btn-ghost" %> btn-sm">
      Unread <% if (unreadCount > 0) { %><span style="background:rgba(255,255,255,.25);border-radius:20px;padding:1px 7px;margin-left:4px;font-size:11px"><%= unreadCount %></span><% } %>
    </a>
    <a href="?filter=all" class="btn <%= filter.equals("all") ? "btn-brand" : "btn-ghost" %> btn-sm">All alerts</a>
  </div>

  <div style="display:flex;flex-direction:column;gap:10px">
    <% for (Map.Entry<String, String[]> sec : sectionInfo.entrySet()) {
      List<Row> items = sectionItems.get(sec.getKey());
      int count = items.size();
      int unreadInSec = 0;
      for (Row a : items) if (!a.truthy("is_read")) unreadInSec++;
    %>
    <a href="?category=<%= Fn.urlencode(sec.getKey()) %>&filter=<%= Fn.h(filter) %>" class="card card-p bsy-tap bsy-row" style="display:flex;align-items:center;gap:14px;text-decoration:none;color:inherit">
      <span style="font-size:22px;flex:none"><%= sec.getValue()[1] %></span>
      <div style="flex:1">
        <div class="fw-800 fs-14"><%= Fn.h(sec.getValue()[0]) %></div>
        <div class="fs-12 text-muted"><%= count %> alert<%= count == 1 ? "" : "s" %><%= filter.equals("all") && unreadInSec > 0 ? " · " + unreadInSec + " unread" : "" %></div>
      </div>
      <% if (count > 0) { %>
      <span class="badge" style="background:var(--danger-bg);color:var(--danger);font-size:12px;font-weight:800"><%= count %></span>
      <% } else { %>
      <span class="fs-12 text-faint">All clear</span>
      <% } %>
      <span style="color:var(--faint);font-size:16px">›</span>
    </a>
    <% } %>
  </div>

  <% } else {
    String[] sec = sectionInfo.get(category);
    List<Row> items = sectionItems.get(category);
  %>
  <!-- ── Category detail ── -->
  <div class="flex items-center gap-14 mb-18">
    <div style="flex:1">
      <a href="?filter=<%= Fn.h(filter) %>" class="fs-13 fw-700" style="color:var(--muted);display:inline-block;margin-bottom:6px">‹ All categories</a>
      <h1 style="font-size:22px;font-weight:800;letter-spacing:-.5px"><%= sec[1] %> <%= Fn.h(sec[0]) %></h1>
    </div>
    <% if (unreadCount > 0) { %>
    <button class="btn btn-ghost" onclick="markAllRead()">Mark all read</button>
    <% } %>
  </div>

  <div class="flex gap-8 mb-18">
    <a href="?category=<%= Fn.urlencode(category) %>&filter=unread" class="btn <%= filter.equals("unread") ? "btn-brand" : "btn-ghost" %> btn-sm">Unread</a>
    <a href="?category=<%= Fn.urlencode(category) %>&filter=all" class="btn <%= filter.equals("all") ? "btn-brand" : "btn-ghost" %> btn-sm">All alerts</a>
  </div>

  <% if (items.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">✓</div>
    <div class="fw-800 fs-16 mb-6">All clear</div>
    <div class="fs-13 text-muted"><%= filter.equals("unread") ? "No unread alerts in this category." : "No alerts in this category." %></div>
  </div>
  <% } else { %>
  <div style="display:flex;flex-direction:column;gap:10px">
    <% for (Row a : items) { %><%= renderAlertCard(a) %><% } %>
  </div>
  <% } %>

  <% } %>
</div>
</main>
</div>

<script>
async function markRead(alertId, btn) {
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'mark_alert_read', alert_id: alertId });
  if (res.success) {
    const card = btn.closest('.card');
    card.style.opacity = '.65';
    btn.remove();
  } else showToast(res.message, 'danger');
}
async function markAllRead() {
  const res = await postJson(BASE_URL + 'api/manager-action', { action: 'mark_all_alerts_read' });
  if (res.success) { showToast('All alerts marked as read', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
