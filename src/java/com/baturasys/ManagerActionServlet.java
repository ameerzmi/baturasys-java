package com.baturasys;

import java.io.*;
import java.nio.file.*;
import java.time.LocalDate;
import java.util.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.Part;

/** Java version of api/manager-action.php */
@WebServlet(name = "ManagerActionServlet", urlPatterns = {"/api/manager-action"})
@MultipartConfig(maxFileSize = 52428800L, maxRequestSize = 62914560L)
public class ManagerActionServlet extends ApiServlet {

    private static final long serialVersionUID = 1L;
    private static final List<String> VALID_ACTIVITIES = Fn.ACTIVITY_IDS;

    @Override
    protected void handle(Ctx c) {
        if (!c.requireManager()) return;

        String action = c.post("action");
        try {
            switch (action) {
                case "upload_qr":            uploadQr(c); break;
                case "add_equipment":        addEquipment(c); break;
                case "edit_equipment":       editEquipment(c); break;
                case "retire_equipment":     retireEquipment(c); break;
                case "add_watercraft":       addWatercraft(c); break;
                case "edit_watercraft":      editWatercraft(c); break;
                case "retire_watercraft":    retireWatercraft(c); break;
                case "schedule_task":        scheduleTask(c); break;
                case "approve_task":         approveTask(c); break;
                case "reopen_task":          reopenTask(c); break;
                case "add_staff":            addStaff(c); break;
                case "deactivate_staff":     setStaffStatus(c, "Deactivated"); break;
                case "activate_staff":       setStaffStatus(c, "Active"); break;
                case "reset_staff_pw":       resetStaffPw(c); break;
                case "save_payment":         savePayment(c); break;
                case "save_settings":        saveSettings(c); break;
                case "save_activity":        saveActivity(c); break;
                case "mark_alert_read":      markAlertRead(c); break;
                case "mark_all_alerts_read": markAllAlertsRead(); break;
                default:                     jsonErr("Unknown action");
            }
        } catch (JsonExit e) {
            throw e;
        } catch (Exception e) {
            jsonErr("Server error: " + e.getMessage());
        }
    }

    // ---------- QR upload ----------

    private void uploadQr(Ctx c) throws IOException, ServletException {
        Part file;
        try {
            file = c.req.getPart("qr_file");
        } catch (IllegalStateException e) {
            jsonErr("File too large (max 5 MB)");
            return;
        }
        if (file == null || file.getSubmittedFileName() == null || file.getSubmittedFileName().isEmpty()) {
            jsonErr("No file uploaded");
        }
        if (file.getSize() > Config.MAX_UPLOAD_BYTES) jsonErr("File too large (max 5 MB)");

        byte[] data = readAll(file);
        String mime = sniffMime(data);
        if (!"image/png".equals(mime) && !"image/jpeg".equals(mime)) jsonErr("Only PNG and JPG allowed");

        String ext = "image/png".equals(mime) ? "png" : "jpg";
        String filename = "duitnow_qr." + ext;
        File dir = new File(Config.UPLOAD_DIR);
        if (!dir.isDirectory() && !dir.mkdirs()) jsonErr("Failed to save file");
        try {
            Files.write(new File(dir, filename).toPath(), data);
        } catch (IOException e) {
            jsonErr("Failed to save file");
        }

        Fn.saveSetting("qr_image_path", filename);

        jsonOk(map("url", c.UPLOAD_URL + filename));
    }

    static byte[] readAll(Part part) throws IOException {
        try (InputStream in = part.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toByteArray();
        }
    }

