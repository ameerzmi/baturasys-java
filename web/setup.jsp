<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.time.LocalDate, com.baturasys.*" %><%
/*
 * BaturaSys Setup Script
 * Run once at http://localhost:8080/BaturaSysJava/setup.jsp after importing the SQL schema.
 * This seeds all demo data with properly hashed passwords.
 */
Ctx c = new Ctx(request, response);
List<String> errors = new ArrayList<String>();
List<String> messages = new ArrayList<String>();

// Check tables exist (CAST: system columns use a different collation than this database)
boolean noTables = Db.scalarInt("SELECT COUNT(*) FROM SYS.SYSTABLES WHERE CAST(TABLETYPE AS VARCHAR(1))='T'") == 0;

// This page DELETES ALL DATA: manager login required, and it only runs from the
// confirmation form (POST with confirm=RESET) - never from simply opening the page.
boolean confirmed = false;
if (!noTables) {
    // Fresh install (no manager accounts yet) can't log in, so it may seed without one.
    boolean freshInstall = Db.scalarInt("SELECT COUNT(*) FROM managers") == 0;
    if (!freshInstall && !c.requireManager()) return;
    confirmed = c.isPost() && "RESET".equals(c.post("confirm"));
}

try {
    if (noTables || !confirmed) {
        // nothing to do yet
    } else {
        DemoSeed.run(messages);
    }
} catch (Db.DbException e) {
    errors.add("Database error: " + e.getMessage());
}

if (noTables) {
%><div style="font-family:sans-serif;padding:40px;color:#bf3b2b"><h2>No tables found</h2><p>Please run <code>database/baturasys_derby.sql</code> on the Java DB connection in NetBeans first, then reload this page.</p></div><%
    return;
}
%><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BaturaSys Setup</title>
<style>
body{font-family:'Segoe UI',sans-serif;background:#eef2f3;margin:0;padding:40px 24px;color:#0f262c}
.box{max-width:600px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 8px 24px rgba(15,38,44,.1)}
h1{font-size:24px;margin:0 0 6px;color:#0d7f8e}
.logo{display:flex;align-items:center;gap:12px;margin-bottom:24px}
.logo-icon{width:40px;height:40px;background:#0d7f8e;border-radius:10px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:20px;font-weight:800}
.ok{background:#e3f3ea;color:#1f8a5b;border-radius:9px;padding:10px 14px;font-size:13.5px;margin-bottom:8px}
.err{background:#fae6e2;color:#bf3b2b;border-radius:9px;padding:10px 14px;font-size:13.5px;margin-bottom:8px}
.btn{display:inline-block;margin-top:20px;background:#0d7f8e;color:#fff;border-radius:10px;padding:12px 24px;font-weight:700;font-size:15px;text-decoration:none}
.note{margin-top:18px;background:#f6f9f9;border-radius:10px;padding:14px;font-size:13px;color:#5e767c;line-height:1.6}
code{background:#e4f2f3;border-radius:5px;padding:1px 5px;font-size:12px;color:#0a6470}
</style>
</head>
<body>
<div class="box">
  <div class="logo">
    <div class="logo-icon">≈</div>
    <div><h1>BaturaSys Setup</h1><div style="font-size:13px;color:#5e767c">Database seeding</div></div>
  </div>
  <% if (!confirmed && errors.isEmpty()) { %>
    <div class="err">⚠ This will <strong>permanently delete all bookings, customers, staff, equipment,
      watercraft, maintenance tasks, transactions, alerts and settings</strong> and replace them with demo data.</div>
    <form method="POST" style="margin-top:18px">
      <label style="font-size:13.5px;color:#5e767c">Type <code>RESET</code> to confirm</label><br>
      <input name="confirm" autocomplete="off" style="margin-top:8px;padding:10px 12px;border:1px solid #cfdcde;border-radius:10px;font-size:14px;width:200px">
      <button type="submit" class="btn" style="border:none;cursor:pointer;background:#bf3b2b">Reset database</button>
    </form>
    <a class="btn" href="manager/dashboard.jsp" style="background:#eef2f3;color:#0f262c">Cancel</a>
  <% } else if (!errors.isEmpty()) { for (String e : errors) { %>
    <div class="err">❌ <%= Fn.h(e) %></div>
  <% } } else { %>
    <% for (String m : messages) { %>
      <div class="ok">✓ <%= Fn.h(m) %></div>
    <% } %>
    <div class="note">
      <strong>Setup complete!</strong> Demo credentials:<br>
      <strong>Manager:</strong> <code>MGR-01</code> / <code>batura123</code><br>
      <strong>Staff:</strong> <code>BS-0002</code> / <code>batura123</code><br>
      <strong>Customer:</strong> <code>aisyah@email.com</code> / <code>demo1234</code><br><br>
      <strong>⚠ Delete or protect <code>setup.jsp</code> after setup to prevent re-seeding.</strong>
    </div>
    <a class="btn" href="index.jsp">Go to BaturaSys →</a>
  <% } %>
</div>
</body>
</html>
