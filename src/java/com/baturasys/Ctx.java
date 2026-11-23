package com.baturasys;

import java.io.IOException;
import java.util.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

/**
 * Per-request helper used by every JSP page and API servlet.
 * Java version of includes/auth.php + includes/layout.php.
 *
 * Usage at the top of a JSP:   Ctx c = new Ctx(request, response);
 */
public class Ctx {

    public final HttpServletRequest req;
    public final HttpServletResponse res;
    /** Same as BASE_URL in the PHP version, e.g. "/BaturaSysJava/" */
    public final String BASE;
    /** Same as UPLOAD_URL in the PHP version */
    public final String UPLOAD_URL;

    private static final String ASSET_VERSION = "20260705d";

    public Ctx(HttpServletRequest req, HttpServletResponse res) {
        this.req = req;
        this.res = res;
        this.BASE = req.getContextPath() + "/";
        this.UPLOAD_URL = BASE + "uploads/";
    }

    // ================================================================ request helpers

    public boolean isPost() {
        return "POST".equalsIgnoreCase(req.getMethod());
    }

    /** $_POST['k'] ?? '' (raw, not trimmed) */
    public String post(String k) {
        String v = req.getParameter(k);
        return v == null ? "" : v;
    }

    /** trim($_POST['k'] ?? '') */
    public String postTrim(String k) {
        return post(k).trim();
    }

    /** $_GET['k'] ?? '' */
    public String get(String k) {
        String v = req.getParameter(k);
        return v == null ? "" : v;
    }

    /** $_GET['k'] ?? $default */
    public String get(String k, String def) {
        String v = req.getParameter(k);
        return v == null ? def : v;
    }

    public boolean has(String k) {
        return req.getParameter(k) != null;
    }

    public HttpSession session() {
        return req.getSession(true);
    }

    public Object sess(String k) {
        HttpSession s = req.getSession(false);
        return s == null ? null : s.getAttribute(k);
    }

    public void sessSet(String k, Object v) {
        session().setAttribute(k, v);
    }

    public void sessRemove(String k) {
        HttpSession s = req.getSession(false);
        if (s != null) s.removeAttribute(k);
    }

    /** header('Location: ...'); exit;  — caller must "return;" afterwards. */
    public void redirect(String url) {
        try {
            res.sendRedirect(url);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    // ================================================================ auth.php

    public boolean isCustomer() { return sess("customer") != null; }
    public boolean isStaff()    { return sess("staff") != null; }
    public boolean isManager()  { return sess("manager") != null; }
    public boolean isPortal()   { return isStaff() || isManager(); }

    public Row currentCustomer() { return (Row) sess("customer"); }
    public Row currentStaff()    { return (Row) sess("staff"); }
    public Row currentManager()  { return (Row) sess("manager"); }

    /** Returns false (and redirects) when not logged in as a customer. */
    public boolean requireCustomer() {
        if (!isCustomer()) { redirect(BASE + "login.jsp"); return false; }
        return true;
    }

    public boolean requireStaff() {
        if (!isStaff()) { redirect(BASE + "portal-login.jsp?role=staff"); return false; }
        return true;
    }

    public boolean requireManager() {
        if (!isManager()) { redirect(BASE + "portal-login.jsp?role=manager"); return false; }
        return true;
    }

    private void regenerateId() {
        session();
        try { req.changeSessionId(); } catch (IllegalStateException ignored) { }
    }

    public void loginCustomer(Row customer) {
        regenerateId();
        sessSet("customer", customer);
        sessRemove("staff");
        sessRemove("manager");
    }

    public void loginStaff(Row staff) {
        regenerateId();
        sessSet("staff", staff);
        sessRemove("customer");
        sessRemove("manager");
    }

    public void loginManager(Row manager) {
        regenerateId();
        sessSet("manager", manager);
        sessRemove("customer");
        sessRemove("staff");
    }

    public void logoutAll() {
        HttpSession s = req.getSession(false);
        if (s != null) {
            try { s.invalidate(); } catch (IllegalStateException ignored) { }
        }
    }

    // Flash messages
    public void setFlash(String msg, String type) {
        Map<String, String> f = new HashMap<>();
        f.put("msg", msg);
        f.put("type", type);
        sessSet("flash", f);
    }

    @SuppressWarnings("unchecked")
    public Map<String, String> getFlash() {
        Map<String, String> f = (Map<String, String>) sess("flash");
        sessRemove("flash");
        return f;
    }

    // ================================================================ layout.php

    public String pageHead(String title) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"UTF-8\">\n")
          .append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n")
          .append("<title>").append(title).append(" · BaturaSys</title>\n")
          .append("<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n")
          .append("<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n")
          .append("<link href=\"https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Mono:wght@400;700&display=swap\" rel=\"stylesheet\">\n")
          .append("<link rel=\"stylesheet\" href=\"").append(BASE).append("assets/style.css?v=").append(ASSET_VERSION).append("\">\n")
          .append("<script>const BASE_URL = '").append(BASE).append("';</script>\n")
          .append("</head>\n<body>\n")
          .append("<div id=\"bsy-toast\"><div class=\"inner\"><span class=\"dot\"></span><span class=\"msg\"></span></div></div>");
        Map<String, String> flash = getFlash();
        if (flash != null) {
            sb.append("<div id='bsy-flash' data-msg='").append(Fn.h(flash.get("msg")))
              .append("' data-type='").append(Fn.h(flash.get("type"))).append("' style='display:none'></div>");
        }
        return sb.toString();
    }

