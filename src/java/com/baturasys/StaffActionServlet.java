package com.baturasys;

import java.util.*;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;

/** Java version of api/staff-action.php */
@WebServlet(name = "StaffActionServlet", urlPatterns = {"/api/staff-action"})
@MultipartConfig
public class StaffActionServlet extends ApiServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void handle(Ctx c) {
        if (!c.requireStaff()) return;

        // receipt_img is loaded as img.src (GET), so handle before JSON
        String getAction = c.req.getQueryString() != null ? c.get("action") : "";
        if ("receipt_img".equals(getAction) && "GET".equalsIgnoreCase(c.req.getMethod())) {
            String groupRef = c.get("group_ref").trim();
            int bookingId = Fn.toInt(c.has("id") ? c.get("id") : c.get("booking_id"));
            Row row = null;
            if (!Fn.empty(groupRef)) {
                row = Db.one("SELECT receipt_path FROM bookings WHERE (group_ref=? OR (group_ref IS NULL AND ref=?)) AND receipt_path IS NOT NULL ORDER BY id FETCH FIRST 1 ROWS ONLY",
                        groupRef, groupRef);
            } else if (bookingId != 0) {
                row = Db.one("SELECT receipt_path FROM bookings WHERE id=?", bookingId);
            }
            if (row != null && !Fn.empty(row.s("receipt_path"))) {
                c.redirect(c.UPLOAD_URL + row.s("receipt_path"));
                return;
            }
            try {
                c.res.setStatus(404);
                c.res.setContentType("text/plain; charset=UTF-8");
                c.res.getWriter().print("Receipt not found");
            } catch (java.io.IOException ignored) { }
            return;
        }

