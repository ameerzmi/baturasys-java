<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

int id = Fn.toInt(c.has("id") ? c.get("id") : (c.sess("current_booking_id") != null ? c.sess("current_booking_id").toString() : "0"));
if (id == 0) { c.redirect(c.BASE + "lookup.jsp"); return; }

Row first = Db.one("SELECT * FROM bookings WHERE id=?", id);
if (first == null) { c.redirect(c.BASE + "lookup.jsp"); return; }

// Only the owner, staff/manager, or someone who made / looked up this booking may see it
if (!c.canViewBooking(first)) {
    c.setFlash("Enter your booking reference to view that booking.", "info");
    c.redirect(c.BASE + "lookup.jsp");
    return;
}

// Load all bookings in the same group
String gref = first.s("group_ref");
List<Row> groupBookings;
if (!Fn.empty(gref)) {
    groupBookings = Db.all("SELECT * FROM bookings WHERE group_ref=? ORDER BY id", gref);
} else {
    groupBookings = new ArrayList<>();
    groupBookings.add(first);
    gref = first.s("ref");
}
if (groupBookings.isEmpty()) { c.redirect(c.BASE + "lookup.jsp"); return; }

String displayRef  = gref;
Row mainBooking    = groupBookings.get(0);
String status      = mainBooking.s("status");
double totalAmount = 0;
for (Row b : groupBookings) totalAmount += b.d("amount");
Activity firstMeta = Fn.activityMeta(mainBooking.s("activity_id"));
Row customer       = c.currentCustomer();

// For re-upload: restore session so step4 knows which bookings to update
if ("PENDING_PAYMENT".equals(status) || "REJECTED".equals(status)) {
    List<Integer> ids = new ArrayList<>();
    for (Row b : groupBookings) ids.add(b.i("id"));
    c.sessSet("current_booking_ids", ids);
    c.sessSet("current_booking_id", mainBooking.i("id"));
}

String[] st = Fn.statusBadge(status);
String stLabel = st[0], stBg = st[1], stFg = st[2];

String[] tlSteps = {"Pending", "Verifying", "Confirmed", "Completed"};
Map<String, Integer> stOrder = new HashMap<>();
stOrder.put("PENDING_PAYMENT", 0);
stOrder.put("AWAITING_VERIFICATION", 1);
stOrder.put("CONFIRMED", 2);
stOrder.put("CHECKED_IN", 2);
stOrder.put("COMPLETED", 3);
boolean cancelled = "CANCELLED".equals(status) || "REJECTED".equals(status);
int curIdx = cancelled ? -1 : stOrder.getOrDefault(status, 0);
boolean showRefPop = c.has("new");
int n = groupBookings.size();
%><%= c.pageHead("Booking " + displayRef) %><%= c.customerNav() %>