    public String pageFoot() {
        return "<script src=\"" + BASE + "assets/app.js?v=" + ASSET_VERSION + "\"></script>\n</body>\n</html>";
    }

    public String customerNav() {
        return customerNav("home");
    }

    public String customerNav(String active) {
        Row customer = currentCustomer();
        boolean authed = customer != null;
        String name = authed ? Fn.h(customer.s("name")) : "";
        String initials = authed ? Fn.initials(customer.s("name")) : "";

        String aHome = "home".equals(active) ? " active" : "";
        String aLookup = "lookup".equals(active) ? " active" : "";
        String aDash = "dashboard".equals(active) ? " active" : "";

        StringBuilder sb = new StringBuilder();
        sb.append("<nav class=\"cust-nav\">\n  <div class=\"inner\">\n")
          .append("    <a class=\"logo\" href=\"").append(BASE).append("index.jsp\">\n")
          .append("      <div class=\"logo-icon\">≈</div>\n      <span class=\"logo-text\">BaturaSys</span>\n    </a>\n")
          .append("    <a href=\"").append(BASE).append("index.jsp\" class=\"nav-link").append(aHome).append("\">Activities</a>\n")
          .append("    <a href=\"").append(BASE).append("lookup.jsp\" class=\"nav-link").append(aLookup).append("\">Check booking</a>\n")
          .append("    <div class=\"spacer\"></div>\n");
        if (authed) {
            sb.append("    <a href=\"").append(BASE).append("customer/dashboard.jsp\" class=\"nav-link").append(aDash).append("\">My bookings</a>\n")
              .append("    <a href=\"").append(BASE).append("customer/profile.jsp\" class=\"user-chip bsy-tap\">\n")
              .append("      ").append(name).append("\n")
              .append("      <span class=\"avatar\">").append(initials).append("</span>\n    </a>\n");
        } else {
            sb.append("    <a href=\"").append(BASE).append("login.jsp\" class=\"btn btn-ghost btn-sm\" style=\"font-size:14px;padding:9px 16px\">Log in</a>\n")
              .append("    <a href=\"").append(BASE).append("register.jsp\" class=\"btn btn-brand btn-sm\" style=\"font-size:14px;padding:10px 16px\">Sign up</a>\n");
        }
        sb.append("</div></nav>\n");
        return sb.toString();
    }

