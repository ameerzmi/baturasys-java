<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;

List<Row> active = Db.all("SELECT b.*, w.name as wc_name FROM bookings b LEFT JOIN watercraft w ON b.watercraft_id=w.identifier WHERE b.status='CHECKED_IN' ORDER BY b.checkin_at");
%><%= c.pageHead("Rental Returns") %>
<div class="portal-wrap">
<%= c.staffSidebar("returns") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:900px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">Rental returns</h1>
  <p class="fs-14 text-muted mb-22">Process returns for active rentals. Log condition and record any damage or loss.</p>

  <% if (active.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">✓</div>
    <div class="fw-800 fs-16 mb-6">No active rentals</div>
    <div class="fs-13 text-muted">All watercraft are available or under maintenance.</div>
  </div>
  <% } else { %>
  <div style="display:flex;flex-direction:column;gap:13px">
    <% for (Row b : active) {
      Activity meta = Fn.activityMeta(b.s("activity_id"));
      String wcName = Fn.coalesce(b.s("wc_name"), b.s("watercraft_id"));
    %>
    <div class="card card-p flex items-center gap-14">
      <div style="width:44px;height:44px;border-radius:10px;background:<%= Fn.h(meta.swatch) %>;display:flex;align-items:center;justify-content:center;font-size:20px;flex:none"><%= meta.emoji %></div>
      <div style="flex:1">
        <div class="fw-800 fs-14"><%= Fn.h(b.s("customer_name")) %></div>
        <div class="fs-12 text-muted mono mt-4"><%= Fn.h(b.s("ref")) %></div>
        <div class="fs-12 text-muted mt-4">
          <%= Fn.h(wcName) %> · <%= Fn.h(b.s("slot")) %>
          <% if (b.truthy("checkin_at")) { %>
          · Checked in <%= Fn.h(Fn.timeHM(b.ts("checkin_at"))) %>
          <% } %>
        </div>
        <% if (b.truthy("equipment_assigned")) { %>
        <div class="fs-12 mt-4" style="color:var(--info)">Equipment: <%= Fn.h(b.s("equipment_assigned")) %></div>
        <% } %>
      </div>
      <div style="text-align:right">
        <div class="fw-800 mb-8" style="color:var(--brand)"><%= Fn.h(Fn.fmt(b.d("amount"))) %></div>
        <button class="btn btn-brand btn-sm" onclick="openReturnModal(<%= b.i("id") %>, '<%= Fn.jsAttr(b.s("customer_name")) %>', '<%= Fn.jsAttr(wcName) %>')">Process return</button>
      </div>
    </div>
    <% } %>
  </div>
  <% } %>
</div>
</main>
</div>

<!-- Return Modal -->
<div class="bsy-overlay" id="modal-return">
  <div class="bsy-modal" style="text-align:left">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Process return</div>
    <div class="fs-13 text-muted mb-18" id="return-info"></div>
    <form id="return-form">
      <input type="hidden" name="booking_id" id="return-booking-id">
      <input type="hidden" name="action" value="return">
      <div class="field sm">
        <label>Condition on return</label>
        <div style="display:flex;flex-direction:column;gap:9px;margin-bottom:16px">
          <label style="display:flex;align-items:flex-start;gap:10px;border:1px solid var(--border);border-radius:10px;padding:12px;cursor:pointer;font-size:13.5px;font-weight:600">
            <input type="radio" name="damage" value="no" checked style="width:auto;padding:0;border:none;background:none;margin-top:2px;flex:none">
            <span style="flex:1">All gear returned in good condition</span>
          </label>
          <label style="display:flex;align-items:flex-start;gap:10px;border:1px solid var(--border);border-radius:10px;padding:12px;cursor:pointer;font-size:13.5px;font-weight:600">
            <input type="radio" name="damage" value="yes" style="width:auto;padding:0;border:none;background:none;margin-top:2px;flex:none">
            <span style="flex:1">Damage or loss to report</span>
          </label>
        </div>
      </div>
      <div class="field sm">
        <label>Notes <span class="text-faint" style="font-weight:500">(required if reporting an incident)</span></label>
        <textarea name="issue" rows="2" placeholder="Describe any damaged or missing items" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;resize:vertical"></textarea>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-return')">Cancel</button>
        <button type="button" class="btn btn-brand flex-1" onclick="submitModalForm('return-form','return','Return complete — transaction recorded')">Complete return</button>
      </div>
    </form>
  </div>
</div>

<%= c.logoutFab() %><%= c.pageFoot() %>