<div class="bsy-screen" style="max-width:600px;margin:0 auto;padding:34px 24px 80px">

  <!-- Header card -->
  <div class="card" style="overflow:hidden;margin-bottom:16px">
    <div style="height:100px;background:<%= Fn.h(firstMeta.swatch) %>;display:flex;align-items:center;justify-content:center;font-size:42px">
      <%= firstMeta.emoji %>
    </div>
    <div class="card-p">
      <div class="flex items-center justify-between mb-14">
        <div>
          <div style="font-size:18px;font-weight:800;margin-bottom:3px">
            <% if (n > 1) { %>
              <%= n %> activities booked
            <% } else { %>
              <%= Fn.h(firstMeta.name) %>
            <% } %>
          </div>
          <div class="flex items-center gap-8 mt-3">
            <span class="fs-13 text-muted mono"><%= Fn.h(displayRef) %></span>
            <button onclick="copyRef('<%= Fn.jsAttr(displayRef) %>')" title="Copy reference" style="background:none;border:none;cursor:pointer;padding:3px 6px;border-radius:6px;color:var(--muted);font-size:12px;line-height:1;transition:background .15s" onmouseover="this.style.background='var(--surface-2)'" onmouseout="this.style.background='none'">⎘ Copy</button>
          </div>
        </div>
        <span class="badge" style="background:<%= stBg %>;color:<%= stFg %>"><%= Fn.h(stLabel) %></span>
      </div>

      <!-- Timeline -->
      <% if (!cancelled) { %>
      <div class="timeline mb-18">
        <% for (int i = 0; i < tlSteps.length; i++) { %>
        <div class="tl-step">
          <div class="tl-bar" style="background:<%= i <= curIdx ? "var(--brand)" : "#e2e9ea" %>"></div>
          <div class="tl-label" style="color:<%= i <= curIdx ? "var(--brand-dark)" : "var(--faint)" %>"><%= Fn.h(tlSteps[i]) %></div>
        </div>
        <% } %>
      </div>
      <% } %>

      <!-- Date and customer info -->
      <div class="grid-2 fs-13 mb-18">
        <div><span class="text-muted">Date</span><br><b><%= Fn.h(Fn.dateLabel(mainBooking.s("booking_date"))) %></b></div>
        <div><span class="text-muted">Customer</span><br><b><%= Fn.h(mainBooking.s("customer_name")) %></b></div>
        <div><span class="text-muted">Phone</span><br><b><%= Fn.h(mainBooking.s("customer_phone")) %></b></div>
        <div><span class="text-muted">Total amount</span><br><b style="color:var(--brand)"><%= Fn.h(Fn.fmt(totalAmount)) %></b></div>
      </div>

      <!-- Items in this booking -->
      <div style="border-top:1px solid var(--border-2);padding-top:14px;margin-bottom:14px">
        <div class="fw-800 fs-13 mb-10">Booking items</div>
        <% for (Row b : groupBookings) {
          Activity bMeta = Fn.activityMeta(b.s("activity_id"));
          String[] bSt = Fn.statusBadge(b.s("status"));
        %>
        <div style="display:flex;align-items:flex-start;gap:10px;margin-bottom:10px;padding-bottom:10px;border-bottom:1px solid var(--border-2)">
          <span style="font-size:18px;flex:none;margin-top:1px"><%= bMeta.emoji %></span>
          <div style="flex:1;min-width:0">
            <div class="fw-800 fs-13"><%= Fn.h(bMeta.name) %></div>
            <div class="fs-12 text-muted"><%= Fn.h(Fn.bookingSlotLabel(b.s("slot"), b.i("hours"), b.s("rental_type"))) %></div>
            <% if (b.truthy("watercraft_id")) { %>
              <div class="fs-12 text-muted">Watercraft: <span class="mono fw-700"><%= Fn.h(b.s("watercraft_id")) %></span></div>
            <% } else { %>
              <div class="fs-12 text-muted" style="font-style:italic">Watercraft assigned at check-in</div>
            <% } %>
            <% if ("CHECKED_IN".equals(b.s("status")) && b.truthy("equipment_assigned")) { %>
              <div class="fs-12 text-muted">Equipment: <%= Fn.h(b.s("equipment_assigned")) %></div>
            <% } %>
          </div>
          <div style="text-align:right;flex:none">
            <div class="fw-800 fs-12" style="color:var(--brand)"><%= Fn.h(Fn.fmt(b.d("amount"))) %></div>
            <% if (n > 1) { %>
              <span class="badge mt-4" style="background:<%= bSt[1] %>;color:<%= bSt[2] %>;font-size:10px"><%= Fn.h(bSt[0]) %></span>
            <% } %>
          </div>
        </div>
        <% } %>
      </div>

      <% if ("REJECTED".equals(status) && mainBooking.truthy("rejection_reason")) { %>
      <div style="background:var(--danger-bg);border-radius:10px;padding:12px 14px;font-size:13px;color:var(--danger);margin-bottom:14px">
        <b>Rejection reason:</b> <%= Fn.h(mainBooking.s("rejection_reason")) %>
      </div>
      <% } %>

      <!-- Action buttons -->
      <div class="flex gap-10 flex-wrap">
        <% if ("PENDING_PAYMENT".equals(status)) { %>
          <a href="<%= c.BASE %>booking/step4.jsp" class="btn btn-brand">Upload receipt</a>
        <% } %>

        <% if ("REJECTED".equals(status)) { %>
          <a href="<%= c.BASE %>booking/step4.jsp" class="btn btn-brand">Re-upload receipt</a>
        <% } %>

        <% if ("PENDING_PAYMENT".equals(status) || "AWAITING_VERIFICATION".equals(status)) { %>
          <button class="btn btn-ghost" onclick="openCancelConfirm()">Cancel booking</button>
        <% } %>

        <% if (mainBooking.truthy("receipt_path")) { %>
          <button type="button" class="btn btn-ghost" onclick="openModal('modal-receipt')">View receipt</button>
        <% } %>

        <% if (customer == null && ("AWAITING_VERIFICATION".equals(status) || "CONFIRMED".equals(status))) { %>
          <a href="<%= c.BASE %>register.jsp?name=<%= Fn.urlencode(mainBooking.s("customer_name")) %>&phone=<%= Fn.urlencode(mainBooking.s("customer_phone")) %>" class="btn" style="background:var(--surface-2);border:1px solid var(--border);color:var(--ink);font-size:14px">Create account</a>
        <% } %>

        <a href="<%= customer != null ? c.BASE + "customer/dashboard.jsp" : c.BASE + "index.jsp" %>" class="btn btn-ghost">
          <%= customer != null ? "My bookings" : "Back to home" %>
        </a>
      </div>
    </div>
  </div>