    public String customerFooter() {
        return "<footer class=\"cust-footer\">\n  <div class=\"inner\">\n"
             + "    <span class=\"fs-12 text-muted\">© 2026 Antan Batura Watersports · Taman Tasik Shah Alam, Selangor</span>\n"
             + "    <a href=\"" + BASE + "portal-login.jsp\" class=\"btn btn-ghost btn-sm\" style=\"font-size:13px\">🔐 Staff &amp; Manager portal</a>\n"
             + "  </div>\n</footer>";
    }

    private String sidebar(String sub, String userName, String initials, String role, String active, Object[][] nav) {
        StringBuilder sb = new StringBuilder();
        sb.append("<aside class=\"sidebar bsy-scroll\"><div class=\"sidebar-brand\"><div class=\"icon\">≈</div><div><div class=\"title\">BaturaSys</div><div class=\"sub\">")
          .append(sub).append("</div></div></div><nav class=\"sidebar-nav\">");
        for (Object[] n : nav) {
            String path = (String) n[0], key = (String) n[1], icon = (String) n[2], label = (String) n[3];
            int badge = (Integer) n[4];
            String cls = active.equals(key) ? " active" : "";
            String badgeHtml = badge != 0 ? "<span class='nav-badge'>" + badge + "</span>" : "";
            sb.append("<a href='").append(BASE).append(path).append("' class='").append(cls).append("'><span class='nav-icon'>")
              .append(icon).append("</span><span style='flex:1'>").append(label).append("</span>").append(badgeHtml).append("</a>");
        }
        sb.append("</nav><div class='sidebar-user'><div class='ua'>").append(initials).append("</div><div><div class='uname'>")
          .append(userName).append("</div><div class='urole'>").append(role).append("</div></div></div></aside>");

        Object welcome = sess("portal_welcome");
        if (welcome != null && !welcome.toString().isEmpty()) {
            sessRemove("portal_welcome");
            sb.append("\n<div class=\"bsy-overlay open\" id=\"modal-welcome\">\n")
              .append("  <div class=\"bsy-modal\" style=\"max-width:340px;text-align:center;padding:36px 28px\">\n")
              .append("    <div style=\"font-size:48px;margin-bottom:12px\">👋</div>\n")
              .append("    <div style=\"font-size:22px;font-weight:800;letter-spacing:-.4px;margin-bottom:6px\">Welcome back!</div>\n")
              .append("    <div style=\"font-size:15px;color:var(--muted);margin-bottom:26px\">").append(Fn.h(welcome)).append("</div>\n")
              .append("    <button class=\"btn btn-brand w-full\" onclick=\"closeModal('modal-welcome')\" style=\"font-size:15px;padding:13px\">Let's get started</button>\n")
              .append("  </div>\n</div>");
        }
        return sb.toString();
    }

    public String staffSidebar(String active) {
        Row staff = currentStaff();
        String name = staff != null ? Fn.h(staff.s("name")) : "Staff";
        String initials = staff != null ? Fn.substr(name, 0, 2).toUpperCase() : "ST";

        int pending = Db.scalarInt("SELECT COUNT(DISTINCT COALESCE(group_ref, ref)) FROM bookings WHERE status='AWAITING_VERIFICATION'");
        int confirmed = Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE status='CONFIRMED'");
        int activeR = Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE status='CHECKED_IN'");
        String staffId = staff != null ? staff.str("staff_id") : "";
        int tasks = Db.scalarInt("SELECT COUNT(*) FROM maintenance_tasks WHERE assignee_id=? AND status IN ('SCHEDULED','IN_PROGRESS','OVERDUE')", staffId);

        Object[][] nav = {
            {"staff/dashboard.jsp",   "dashboard",   "◧",  "Overview",        0},
            {"staff/verify.jsp",      "verify",      "🧾", "Verify payments", pending},
            {"staff/checkin.jsp",     "checkin",     "✓",  "Check-in",        confirmed},
            {"staff/returns.jsp",     "returns",     "↩",  "Rental returns",  activeR},
            {"staff/equipment.jsp",   "equipment",   "🦺", "Equipment",       0},
            {"staff/maintenance.jsp", "maintenance", "🔧", "Maintenance",     tasks},
        };
        return sidebar("Staff portal", name, initials, "Staff", active, nav);
    }

