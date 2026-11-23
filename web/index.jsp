<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

Map<String, String> settings = Fn.getAllSettings();
String openTime  = Fn.opt(settings, "open_time", "09:00");
String closeTime = Fn.opt(settings, "close_time", "18:00");
String hoursLabel = Fn.fmtHour(openTime) + "–" + Fn.fmtHour(closeTime);

// Activity types to show on home
List<String> activityIds = Arrays.asList("kayak", "canoe", "paddle", "cruise");
Map<String, Integer> availCounts = new LinkedHashMap<>();
for (String type : Fn.ACTIVITY_IDS) {
    availCounts.put(type, Db.scalarInt("SELECT COUNT(*) FROM watercraft WHERE activity_id=? AND status='AVAILABLE'", type));
}

// Paid & approved bookings for today already claim a unit even though it
// isn't assigned/checked in yet — don't count those units as available.
Map<String, Integer> confirmedToday = new HashMap<>();
for (Row row : Db.all("SELECT activity_id, COUNT(*) AS cnt FROM bookings WHERE status='CONFIRMED' AND booking_date=CURRENT_DATE GROUP BY activity_id")) {
    confirmedToday.put(row.s("activity_id"), row.i("cnt"));
}
for (Map.Entry<String, Integer> e : availCounts.entrySet()) {
    e.setValue(Math.max(0, e.getValue() - confirmedToday.getOrDefault(e.getKey(), 0)));
}

// Kayaking (Double) isn't shown as its own home card, so fold it into
// the Kayaking count — the split is chosen on the next step.
availCounts.put("kayak", availCounts.get("kayak") + availCounts.get("kayak2"));

int totalAvail = 0;
for (String id : activityIds) totalAvail += availCounts.get(id);
%><%= c.pageHead("Home") %><%= c.customerNav("home") %>

<!-- HERO -->
<section class="hero bsy-screen">
  <div class="hero-inner">
    <span class="hero-decor" aria-hidden="true">🛶</span>
    <div style="max-width:620px">
      <div class="hero-badge">Taman Tasik Shah Alam · Open daily <%= Fn.h(hoursLabel) %></div>
      <h1>Get on the water in minutes.</h1>
      <p>Reserve a kayak, canoe, paddle boat or cruise ride online. Pick a slot, pay by DuitNow QR, and skip the queue.</p>
      <div class="flex gap-10 flex-wrap">
        <a href="<%= c.BASE %>booking/step1.jsp" class="btn bsy-tap" style="background:#fff;color:var(--brand-dark);border:none;font-size:15px">Book an activity</a>
        <a href="<%= c.BASE %>lookup.jsp" class="btn bsy-tap" style="background:rgba(255,255,255,.14);color:#fff;border:1px solid rgba(255,255,255,.35);font-size:15px">Check my booking</a>
      </div>
    </div>
  </div>
</section>

<!-- ACTIVITIES -->
<section style="max-width:1120px;margin:0 auto;padding:36px 24px 56px" class="bsy-screen">
  <div class="flex items-center justify-between mb-20">
    <h2 style="font-size:22px;font-weight:800;letter-spacing:-.4px">Choose your activity</h2>
    <span class="fs-13 text-muted">Live availability · <%= totalAvail %> watercraft ready now</span>
  </div>

  <div class="activity-grid">
    <% for (String id : activityIds) {
      Activity m = Fn.activityMeta(id);
      int avail = availCounts.getOrDefault(id, 0);
    %>
    <a href="<%= c.BASE %>booking/step1.jsp?activity=<%= id %>" class="activity-card bsy-tap" style="text-decoration:none">
      <div class="activity-thumb" style="background:<%= Fn.h(m.swatch) %>">
        <span style="font-size:30px"><%= m.emoji %></span>
        <span style="background:rgba(255,255,255,.9);border-radius:999px;padding:4px 10px;font-size:12px;font-weight:800;color:var(--ink)"><%= Fn.h(Fn.fmt(m.rate) + m.unit) %></span>
      </div>
      <div class="activity-body">
        <div style="font-size:16px;font-weight:800;margin-bottom:4px"><%= Fn.h(m.name) %></div>
        <div class="fs-13 text-muted" style="line-height:1.45;margin-bottom:12px"><%= Fn.h(m.blurb) %></div>
        <div class="flex items-center gap-10 fs-12 text-ok fw-800">
          <span style="width:7px;height:7px;border-radius:50%;background:var(--ok);display:inline-block"></span>
          <%= avail %> available now
        </div>
      </div>
    </a>
    <% } %>
  </div>

  <!-- Feature cards -->
  <div class="grid-3 mt-20" style="margin-top:36px">
    <div class="card card-p">
      <div style="font-size:22px;margin-bottom:10px">🕑</div>
      <div class="fw-800" style="font-size:15px;margin-bottom:5px">Real-time slots</div>
      <div class="fs-13 text-muted" style="line-height:1.5">No double bookings. Availability updates the moment someone reserves.</div>
    </div>
    <div class="card card-p">
      <div style="font-size:22px;margin-bottom:10px">📱</div>
      <div class="fw-800" style="font-size:15px;margin-bottom:5px">Pay by DuitNow QR</div>
      <div class="fs-13 text-muted" style="line-height:1.5">Scan, pay, upload your receipt. Staff verify within 30 minutes during operating hours.</div>
    </div>
    <div class="card card-p">
      <div style="font-size:22px;margin-bottom:10px">🦺</div>
      <div class="fw-800" style="font-size:15px;margin-bottom:5px">Safety first</div>
      <div class="fs-13 text-muted" style="line-height:1.5">Every rental includes an inspected life jacket. Gear is tracked and replaced on schedule.</div>
    </div>
  </div>
</section>

<%= c.customerFooter() %><%= c.pageFoot() %>