</div>

<!-- Save reference popup (shown once after receipt upload) -->
<% if (showRefPop) { %>
<div class="bsy-overlay open" id="modal-save-ref">
  <div class="bsy-modal" style="max-width:360px;text-align:center;padding:32px 28px">
    <div style="font-size:40px;margin-bottom:14px">🔖</div>
    <div style="font-size:18px;font-weight:800;letter-spacing:-.3px;margin-bottom:8px">Save your reference number</div>
    <div class="fs-13 text-muted mb-18" style="line-height:1.55">Screenshot or note this down — you'll need it to check your booking status or contact us.</div>
    <div style="background:var(--surface-2);border:1px solid var(--border);border-radius:10px;padding:12px 16px;margin-bottom:20px;display:flex;align-items:center;justify-content:center;gap:10px">
      <span class="fw-800 mono" style="font-size:15px;letter-spacing:.5px;color:var(--brand-dark)"><%= Fn.h(displayRef) %></span>
      <button onclick="copyRef('<%= Fn.jsAttr(displayRef) %>')" style="background:var(--brand);color:#fff;border:none;border-radius:7px;padding:5px 10px;font-size:12px;font-weight:700;cursor:pointer">Copy</button>
    </div>
    <button class="btn btn-brand w-full" onclick="closeModal('modal-save-ref')" style="font-size:15px;padding:13px">Got it!</button>
  </div>
</div>
<% } %>

<!-- Cancel confirm modal -->
<div class="bsy-overlay" id="modal-cancel">
  <div class="bsy-modal" style="max-width:400px">
    <div class="fw-800" style="font-size:17px;margin-bottom:6px">Cancel this booking?</div>
    <div class="fs-13 text-muted mb-18">This will cancel all <%= n %> item<%= n > 1 ? "s" : "" %> in this booking. This action cannot be undone.</div>
    <div class="flex gap-10">
      <button class="btn btn-ghost flex-1" onclick="closeModal('modal-cancel')">Keep booking</button>
      <button class="btn flex-1" style="background:var(--danger);color:#fff;border:none" onclick="confirmCancelGroup('<%= Fn.jsAttr(gref) %>')">Yes, cancel</button>
    </div>
  </div>
</div>

<% if (mainBooking.truthy("receipt_path")) { %>
<!-- Receipt preview modal -->
<div class="bsy-overlay" id="modal-receipt">
  <div class="bsy-modal" style="max-width:420px;text-align:center">
    <div class="fw-800" style="font-size:17px;margin-bottom:14px">Your uploaded receipt</div>
    <img src="<%= c.UPLOAD_URL + Fn.h(mainBooking.s("receipt_path")) %>" alt="Uploaded receipt" style="max-width:100%;max-height:60vh;border-radius:10px;border:1px solid var(--border);object-fit:contain">
    <button class="btn btn-brand w-full mt-18" onclick="closeModal('modal-receipt')">Close</button>
  </div>
</div>
<% } %>

<%= c.pageFoot() %>
