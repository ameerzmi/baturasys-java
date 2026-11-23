<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;

List<Row> confirmed = Db.all("SELECT b.*, w.name as wc_name FROM bookings b "
    + "LEFT JOIN watercraft w ON b.watercraft_id = w.identifier "
    + "WHERE b.status = 'CONFIRMED' ORDER BY b.booking_date, b.slot");

List<Row> equipment = Db.all("SELECT * FROM equipment WHERE status='Active' ORDER BY type, size, equipment_id");

// Equipment IDs currently checked out in active bookings
Set<String> takenIds = Fn.takenEquipmentIds();

// Watercraft options are fetched per-booking via AJAX when the modal opens.
%><%= c.pageHead("Check-in") %>
<div class="portal-wrap">
<%= c.staffSidebar("checkin") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:900px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">Check-in</h1>
  <p class="fs-14 text-muted mb-22">Search by booking reference or customer name to find a confirmed booking.</p>

  <!-- Search -->
  <div class="card card-p mb-18">
    <form onsubmit="doCheckinSearch(event)" class="flex gap-10 items-center">
      <input type="text" id="checkin-search" placeholder="BSY-20260618-0007 or customer name" style="flex:1;padding:12px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px" autocomplete="off">
      <button type="submit" class="btn btn-brand" style="padding:12px 20px">Search</button>
    </form>
    <div id="checkin-result"></div>
  </div>

  <!-- Today's confirmed bookings -->
  <div class="fw-800 fs-14 mb-14">Today's confirmed bookings (<%= confirmed.size() %>)</div>
  <% if (confirmed.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:30px;color:var(--muted)">No confirmed bookings at the moment.</div>
  <% } else { %>
  <div class="data-table">
    <div class="data-table-head" style="grid-template-columns:1.2fr 1fr 1fr 1fr 0.8fr">
      <span>Reference</span><span>Customer</span><span>Activity</span><span>Slot</span><span style="text-align:right">Action</span>
    </div>
    <% for (Row b : confirmed) {
      Activity meta = Fn.activityMeta(b.s("activity_id"));
      int hrs = b.i("hours");
    %>
    <div class="data-table-row bsy-row" style="grid-template-columns:1.2fr 1fr 1fr 1fr 0.8fr">
      <div class="fw-800 fs-13 mono"><%= Fn.h(b.s("ref")) %></div>
      <div>
        <div class="fw-800 fs-13"><%= Fn.h(b.s("customer_name")) %></div>
        <div class="fs-12 text-muted"><%= Fn.h(b.s("customer_phone")) %></div>
      </div>
      <div class="fs-13"><%= Fn.h(meta.name) %></div>
      <div class="fs-13">
        <% if ("Off-site".equals(b.s("rental_type"))) { %>
          <span class="badge" style="background:var(--info-bg);color:var(--info);font-size:10px;margin-bottom:2px">Off-site</span><br>
          Pickup <%= Fn.h(b.s("slot")) %> · <%= hrs %> day<%= hrs > 1 ? "s" : "" %>
        <% } else { %>
          <%= Fn.h(b.s("slot")) %><%= hrs > 1 ? " <span class=\"fs-12 text-muted\">·" + hrs + "h</span>" : "" %>
        <% } %>
        <br><span class="fs-12 text-muted"><%= Fn.h(Fn.dateLabel(b.s("booking_date"))) %></span>
      </div>
      <div class="justify-end flex">
        <button class="btn btn-brand btn-xs" onclick="openCheckinModal(<%= b.i("id") %>, '<%= Fn.jsAttr(b.s("ref")) %>', '<%= Fn.jsAttr(b.s("customer_name")) %>')">Check in</button>
      </div>
    </div>
    <% } %>
  </div>
  <% } %>
</div>
</main>
</div>

<!-- Check-in Modal -->
<div class="bsy-overlay" id="modal-checkin">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Customer check-in</div>
    <div class="fs-12 mono text-muted mb-4" id="checkin-ref"></div>
    <div class="fs-13 text-muted mb-18" id="checkin-info"></div>
    <form id="checkin-form">
      <input type="hidden" name="booking_id" id="checkin-booking-id">
      <input type="hidden" name="action" value="checkin">

      <div class="field sm">
        <label>Assign watercraft <span style="color:var(--danger)">*</span></label>
        <select name="watercraft_id" id="checkin-watercraft" required style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff">
          <option value="">— Select watercraft —</option>
        </select>
        <div id="checkin-wc-warn" class="fs-12" style="color:var(--warn);margin-top:5px;display:none">No available watercraft for this slot.</div>
      </div>

      <div class="field sm" style="margin-top:14px">
        <label>Assign equipment <span class="fw-400 text-muted">(select all that apply)</span></label>
        <div style="max-height:200px;overflow-y:auto;border:1px solid var(--border);border-radius:10px;padding:4px 2px">
          <% for (Row eq : equipment) {
            boolean taken = takenIds.contains(eq.s("equipment_id"));
            String size = eq.s("size");
          %>
          <label style="display:block;padding:7px 12px;border-radius:8px;cursor:<%= taken ? "not-allowed" : "pointer" %>;opacity:<%= taken ? "0.4" : "1" %>;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
            <input type="checkbox" name="equip[]" value="<%= Fn.h(eq.s("equipment_id")) %>" <%= taken ? "disabled" : "" %> style="width:13px;height:13px;vertical-align:middle;accent-color:var(--brand);margin-right:7px;flex:none">
            <span class="fs-13 fw-700 mono"><%= Fn.h(eq.s("equipment_id")) %></span>
            <span class="fs-13"> · <%= Fn.h(eq.s("type")) %><%= !Fn.empty(size) && !size.equals("-") ? " <span class=\"text-muted\">" + Fn.h(size) + "</span>" : "" %><%= taken ? " <span class=\"fs-12 text-muted\"> — in use</span>" : "" %></span>
          </label>
          <% } %>
          <% if (equipment.isEmpty()) { %>
          <div class="fs-13 text-muted" style="padding:10px">No active equipment.</div>
          <% } %>
        </div>
      </div>

      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-checkin')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitModalForm('checkin-form','checkin','Customer checked in')">Confirm check-in</button>
      </div>
    </form>
  </div>
</div>

<%= c.logoutFab() %><%= c.pageFoot() %>
