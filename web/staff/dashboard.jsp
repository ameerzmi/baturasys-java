<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireStaff()) return;
Row staff = c.currentStaff();

int pending  = Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE status='AWAITING_VERIFICATION'");
int checkins = Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE status='CONFIRMED'");
int active   = Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE status='CHECKED_IN'");
int myTasks  = Db.scalarInt("SELECT COUNT(*) FROM maintenance_tasks WHERE assignee_id=? AND status IN ('SCHEDULED','IN_PROGRESS','OVERDUE')", staff.s("staff_id"));
%><%= c.pageHead("Staff Dashboard") %>
<div class="portal-wrap">
<%= c.staffSidebar("dashboard") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Overview</h1>
  <p class="fs-14 text-muted mb-22">Welcome, <%= Fn.h(staff.s("name")) %> — <%= Fn.todayLong() %></p>

  <div class="grid-4 mb-22">
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Awaiting verification</div>
      <div style="font-size:28px;font-weight:800;color:var(--warn)"><%= pending %></div>
    </div>
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Ready to check in</div>
      <div style="font-size:28px;font-weight:800;color:var(--brand)"><%= checkins %></div>
    </div>
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">Active rentals</div>
      <div style="font-size:28px;font-weight:800;color:var(--info)"><%= active %></div>
    </div>
    <div class="card card-p">
      <div class="fs-12 text-muted fw-800 mb-8">My tasks</div>
      <div style="font-size:28px;font-weight:800"><%= myTasks %></div>
    </div>
  </div>

  <!-- Quick links -->
  <div class="grid-3">
    <a href="<%= c.BASE %>staff/verify.jsp" class="card card-p bsy-tap" style="text-decoration:none;color:var(--ink)">
      <div style="font-size:24px;margin-bottom:10px">🧾</div>
      <div class="fw-800 fs-14 mb-4">Verify payments</div>
      <div class="fs-13 text-muted"><%= pending %> receipt<%= pending == 1 ? "" : "s" %> awaiting</div>
    </a>
    <a href="<%= c.BASE %>staff/checkin.jsp" class="card card-p bsy-tap" style="text-decoration:none;color:var(--ink)">
      <div style="font-size:24px;margin-bottom:10px">✓</div>
      <div class="fw-800 fs-14 mb-4">Check-in</div>
      <div class="fs-13 text-muted"><%= checkins %> booking<%= checkins == 1 ? "" : "s" %> confirmed</div>
    </a>
    <a href="<%= c.BASE %>staff/returns.jsp" class="card card-p bsy-tap" style="text-decoration:none;color:var(--ink)">
      <div style="font-size:24px;margin-bottom:10px">↩</div>
      <div class="fw-800 fs-14 mb-4">Process returns</div>
      <div class="fs-13 text-muted"><%= active %> active rental<%= active == 1 ? "" : "s" %></div>
    </a>
  </div>
</div>
</main>
</div>
<%= c.logoutFab() %><%= c.pageFoot() %>
