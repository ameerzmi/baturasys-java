<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;

Fn.checkExpiredPendingPayments();

// Group bookings by group_ref (or individual ref for old bookings without group_ref)
List<Row> pending = Fn.groupBookings(Db.all("SELECT * FROM bookings WHERE status = 'AWAITING_VERIFICATION' ORDER BY id"));
Fn.sortByCreated(pending, false);
%><%= c.pageHead("Verify Payments") %>
<div class="portal-wrap">
<%= c.staffSidebar("verify") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:900px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">Verify payments</h1>
  <p class="fs-14 text-muted mb-22">Review uploaded DuitNow receipts and approve or reject each payment.</p>

  <% if (pending.isEmpty()) { %>
  <div class="card card-p" style="text-align:center;padding:40px">
    <div style="font-size:40px;margin-bottom:12px">✓</div>
    <div class="fw-800 fs-16 mb-6">All caught up!</div>
    <div class="fs-13 text-muted">No receipts awaiting verification.</div>
  </div>
  <% } else { %>
  <div class="data-table">
    <div class="data-table-head" style="grid-template-columns:1.2fr 1fr 1.2fr 0.8fr 1fr">
      <span>Reference</span><span>Customer</span><span>Activities</span><span>Total</span><span style="text-align:right">Action</span>
    </div>
    <% for (Row row : pending) {
      List<String> actLabels = new ArrayList<String>();
      for (Map.Entry<String, Integer> e : Fn.countValues(row.s("activity_ids")).entrySet()) {
          Activity m = Fn.activityMeta(e.getKey());
          actLabels.add(Fn.h(m.name) + (e.getValue() > 1 ? " <span style=\"color:var(--brand);font-size:11px\">×" + e.getValue() + "</span>" : ""));
      }
      String actDisplay = String.join(", ", actLabels);
    %>
    <div class="data-table-row bsy-row" style="grid-template-columns:1.2fr 1fr 1.2fr 0.8fr 1fr">
      <div>
        <div class="fw-800 fs-13 mono"><%= Fn.h(row.s("gref")) %></div>
        <div class="fs-12 text-muted mt-4"><%= Fn.h(Fn.dateLabel(row.s("booking_date"))) %></div>
      </div>
      <div>
        <div class="fw-800 fs-13"><%= Fn.h(row.s("customer_name")) %></div>
        <div class="fs-12 text-muted"><%= Fn.h(row.s("customer_phone")) %></div>
      </div>
      <div>
        <div class="fs-13"><%= actDisplay %></div>
        <div class="fs-12 text-muted"><%= row.i("item_count") > 1 ? row.i("item_count") + " items" : Fn.h(row.s("slot")) %></div>
      </div>
      <div class="fw-800" style="color:var(--brand)"><%= Fn.h(Fn.fmt(row.d("total_amount"))) %></div>
      <div class="flex gap-10 justify-end">
        <button class="btn btn-ghost btn-xs" onclick="openReviewModal('<%= Fn.jsAttr(row.s("gref")) %>')">Review receipt</button>
      </div>
    </div>
    <% } %>
  </div>
  <% } %>
</div>
</main>
</div>

<!-- Review Modal -->
<div class="bsy-overlay" id="modal-review">
  <div class="bsy-modal" style="max-width:520px">
    <div class="fw-800" style="font-size:17px;margin-bottom:4px">Review receipt</div>
    <div class="fs-12 text-muted mb-18 mono" id="review-booking-id"></div>
    <div style="text-align:center;margin-bottom:18px">
      <img id="receipt-preview" src="" alt="Receipt" style="max-width:100%;max-height:300px;border-radius:10px;border:1px solid var(--border);object-fit:contain;background:var(--surface-2)">
      <div class="fs-12 text-muted mt-8">If no image loads, this booking used a demo receipt.</div>
    </div>
    <div class="flex gap-10">
      <button class="btn btn-ghost flex-1" onclick="closeModal('modal-review')">Close</button>
      <button class="btn flex-1" style="background:var(--danger-bg);color:var(--danger);border:none" id="reject-btn">Reject</button>
      <button class="btn btn-ok flex-1" id="approve-btn">Approve ✓</button>
    </div>
  </div>
</div>

<!-- Reject Modal -->
<div class="bsy-overlay" id="modal-reject">
  <div class="bsy-modal">
    <div class="fw-800" style="font-size:17px;margin-bottom:14px">Reject receipt</div>
    <form id="reject-form">
      <input type="hidden" name="group_ref" id="reject-group-input">
      <input type="hidden" name="action" value="reject">
      <div class="field sm">
        <label>Reason for rejection</label>
        <select name="preset" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;background:#fff;margin-bottom:10px">
          <option value="">Select a reason…</option>
          <option>Receipt image is unclear or unreadable</option>
          <option>Transfer amount does not match</option>
          <option>Receipt appears to be a duplicate</option>
          <option>Bank transfer details do not match</option>
        </select>
        <textarea name="reason" rows="2" placeholder="Or type a custom reason…" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px;resize:vertical"></textarea>
      </div>
      <div class="flex gap-10 mt-18">
        <button type="button" class="btn btn-ghost flex-1" onclick="closeModal('modal-reject')">Cancel</button>
        <button type="button" class="btn flex-1" style="background:var(--danger);color:#fff;border:none" onclick="submitModalForm('reject-form','reject','Receipt rejected — customer notified')">Reject</button>
      </div>
    </form>
  </div>
</div>

<%= c.logoutFab() %><%= c.pageFoot() %>
