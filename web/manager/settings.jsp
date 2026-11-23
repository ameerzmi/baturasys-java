<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

Map<String, String> s = Fn.getAllSettings();
%><%= c.pageHead("System Settings") %>
<div class="portal-wrap">
<%= c.managerSidebar("settings") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:720px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">System settings</h1>
  <p class="fs-14 text-muted mb-22">Configure operating hours, booking policies, and rental rates.</p>

  <!-- Operating hours -->
  <div class="card card-p mb-18">
    <div class="fw-800 fs-15 mb-4">Operating hours</div>
    <p class="fs-13 text-muted mb-16">Set the daily opening and closing time displayed on the homepage.</p>
    <form id="hours-form">
      <input type="hidden" name="action" value="save_settings">
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="field sm">
          <label>Open time</label>
          <input type="time" name="open_time" value="<%= Fn.h(Fn.opt(s, "open_time", "09:00")) %>" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
        </div>
        <div class="field sm">
          <label>Close time</label>
          <input type="time" name="close_time" value="<%= Fn.h(Fn.opt(s, "close_time", "17:00")) %>" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
        </div>
      </div>
      <div class="field sm">
        <label>Operating days</label>
        <input type="text" name="operating_days" value="<%= Fn.h(Fn.opt(s, "operating_days", "Tuesday – Sunday")) %>" placeholder="e.g. Tuesday – Sunday" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <button type="button" class="btn btn-brand mt-14" onclick="submitManagerForm('hours-form','save_settings','Operating hours saved')">Save hours</button>
    </form>
  </div>

  <!-- Booking policy -->
  <div class="card card-p mb-18">
    <div class="fw-800 fs-15 mb-4">Booking policy</div>
    <p class="fs-13 text-muted mb-16">Configure hold duration and cancellation window.</p>
    <form id="policy-form">
      <input type="hidden" name="action" value="save_settings">
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="field sm">
          <label>Payment hold (hours)</label>
          <input type="number" name="hold_hours" value="<%= Fn.h(Fn.opt(s, "hold_hours", Fn.opt(s, "holding_hours", "24"))) %>" min="1" max="72" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
          <div class="fs-12 text-faint mt-4">Auto-cancel if no receipt</div>
        </div>
        <div class="field sm">
          <label>Cancellation window (hours)</label>
          <input type="number" name="cancel_hours" value="<%= Fn.h(Fn.opt(s, "cancel_hours", "24")) %>" min="0" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
          <div class="fs-12 text-faint mt-4">Before slot start time</div>
        </div>
      </div>
      <button type="button" class="btn btn-brand mt-14" onclick="submitManagerForm('policy-form','save_settings','Policy saved')">Save policy</button>
    </form>
  </div>

  <!-- Rental rates -->
  <div class="card card-p">
    <div class="fw-800 fs-15 mb-4">Activity rates</div>
    <p class="fs-13 text-muted mb-16">Edit the display name, unit, and rate charged for each activity. Changes apply immediately to new bookings.</p>
    <div class="data-table-head" style="display:grid;grid-template-columns:32px 1.3fr 1fr 1fr 70px;gap:10px;padding:0 2px 8px">
      <span></span><span>Activity</span><span>Unit</span><span>Rate (RM)</span><span></span>
    </div>
    <% for (String aid : Fn.ACTIVITY_IDS) {
      Activity m = Fn.activityMeta(aid);
    %>
    <form id="act-form-<%= aid %>" style="display:grid;grid-template-columns:32px 1.3fr 1fr 1fr 70px;gap:10px;align-items:center;padding:8px 2px;border-bottom:1px solid var(--border-2)">
      <input type="hidden" name="action" value="save_activity">
      <input type="hidden" name="activity_id" value="<%= Fn.h(aid) %>">
      <span style="font-size:18px"><%= m.emoji %></span>
      <input type="text" name="name" value="<%= Fn.h(m.name) %>" style="width:100%;padding:9px 10px;border:1px solid var(--border);border-radius:8px;font-size:13px" required>
      <input type="text" name="unit" value="<%= Fn.h(m.unit) %>" style="width:100%;padding:9px 10px;border:1px solid var(--border);border-radius:8px;font-size:13px" required>
      <input type="number" name="rate" value="<%= Fn.h(Fn.phpFloatStr(m.rate)) %>" step="0.01" min="0.01" style="width:100%;padding:9px 10px;border:1px solid var(--border);border-radius:8px;font-size:13px" required>
      <button type="button" class="btn btn-brand btn-xs" onclick="submitManagerForm('act-form-<%= aid %>','save_activity','<%= Fn.jsAttr(m.name) %> updated')">Save</button>
    </form>
    <% } %>
  </div>
</div>
</main>
</div>

<%= c.logoutFab() %><%= c.pageFoot() %>