        String action = c.post("action");
        try {
            switch (action) {
                case "approve":        approvePayment(c); break;
                case "reject":         rejectPayment(c); break;
                case "receipt_img":    receiptImg(c); break;
                case "checkin_search": checkinSearch(c); break;
                case "available_wc":   availableWatercraft(c); break;
                case "checkin":        checkin(c); break;
                case "return":         processReturn(c); break;
                case "equip_update":   equipUpdate(c); break;
                case "flag_equip":     flagEquip(c); break;
                case "task_start":     taskStart(c); break;
                case "task_complete":  taskComplete(c); break;
                default:               jsonErr("Unknown action");
            }
        } catch (JsonExit e) {
            throw e;
        } catch (RuntimeException e) {
            jsonErr("Server error: " + e.getMessage());
        }
    }

    // ---------- Payment verification ----------

    private void approvePayment(Ctx c) {
        String groupRef = p(c, "group_ref").trim();
        if (Fn.empty(groupRef)) jsonErr("Missing booking reference");

        List<Row> bookings = Db.all("SELECT * FROM bookings WHERE (group_ref=? OR (group_ref IS NULL AND ref=?)) AND status='AWAITING_VERIFICATION'",
                groupRef, groupRef);
        if (bookings.isEmpty()) jsonErr("Booking not found or not awaiting verification");

        double totalAmount = 0;
        for (Row b : bookings) {
            Db.exec("UPDATE bookings SET status='CONFIRMED', updated_at=CURRENT_TIMESTAMP WHERE id=?", b.i("id"));
            if (b.truthy("watercraft_id")) {
                Db.exec("UPDATE watercraft SET status='AVAILABLE' WHERE identifier=?", b.s("watercraft_id"));
            }
            totalAmount += b.d("amount");
        }

        Fn.addTransaction(groupRef, Fn.today(), totalAmount, "DuitNow", "Rental");
        Fn.addAlert("Payment", "low", "Payment verified for " + groupRef + " — " + bookings.size() + " booking(s) confirmed.");

        jsonOk(map("message", "Payment approved"));
    }

    private void rejectPayment(Ctx c) {
        String groupRef = p(c, "group_ref").trim();
        String custom = p(c, "reason").trim();
        String preset = p(c, "preset").trim();
        String reason = !Fn.empty(custom) ? custom : preset;
        if (Fn.empty(groupRef)) jsonErr("Missing booking reference");
        if (Fn.empty(reason)) jsonErr("Please select a reason or type a custom reason.");

        List<Row> bookings = Db.all("SELECT * FROM bookings WHERE (group_ref=? OR (group_ref IS NULL AND ref=?)) AND status='AWAITING_VERIFICATION'",
                groupRef, groupRef);
        if (bookings.isEmpty()) jsonErr("Booking not found or not awaiting verification");

        for (Row b : bookings) {
            Db.exec("UPDATE bookings SET status='REJECTED', rejection_reason=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
                    Fn.empty(reason) ? null : reason, b.i("id"));
            if (b.truthy("watercraft_id")) {
                Db.exec("UPDATE watercraft SET status='AVAILABLE' WHERE identifier=?", b.s("watercraft_id"));
            }
        }

        Fn.addAlert("Payment", "medium", "Payment rejected for " + groupRef + (!Fn.empty(reason) ? ": " + reason : ""));

        jsonOk(map("message", "Payment rejected"));
    }

    private void receiptImg(Ctx c) {
        String raw = c.has("booking_id") ? c.post("booking_id") : (c.has("id") ? c.get("id") : "");
        int bookingId = Fn.toInt(raw);
        if (bookingId == 0) jsonErr("Missing booking ID");

        Row booking = Db.one("SELECT receipt_path FROM bookings WHERE id=?", bookingId);
        if (booking == null || Fn.empty(booking.s("receipt_path"))) jsonErr("No receipt found");

        jsonOk(map("url", c.UPLOAD_URL + booking.s("receipt_path")));
    }

    // ---------- Check-in ----------

    private void availableWatercraft(Ctx c) {
        int bookingId = Fn.toInt(p(c, "booking_id"));
        if (bookingId == 0) jsonErr("Missing booking ID");

        Row booking = Db.one("SELECT activity_id, booking_date, slot FROM bookings WHERE id=? AND status='CONFIRMED'", bookingId);
        if (booking == null) jsonErr("Booking not found or not in CONFIRMED status");

        // Physically available watercraft for this activity
        List<Row> allAvail = Db.all("SELECT identifier, name, usage_hours, condition_status FROM watercraft WHERE activity_id=? AND status='AVAILABLE' ORDER BY name",
                booking.s("activity_id"));

        // Watercraft already assigned to another booking in this same slot
        Set<String> blocked = new HashSet<>();
        for (Row r : Db.all("SELECT watercraft_id FROM bookings WHERE booking_date=? AND slot=? AND activity_id=? AND status IN ('AWAITING_VERIFICATION','CONFIRMED','CHECKED_IN') AND watercraft_id IS NOT NULL AND watercraft_id <> '' AND id <> ?",
                booking.s("booking_date"), booking.s("slot"), booking.s("activity_id"), bookingId)) {
            blocked.add(r.s("watercraft_id"));
        }

        List<Map<String, Object>> available = new ArrayList<>();
        for (Row w : allAvail) {
            if (!blocked.contains(w.s("identifier"))) {
                available.add(map("identifier", w.s("identifier"), "name", w.s("name"),
                        "usage_hours", w.i("usage_hours"), "condition_status", w.s("condition_status")));
            }
        }

        jsonOk(map("watercraft", available));
    }

    private void checkinSearch(Ctx c) {
        String q = p(c, "q").trim();
        if (q.length() < 2) jsonErr("Query too short");

        String like = "%" + q + "%";
        List<Row> rows = Db.all("SELECT b.*, w.name as wc_name FROM bookings b "
                + "LEFT JOIN watercraft w ON b.watercraft_id = w.identifier "
                + "WHERE b.status='CONFIRMED' AND (b.ref LIKE ? OR b.customer_name LIKE ?) "
                + "ORDER BY b.booking_date, b.slot FETCH FIRST 10 ROWS ONLY", like, like);

        StringBuilder html = new StringBuilder();
        if (rows.isEmpty()) {
            html.append("<div style=\"padding:14px;font-size:13px;color:var(--muted)\">No confirmed bookings matched.</div>");
        } else {
            for (Row b : rows) {
                String custName = Fn.h(b.s("customer_name"));
                String wcName = Fn.h(Fn.coalesce(b.s("wc_name"), b.s("watercraft_id")));
                String ref = Fn.h(b.s("ref"));
                String slot = Fn.h(b.s("slot"));
                html.append("<div class=\"bsy-row\" style=\"padding:12px 16px;display:flex;align-items:center;gap:12px;border-bottom:1px solid var(--border-2)\">")
                    .append("<div style=\"flex:1\">")
                    .append("<div class=\"fw-800 fs-13\">").append(custName).append("</div>")
                    .append("<div class=\"fs-12 mono text-muted\">").append(ref).append(" · ").append(slot).append(" · ").append(wcName).append("</div>")
                    .append("</div>")
                    .append("<button class=\"btn btn-brand btn-xs\" onclick=\"openCheckinModal(").append(b.i("id"))
                    .append(",'").append(Fn.jsAttr(b.s("ref"))).append("','").append(Fn.jsAttr(b.s("customer_name"))).append("')\">Check in</button>")
                    .append("</div>");
            }
        }

        jsonOk(map("html", html.toString()));
    }

    private void checkin(Ctx c) {
        int bookingId = Fn.toInt(p(c, "booking_id"));
        String watercraftId = p(c, "watercraft_id").trim();
        String[] equipRaw = c.req.getParameterValues("equip[]");
        if (equipRaw == null) equipRaw = c.req.getParameterValues("equip");
        List<String> parts = new ArrayList<>();
        if (equipRaw != null) {
            for (String e : equipRaw) {
                String t = e == null ? "" : e.trim();
                if (!Fn.empty(t)) parts.add(t);
            }
        }
        String equip = String.join(", ", parts);
        if (bookingId == 0) jsonErr("Missing booking ID");
        if (Fn.empty(watercraftId)) jsonErr("Please select a watercraft");

        Row booking = Db.one("SELECT * FROM bookings WHERE id=? AND status='CONFIRMED'", bookingId);
        if (booking == null) jsonErr("Booking not found or not in CONFIRMED status");

        // Confirm watercraft is still available
        Row wc = Db.one("SELECT status FROM watercraft WHERE identifier=?", watercraftId);
        if (wc == null || !"AVAILABLE".equals(wc.s("status"))) jsonErr("Selected watercraft is no longer available");

        Db.exec("UPDATE bookings SET status='CHECKED_IN', watercraft_id=?, checkin_at=CURRENT_TIMESTAMP, equipment_assigned=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
                watercraftId, Fn.empty(equip) ? null : equip, bookingId);
        Db.exec("UPDATE watercraft SET status='IN_USE' WHERE identifier=?", watercraftId);

        jsonOk(map("message", "Customer checked in"));
    }

    // ---------- Returns ----------

    private void processReturn(Ctx c) {
        int bookingId = Fn.toInt(p(c, "booking_id"));
        String damage = c.has("damage") ? c.post("damage") : "no";
        String issue = p(c, "issue").trim();
        if (bookingId == 0) jsonErr("Missing booking ID");

        if ("yes".equals(damage) && Fn.empty(issue)) jsonErr("Notes required when reporting an incident");

        Row booking = Db.one("SELECT * FROM bookings WHERE id=? AND status='CHECKED_IN'", bookingId);
        if (booking == null) jsonErr("Booking not found or not in CHECKED_IN status");

        Db.exec("UPDATE bookings SET status='COMPLETED', checkout_at=CURRENT_TIMESTAMP, return_notes=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
                Fn.empty(issue) ? null : issue, bookingId);
        Db.exec("UPDATE watercraft SET status='AVAILABLE' WHERE identifier=?", booking.s("watercraft_id"));

        if ("yes".equals(damage)) {
            Fn.addAlert("Flagged Booking", "high", "Return incident reported for " + booking.s("ref") + ": " + issue);
        }

        jsonOk(map("message", "Return processed"));
    }

    // ---------- Equipment ----------

    private void equipUpdate(Ctx c) {
        int id = Fn.toInt(p(c, "equip_id"));
        String cond = p(c, "cond").trim();
        String note = p(c, "note").trim();
        if (id == 0 || Fn.empty(cond)) jsonErr("Missing fields");

        boolean bad = "Damaged".equals(cond) || "Missing".equals(cond);
        if (bad && Fn.empty(note)) jsonErr("Notes required for Damaged or Missing condition");

        if (!Arrays.asList("Good", "Worn", "Damaged", "Missing").contains(cond)) jsonErr("Invalid condition");

        Db.exec("UPDATE equipment SET condition_status=?, updated_at=CURRENT_TIMESTAMP WHERE id=?", cond, id);

        if (bad) {
            Row eq = Db.one("SELECT equipment_id, type FROM equipment WHERE id=?", id);
            String eid = eq != null ? eq.str("equipment_id") : "";
            String type = eq != null ? eq.str("type") : "";
            Fn.addAlert("Damaged/Missing Equipment", "high", "Equipment " + eid + " (" + type + ") marked " + cond + ": " + note);
        }

        jsonOk(map("message", "Condition updated"));
    }

    private void flagEquip(Ctx c) {
        int id = Fn.toInt(p(c, "equip_id"));
        if (id == 0) jsonErr("Missing equipment ID");

        Row eq = Db.one("SELECT * FROM equipment WHERE id=? AND status='Active'", id);
        if (eq == null) jsonErr("Equipment not found or already flagged");

        Db.exec("UPDATE equipment SET status='Flagged', updated_at=CURRENT_TIMESTAMP WHERE id=?", id);

        Fn.addAlert("Flagged Equipment", "medium", "Equipment " + eq.s("equipment_id") + " (" + eq.s("type") + ") flagged for replacement.");

        jsonOk(map("message", "Equipment flagged"));
    }

    // ---------- Maintenance ----------

    private void taskStart(Ctx c) {
        int taskId = Fn.toInt(p(c, "task_id"));
        if (taskId == 0) jsonErr("Missing task ID");

        Row staff = c.currentStaff();
        Row task = Db.one("SELECT * FROM maintenance_tasks WHERE id=? AND assignee_id=?", taskId, staff.s("staff_id"));
        if (task == null) jsonErr("Task not found or not assigned to you");

        String st = task.s("status");
        if (!"SCHEDULED".equals(st) && !"OVERDUE".equals(st)) jsonErr("Task cannot be started in its current status");

        Db.exec("UPDATE maintenance_tasks SET status='IN_PROGRESS', updated_at=CURRENT_TIMESTAMP WHERE id=?", taskId);
        Db.exec("UPDATE watercraft SET status='UNDER_MAINTENANCE' WHERE identifier=?", task.s("watercraft_id"));

        jsonOk(map("message", "Task started"));
    }

    private void taskComplete(Ctx c) {
        int taskId = Fn.toInt(p(c, "task_id"));
        String note = p(c, "note").trim();
        if (taskId == 0) jsonErr("Missing task ID");
        if (Fn.empty(note)) jsonErr("Maintenance notes are required");

        Row staff = c.currentStaff();
        Row task = Db.one("SELECT * FROM maintenance_tasks WHERE id=? AND assignee_id=?", taskId, staff.s("staff_id"));
        if (task == null) jsonErr("Task not found or not assigned to you");

        if (!"IN_PROGRESS".equals(task.s("status"))) jsonErr("Task must be in progress to complete");

        Db.exec("UPDATE maintenance_tasks SET status='COMPLETED', notes=?, completed_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP WHERE id=?", note, taskId);

        Fn.addAlert("Maintenance", "low", "Maintenance task #" + taskId + " completed — awaiting manager approval.");

        jsonOk(map("message", "Task submitted for approval"));
    }
}