    public String managerSidebar(String active) {
        Row mgr = currentManager();
        String name = mgr != null ? Fn.h(mgr.s("name")) : "Manager";
        String initials = mgr != null ? Fn.initials(mgr.s("name")) : "MG";

        int unread = Db.scalarInt("SELECT COUNT(*) FROM alerts WHERE is_read=0");

        Object[][] nav = {
            {"manager/dashboard.jsp",   "dashboard",   "◧",  "Dashboard",        0},
            {"manager/equipment.jsp",   "equipment",   "🦺", "Equipment",        0},
            {"manager/watercraft.jsp",  "watercraft",  "🛶", "Watercraft fleet", 0},
            {"manager/maintenance.jsp", "maintenance", "🔧", "Maintenance",      0},
            {"manager/staff.jsp",       "staff",       "👥", "Staff accounts",   0},
            {"manager/payment.jsp",     "payment",     "💳", "Payment settings", 0},
            {"manager/settings.jsp",    "settings",    "⚙",  "System settings",  0},
            {"manager/reports.jsp",     "reports",     "📊", "Reports",          0},
            {"manager/alerts.jsp",      "alerts",      "🔔", "Alerts",           unread},
        };
        return sidebar("Manager console", name, initials, "Manager · Full access", active, nav);
    }

    public String logoutFab() {
        return "<a href='" + BASE + "portal-logout.jsp' class='logout-fab bsy-tap'><span style='font-size:13px'>⎋</span> Log out</a>";
    }

    // ================================================================ booking access

    /** COALESCE(group_ref, ref) of a booking row. */
    public static String groupOf(Row b) {
        return b.s("group_ref") != null ? b.s("group_ref") : b.s("ref");
    }

    /** Remember that this visitor created / looked up this booking (by its reference). */
    @SuppressWarnings("unchecked")
    public void allowBookingGroup(String gref) {
        if (gref == null) return;
        Set<String> s = (Set<String>) sess("viewable_groups");
        if (s == null) { s = new HashSet<>(); }
        s.add(gref.toUpperCase());
        sessSet("viewable_groups", s);
    }

    /**
     * Who may see a booking: staff/manager; the customer who owns it; or a visitor
     * who made it or looked it up with its reference number in this session.
     */
    @SuppressWarnings("unchecked")
    public boolean canViewBooking(Row b) {
        if (b == null) return false;
        if (isStaff() || isManager()) return true;
        Row cust = currentCustomer();
        if (cust != null && !b.isNull("customer_id") && b.i("customer_id") == cust.i("id")) return true;
        Set<String> s = (Set<String>) sess("viewable_groups");
        return s != null && s.contains(groupOf(b).toUpperCase());
    }

    // ================================================================ booking cart (session)

    @SuppressWarnings("unchecked")
    public List<CartItem> cart() {
        List<CartItem> cart = (List<CartItem>) sess("booking_cart");
        if (cart == null) {
            cart = new ArrayList<>();
            sessSet("booking_cart", cart);
        }
        return cart;
    }

    public void clearCart() {
        sessSet("booking_cart", new ArrayList<CartItem>());
    }

    @SuppressWarnings("unchecked")
    public List<Integer> currentBookingIds() {
        Object v = sess("current_booking_ids");
        return v == null ? new ArrayList<Integer>() : (List<Integer>) v;
    }
}