    /** mime_content_type() for the two image types we accept. */
    static String sniffMime(byte[] d) {
        if (d.length >= 8 && (d[0] & 0xff) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G') return "image/png";
        if (d.length >= 3 && (d[0] & 0xff) == 0xFF && (d[1] & 0xff) == 0xD8 && (d[2] & 0xff) == 0xFF) return "image/jpeg";
        return "application/octet-stream";
    }

    // ---------- Equipment ----------

    private void addEquipment(Ctx c) {
        String type = p(c, "type").trim();
        String size = p(c, "size").trim();
        String countRaw = p(c, "count").trim();
        if (Fn.empty(type)) jsonErr("Type is required");
        if (Fn.empty(size)) jsonErr("Size / variant is required");
        if (!Fn.ctypeDigit(countRaw) || Fn.toInt(countRaw) < 1 || Fn.toInt(countRaw) > 50) {
            jsonErr("Enter a valid number");
        }
        int count = Fn.toInt(countRaw);

        List<String> ids = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            String equipId = Fn.nextEquipId();
            Db.exec("INSERT INTO equipment (equipment_id, type, size, condition_status, status) VALUES (?,?,?,'Good','Active')",
                    equipId, type, size);
            ids.add(equipId);
        }

        jsonOk(map("message", count + " item(s) added", "equipment_ids", ids));
    }

    private void editEquipment(Ctx c) {
        int id = Fn.toInt(p(c, "equip_db_id"));
        String type = p(c, "type").trim();
        String size = p(c, "size").trim();
        String cond = c.has("condition_status") ? c.post("condition_status").trim() : "Good";
        if (id == 0 || Fn.empty(type)) jsonErr("Missing required fields");

        Db.exec("UPDATE equipment SET type=?, size=?, condition_status=?, updated_at=CURRENT_TIMESTAMP WHERE id=?", type, size, cond, id);

        jsonOk(map("message", "Equipment updated"));
    }

    private void retireEquipment(Ctx c) {
        int id = Fn.toInt(p(c, "equip_db_id"));
        if (id == 0) jsonErr("Missing ID");

        Db.exec("UPDATE equipment SET status='Retired', updated_at=CURRENT_TIMESTAMP WHERE id=?", id);

        jsonOk(map("message", "Equipment retired"));
    }

    // ---------- Watercraft ----------

    private void addWatercraft(Ctx c) {
        String name = p(c, "name").trim();
        String activityId = p(c, "activity_id").trim();
        int capacity = c.has("capacity") ? Fn.toInt(c.post("capacity")) : 1;
        double rate = Fn.toFloat(p(c, "rate_per_unit"));
        String year = p(c, "year_acquired").trim();
        if (Fn.empty(name) || Fn.empty(activityId)) jsonErr("Name and activity are required");
        if (capacity < 1) jsonErr("Capacity must be at least 1");

        if (!VALID_ACTIVITIES.contains(activityId)) jsonErr("Invalid activity type");

        // Generate identifier
        String prefix = activityId.substring(0, Math.min(2, activityId.length())).toUpperCase();
        int count = Db.scalarInt("SELECT COUNT(*) FROM watercraft WHERE activity_id=?", activityId);
        String identifier = "WC-" + prefix + "-" + Fn.padLeft(count + 1, 3);

        Db.exec("INSERT INTO watercraft (identifier, name, activity_id, capacity, rate_per_unit, year_acquired, status) VALUES (?,?,?,?,?,?,'AVAILABLE')",
                identifier, name, activityId, capacity, rate, Fn.empty(year) ? null : year);

        jsonOk(map("message", "Watercraft added", "identifier", identifier));
    }

    private void editWatercraft(Ctx c) {
        int id = Fn.toInt(p(c, "wc_id"));
        String name = p(c, "name").trim();
        String activityId = p(c, "activity_id").trim();
        int capacity = c.has("capacity") ? Fn.toInt(c.post("capacity")) : 1;
        double rate = Fn.toFloat(p(c, "rate_per_unit"));
        String status = c.has("status") ? c.post("status").trim() : "AVAILABLE";
        String year = p(c, "year_acquired").trim();
        if (id == 0 || Fn.empty(name)) jsonErr("Missing required fields");

        if (!"AVAILABLE".equals(status) && !"UNDER_MAINTENANCE".equals(status)) jsonErr("Invalid status");

        Db.exec("UPDATE watercraft SET name=?, activity_id=?, capacity=?, rate_per_unit=?, status=?, year_acquired=? WHERE id=?",
                name, activityId, capacity, rate, status, Fn.empty(year) ? null : year, id);

        jsonOk(map("message", "Watercraft updated"));
    }

    private void retireWatercraft(Ctx c) {
        int id = Fn.toInt(p(c, "wc_id"));
        if (id == 0) jsonErr("Missing ID");

        Row wc = Db.one("SELECT status FROM watercraft WHERE id=?", id);
        if (wc == null) jsonErr("Watercraft not found");
        if ("IN_USE".equals(wc.s("status"))) jsonErr("Cannot retire a watercraft that is currently in use");

        Db.exec("UPDATE watercraft SET status='RETIRED' WHERE id=?", id);

        jsonOk(map("message", "Watercraft retired"));
    }

    // ---------- Maintenance ----------

    private void scheduleTask(Ctx c) {
        String type = p(c, "type").trim();
        String wcId = p(c, "watercraft_id").trim();
        String assigneeId = p(c, "assignee_id").trim();
        String scheduledDate = p(c, "scheduled_date").trim();
        String recurRaw = c.has("recurring_days") ? c.post("recurring_days").trim() : "0";
        if (Fn.empty(type) || Fn.empty(wcId) || Fn.empty(assigneeId) || Fn.empty(scheduledDate)) {
            jsonErr("All required fields must be filled");
        }
        if (!Fn.ctypeDigit(recurRaw) || Fn.toInt(recurRaw) > 365) jsonErr("Repeat every (days) must be a whole number from 0 to 365");
        int recurDays = Fn.toInt(recurRaw);

        String taskId = Fn.nextTaskId();
        Db.exec("INSERT INTO maintenance_tasks (task_id, type, watercraft_id, assignee_id, scheduled_date, recurring_days, status) VALUES (?,?,?,?,?,?,'SCHEDULED')",
                taskId, type, wcId, assigneeId, scheduledDate, recurDays);

        Fn.addAlert("Maintenance", "low", "Maintenance task scheduled: " + type + " for " + wcId + " on " + scheduledDate);

        jsonOk(map("message", "Task scheduled", "task_id", taskId));
    }

    private void approveTask(Ctx c) {
        int taskId = Fn.toInt(p(c, "task_id"));
        if (taskId == 0) jsonErr("Missing task ID");

        Row task = Db.one("SELECT * FROM maintenance_tasks WHERE id=? AND status='COMPLETED'", taskId);
        if (task == null) jsonErr("Task not found or not awaiting approval");

        Db.exec("UPDATE maintenance_tasks SET status='APPROVED', updated_at=CURRENT_TIMESTAMP WHERE id=?", taskId);

        // Free watercraft if still under maintenance
        Row wc = Db.one("SELECT status FROM watercraft WHERE identifier=?", task.s("watercraft_id"));
        if (wc != null && "UNDER_MAINTENANCE".equals(wc.s("status"))) {
            Db.exec("UPDATE watercraft SET status='AVAILABLE' WHERE identifier=?", task.s("watercraft_id"));
        }

        // Schedule next if recurring
        if (task.i("recurring_days") > 0) {
            String nextDate = LocalDate.parse(task.s("scheduled_date")).plusDays(task.i("recurring_days")).toString();
            String nextId = Fn.nextTaskId();
            Db.exec("INSERT INTO maintenance_tasks (task_id, type, watercraft_id, assignee_id, scheduled_date, recurring_days, status) VALUES (?,?,?,?,?,?,'SCHEDULED')",
                    nextId, task.s("type"), task.s("watercraft_id"), task.s("assignee_id"), nextDate, task.i("recurring_days"));
        }

        jsonOk(map("message", "Task approved"));
    }

    private void reopenTask(Ctx c) {
        int taskId = Fn.toInt(p(c, "task_id"));
        if (taskId == 0) jsonErr("Missing task ID");

        Row task = Db.one("SELECT status FROM maintenance_tasks WHERE id=?", taskId);
        if (task == null) jsonErr("Task not found");

        Db.exec("UPDATE maintenance_tasks SET status='IN_PROGRESS', updated_at=CURRENT_TIMESTAMP WHERE id=?", taskId);

        jsonOk(map("message", "Task reopened"));
    }

    // ---------- Staff ----------

    private void addStaff(Ctx c) {
        String name = p(c, "name").trim();
        String email = p(c, "email").trim();
        String phone = p(c, "phone").trim();
        String password = p(c, "password");
        if (Fn.empty(name)) jsonErr("Name is required");
        if (password.length() < 8) jsonErr("Password must be at least 8 characters");

        String staffId = Fn.nextStaffId();
        String pwHash = BCrypt.hash(password);

        Db.exec("INSERT INTO staff (staff_id, name, email, phone, password_hash, status) VALUES (?,?,?,?,?,'Active')",
                staffId, name, Fn.empty(email) ? null : email, Fn.empty(phone) ? null : phone, pwHash);

        jsonOk(map("message", "Staff account created", "staff_id", staffId));
    }

    private void setStaffStatus(Ctx c, String status) {
        int id = Fn.toInt(p(c, "staff_db_id"));
        if (id == 0) jsonErr("Missing staff ID");

        Db.exec("UPDATE staff SET status=? WHERE id=?", status, id);

        jsonOk(map("message", "Staff status updated"));
    }

    private void resetStaffPw(Ctx c) {
        int id = Fn.toInt(p(c, "staff_db_id"));
        String pw = p(c, "new_password");
        if (id == 0) jsonErr("Missing staff ID");
        if (pw.length() < 8) jsonErr("Password must be at least 8 characters");

        Db.exec("UPDATE staff SET password_hash=? WHERE id=?", BCrypt.hash(pw), id);

        jsonOk(map("message", "Password reset successfully"));
    }

    // ---------- Settings ----------

    private void savePayment(Ctx c) {
        String[] keys = {"bank_name", "bank_account", "bank_holder"};
        for (String key : keys) {
            Fn.saveSetting(key, p(c, key).trim());
        }
        jsonOk(map("message", "Payment settings saved"));
    }

    private void saveSettings(Ctx c) {
        String[] allowed = {"open_time", "close_time", "operating_days", "hold_hours", "cancel_hours"};
        for (String key : allowed) {
            if (c.has(key)) {
                Fn.saveSetting(key, c.post(key).trim());
            }
        }
        jsonOk(map("message", "Settings saved"));
    }

    private void saveActivity(Ctx c) {
        String id = p(c, "activity_id").trim();
        if (!VALID_ACTIVITIES.contains(id)) jsonErr("Invalid activity");

        String name = p(c, "name").trim();
        String unit = p(c, "unit").trim();
        double rate = Fn.toFloat(p(c, "rate"));

        if (Fn.empty(name)) jsonErr("Name is required");
        if (Fn.empty(unit)) jsonErr("Unit is required");
        if (rate <= 0) jsonErr("Rate must be greater than 0");

        Fn.saveSetting("act_" + id + "_name", name);
        Fn.saveSetting("act_" + id + "_unit", unit);
        Fn.saveSetting("act_" + id + "_rate", Fn.phpFloatStr(rate));

        jsonOk(map("message", "Activity updated"));
    }

    // ---------- Alerts ----------

    private void markAlertRead(Ctx c) {
        int id = Fn.toInt(p(c, "alert_id"));
        if (id == 0) jsonErr("Missing alert ID");

        Db.exec("UPDATE alerts SET is_read=1 WHERE id=?", id);

        jsonOk(map("message", "Alert marked as read"));
    }

    private void markAllAlertsRead() {
        Db.exec("UPDATE alerts SET is_read=1 WHERE is_read=0");
        jsonOk(map("message", "All alerts marked as read"));
    }
}
