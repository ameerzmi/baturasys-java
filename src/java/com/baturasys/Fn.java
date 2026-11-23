package com.baturasys;

import java.io.UnsupportedEncodingException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.sql.Timestamp;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;

/**
 * Shared helper functions — Java version of includes/functions.php.
 */
public final class Fn {

    private Fn() { }

    // ------------------------------------------------------------ formatting

    /** PHP number_format($n, $decimals) */
    public static String numberFormat(double n, int decimals) {
        StringBuilder pattern = new StringBuilder("#,##0");
        if (decimals > 0) {
            pattern.append('.');
            for (int i = 0; i < decimals; i++) pattern.append('0');
        }
        DecimalFormat df = new DecimalFormat(pattern.toString(), DecimalFormatSymbols.getInstance(Locale.ENGLISH));
        df.setRoundingMode(RoundingMode.HALF_UP);
        return df.format(new BigDecimal(Double.toString(n)));
    }

    /** fmt(): 12.5 -> "RM12.50" */
    public static String fmt(double n) {
        return "RM" + numberFormat(n, 2);
    }

    /** Signed money label used on transaction lists: -RM45.00 / RM10.00 */
    public static String signedMoney(double amt) {
        return amt < 0 ? "-RM" + numberFormat(Math.abs(amt), 2) : "RM" + numberFormat(amt, 2);
    }

    /** dateLabel(): "2026-06-18" -> "Thu, 18 Jun 2026" */
    public static String dateLabel(String d) {
        if (empty(d)) return "—";
        try {
            LocalDate dt = LocalDate.parse(d.length() >= 10 ? d.substring(0, 10) : d);
            return dt.format(DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH));
        } catch (Exception e) {
            return d;
        }
    }

    /** date('j F Y') for today */
    public static String todayLong() {
        return LocalDate.now().format(DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.ENGLISH));
    }

    /** date('Y-m-d') */
    public static String today() {
        return LocalDate.now().toString();
    }

    /** date('H:i', strtotime($dt)) */
    public static String timeHM(Timestamp ts) {
        if (ts == null) return "";
        return new java.text.SimpleDateFormat("HH:mm").format(ts);
    }

    /** fmtHour(): "09:00" -> "9am", "17:30" -> "5:30pm" */
    public static String fmtHour(String t) {
        if (empty(t)) return "";
        String[] p = t.split(":");
        int h = toInt(p[0]);
        int m = p.length > 1 ? toInt(p[1]) : 0;
        String ap = h < 12 ? "am" : "pm";
        int hh = h % 12 == 0 ? 12 : h % 12;
        return m != 0 ? hh + ":" + pad2(m) + ap : hh + ap;
    }

    public static String pad2(int n) {
        return n < 10 ? "0" + n : String.valueOf(n);
    }

    /** str_pad($n, $len, '0', STR_PAD_LEFT) */
    public static String padLeft(long n, int len) {
        String s = String.valueOf(n);
        StringBuilder sb = new StringBuilder();
        for (int i = s.length(); i < len; i++) sb.append('0');
        return sb.append(s).toString();
    }

    /** htmlspecialchars($s, ENT_QUOTES, 'UTF-8') */
    public static String h(Object o) {
        if (o == null) return "";
        String s = o.toString();
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&':  sb.append("&amp;"); break;
                case '<':  sb.append("&lt;"); break;
                case '>':  sb.append("&gt;"); break;
                case '"':  sb.append("&quot;"); break;
                case '\'': sb.append("&#039;"); break;
                default:   sb.append(c);
            }
        }
        return sb.toString();
    }

    /**
     * Escapes a value for use inside a single- or double-quoted JavaScript string.
     * Quotes, backslashes, &lt; &gt; &amp;, control characters and U+2028/2029 become
     * \\uXXXX escapes, so the value can never end the string or the script.
     */
    public static String js(Object o) {
        if (o == null) return "";
        String s = o.toString();
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\'' || c == '"' || c == '\\' || c == '<' || c == '>' || c == '&' || c == '`'
                    || c < 0x20 || c == 0x2028 || c == 0x2029) {
                sb.append(String.format("\\u%04x", (int) c));
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    /** For JavaScript strings inside an HTML attribute (onclick="f('...')"): JS-escape, then HTML-escape. */
    public static String jsAttr(Object o) {
        return h(js(o));
    }

    /** urlencode() */
    public static String urlencode(String s) {
        try {
            return URLEncoder.encode(s == null ? "" : s, "UTF-8");
        } catch (UnsupportedEncodingException e) {
            return s;
        }
    }

    /** ucfirst() */
    public static String ucfirst(String s) {
        if (s == null || s.isEmpty()) return "";
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    public static String substr(String s, int start, int len) {
        if (s == null || start >= s.length()) return "";
        return s.substring(start, Math.min(s.length(), start + len));
    }

    /** $a ?? $b */
    public static String coalesce(String a, String b) {
        return a != null ? a : b;
    }

    /** First word of a name (explode(' ', $name)[0]) */
    public static String firstName(String name) {
        if (name == null) return "";
        int i = name.indexOf(' ');
        return i < 0 ? name : name.substring(0, i);
    }

    /** Initials of the first two words, upper-cased. */
    public static String initials(String name) {
        if (name == null || name.isEmpty()) return "";
        String[] words = name.split(" ", -1);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Math.min(2, words.length); i++) {
            if (!words[i].isEmpty()) sb.append(words[i].charAt(0));
        }
        return sb.toString().toUpperCase();
    }

    // ------------------------------------------------------------ PHP-style casts

    /** PHP empty()/falsy for strings: null, "" and "0" are false. */
    public static boolean empty(String s) {
        return s == null || s.isEmpty() || s.equals("0");
    }

    /** trim() that also accepts null */
    public static String trim(String s) {
        return s == null ? "" : s.trim();
    }

    /** (int) "12abc" -> 12, "" -> 0 */
    public static int toInt(String s) {
        if (s == null) return 0;
        s = s.trim();
        int i = 0, n = s.length();
        boolean neg = false;
        if (i < n && (s.charAt(i) == '-' || s.charAt(i) == '+')) { neg = s.charAt(i) == '-'; i++; }
        long v = 0;
        int start = i;
        while (i < n && Character.isDigit(s.charAt(i))) {
            v = v * 10 + (s.charAt(i) - '0');
            if (v > Integer.MAX_VALUE) { v = Integer.MAX_VALUE; break; }
            i++;
        }
        if (i == start) {
            // "1.9" style handled by float path; plain garbage -> 0
            return (int) toFloat(s);
        }
        return (int) (neg ? -v : v);
    }

    /** (float) "12.5abc" -> 12.5 */
    public static double toFloat(String s) {
        if (s == null) return 0;
        s = s.trim();
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("^[+-]?(\\d+(\\.\\d*)?|\\.\\d+)([eE][+-]?\\d+)?").matcher(s);
        if (m.find()) {
            try { return Double.parseDouble(m.group()); } catch (NumberFormatException e) { return 0; }
        }
        return 0;
    }

    /** ctype_digit() */
    public static boolean ctypeDigit(String s) {
        if (s == null || s.isEmpty()) return false;
        for (int i = 0; i < s.length(); i++) if (s.charAt(i) < '0' || s.charAt(i) > '9') return false;
        return true;
    }

    /** max(min()) clamp */
    public static int clamp(int v, int lo, int hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    // ------------------------------------------------------------ settings

    private static final ThreadLocal<Map<String, String>> SETTINGS_CACHE = new ThreadLocal<>();

    /** Clears the per-request settings cache (called by AppFilter). */
    static void resetRequestCache() {
        SETTINGS_CACHE.remove();
    }

    public static String getSetting(String key, String def) {
        Map<String, String> cache = SETTINGS_CACHE.get();
        if (cache == null) {
            cache = getAllSettings();
            SETTINGS_CACHE.set(cache);
        }
        String v = cache.get(key);
        return v != null ? v : def;
    }

    public static Map<String, String> getAllSettings() {
        Map<String, String> map = new LinkedHashMap<>();
        for (Row r : Db.all("SELECT setting_key, setting_value FROM settings")) {
            map.put(r.s("setting_key"), r.s("setting_value"));
        }
        return map;
    }

    /** $settings['key'] ?? 'default' */
    public static String opt(Map<String, String> m, String key, String def) {
        String v = m.get(key);
        return v != null ? v : def;
    }

    /** Insert-or-update a setting (MySQL "ON DUPLICATE KEY UPDATE" equivalent for Java DB). */
    public static void saveSetting(String key, String value) {
        if (Db.exec("UPDATE settings SET setting_value=? WHERE setting_key=?", value, key) == 0) {
            Db.exec("INSERT INTO settings (setting_key,setting_value) VALUES (?,?)", key, value);
        }
    }

    // ------------------------------------------------------------ login lockout (5 failed attempts -> 15 min lock)

    public static final int LOGIN_MAX_ATTEMPTS = 5;
    public static final int LOGIN_LOCK_MINUTES = 15;

    public static String checkLoginLockout(String identifier, String role) {
        identifier = trim(identifier).toLowerCase();
        Row row = Db.one("SELECT locked_until FROM login_attempts WHERE identifier=? AND role=?", identifier, role);
        long now = System.currentTimeMillis();
        if (row != null && row.ts("locked_until") != null && row.ts("locked_until").getTime() > now) {
            int mins = (int) Math.ceil((row.ts("locked_until").getTime() - now) / 60000.0);
            return "Too many failed attempts. Try again in " + mins + " minute" + (mins == 1 ? "" : "s") + ".";
        }
        return null;
    }

    public static void recordFailedLogin(String identifier, String role) {
        identifier = trim(identifier).toLowerCase();
        Row row = Db.one("SELECT id, fail_count, locked_until FROM login_attempts WHERE identifier=? AND role=?", identifier, role);
        long now = System.currentTimeMillis();

        // Already locked — don't extend the window on further attempts.
        if (row != null && row.ts("locked_until") != null && row.ts("locked_until").getTime() > now) return;

        if (row != null) {
            int newCount = row.i("fail_count") + 1;
            Timestamp lockedUntil = newCount >= LOGIN_MAX_ATTEMPTS
                    ? new Timestamp(now + LOGIN_LOCK_MINUTES * 60L * 1000L) : null;
            Db.exec("UPDATE login_attempts SET fail_count=?, locked_until=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
                    newCount, lockedUntil, row.i("id"));
        } else {
            Db.exec("INSERT INTO login_attempts (identifier, role, fail_count) VALUES (?,?,1)", identifier, role);
        }
    }

    public static void resetLoginAttempts(String identifier, String role) {
        identifier = trim(identifier).toLowerCase();
        Db.exec("DELETE FROM login_attempts WHERE identifier=? AND role=?", identifier, role);
    }

    // ------------------------------------------------------------ activities

    public static final List<String> ACTIVITY_IDS = Collections.unmodifiableList(
            Arrays.asList("kayak", "kayak2", "canoe", "paddle", "cruise"));

    private static final Map<String, Activity> ACTIVITY_MAP = new LinkedHashMap<>();
    static {
        ACTIVITY_MAP.put("kayak",  new Activity("kayak",  "Kayaking",          "🛶", "linear-gradient(135deg,#7fd0d9,#3fa6b3)", "Single kayak — glide solo across the lake.", 10.00, "/hour",   60.00, "/day"));
        ACTIVITY_MAP.put("kayak2", new Activity("kayak2", "Kayaking (Double)", "🛶", "linear-gradient(135deg,#86d6c2,#3fae93)", "Double kayak — paddle with a partner.",      15.00, "/hour",   90.00, "/day"));
        ACTIVITY_MAP.put("canoe",  new Activity("canoe",  "Canoeing",          "🚣", "linear-gradient(135deg,#8fc7e8,#4f93c4)", "Stable canoe for groups & families.",        12.00, "/hour",   70.00, "/day"));
        ACTIVITY_MAP.put("paddle", new Activity("paddle", "Paddle Boat",       "⛵", "linear-gradient(135deg,#9ad0a6,#56a86d)", "Pedal-powered fun, no experience needed.",   15.00, "/hour",   90.00, "/day"));
        ACTIVITY_MAP.put("cruise", new Activity("cruise", "Cruise Boat",       "🚤", "linear-gradient(135deg,#f0c98a,#d79a4e)", "Relaxing guided ride around the lake.",      6.00,  "/person", 50.00, "/day"));
    }

    public static Activity activityMeta(String id) {
        Activity base = ACTIVITY_MAP.get(id);
        if (base == null) base = ACTIVITY_MAP.get("kayak");
        Activity meta = base.copy();
        // Manager-editable overrides (System settings -> Activity rates)
        meta.name = getSetting("act_" + id + "_name", meta.name);
        meta.unit = getSetting("act_" + id + "_unit", meta.unit);
        meta.rate = toFloat(getSetting("act_" + id + "_rate", phpFloatStr(meta.rate)));
        return meta;
    }

    /** (string)$float the way PHP prints it: 10.0 -> "10", 12.5 -> "12.5" */
    public static String phpFloatStr(double d) {
        if (d == Math.rint(d) && Math.abs(d) < 1e15) return String.valueOf((long) d);
        return BigDecimal.valueOf(d).stripTrailingZeros().toPlainString();
    }

    public static String bookingSlotLabel(String slot, int hours, String rentalType) {
        if ("Off-site".equals(rentalType)) {
            String[] parts = (slot == null ? "" : slot).split(":");
            int h = parts.length > 0 && !parts[0].isEmpty() ? toInt(parts[0]) : 9;
            String ap = h < 12 ? "AM" : "PM";
            int hh = h % 12 == 0 ? 12 : h % 12;
            return "Pickup " + hh + ":00 " + ap + " · " + hours + " day" + (hours > 1 ? "s" : "");
        }
        return slotDisplay(slot, hours);
    }

    /** [label, background, foreground] */
    public static String[] statusBadge(String s) {
        if (s == null) s = "";
        switch (s) {
            case "PENDING_PAYMENT":       return new String[]{"Pending payment", "var(--warn-bg)", "var(--warn)"};
            case "AWAITING_VERIFICATION": return new String[]{"Awaiting verification", "var(--info-bg)", "var(--info)"};
            case "CONFIRMED":             return new String[]{"Confirmed", "var(--ok-bg)", "var(--ok)"};
            case "REJECTED":              return new String[]{"Rejected", "var(--danger-bg)", "var(--danger)"};
            case "CHECKED_IN":            return new String[]{"Checked in", "var(--brand-tint)", "var(--brand-dark)"};
            case "COMPLETED":             return new String[]{"Completed", "#e9edee", "#566469"};
            case "CANCELLED":             return new String[]{"Cancelled", "#efeae8", "#8a7a76"};
            default:                      return new String[]{s, "#eee", "#555"};
        }
    }

    /** [background, foreground] */
    public static String[] condBadge(String c) {
        if (c == null) c = "";
        switch (c) {
            case "Good":    return new String[]{"var(--ok-bg)", "var(--ok)"};
            case "Worn":    return new String[]{"var(--warn-bg)", "var(--warn)"};
            case "Damaged":
            case "Missing": return new String[]{"var(--danger-bg)", "var(--danger)"};
            default:        return new String[]{"#eee", "#555"};
        }
    }

    public static String generateRef(String date) {
        String d = date.replace("-", "");
        int total = Db.scalarInt("SELECT COUNT(*) FROM bookings") + 1;
        return "BSY-" + d + "-" + padLeft(total, 4);
    }

    public static String slotDisplay(String startSlot, int hours) {
        if (startSlot == null) return "";
        if (hours <= 1) return startSlot;
        String[] parts = startSlot.split("–", -1);
        if (parts.length < 2) return startSlot;
        String start = parts[0];
        String[] timeParts = start.split(":", -1);
        if (timeParts.length < 2) return startSlot;
        String endH = padLeft(toInt(timeParts[0]) + hours, 2);
        return start + "–" + endH + ":" + timeParts[1];
    }

    public static List<String> slots() {
        return Arrays.asList("09:00–10:00", "10:00–11:00", "11:00–12:00", "12:00–13:00",
                "13:00–14:00", "14:00–15:00", "15:00–16:00", "16:00–17:00");
    }

    public static boolean isSlotBooked(String watercraftId, String date, String slot) {
        return Db.scalarInt("SELECT COUNT(*) FROM bookings WHERE watercraft_id=? AND booking_date=? AND slot=? AND status NOT IN ('CANCELLED','REJECTED')",
                watercraftId, date, slot) > 0;
    }

    public static void addAlert(String kind, String severity, String message) {
        Db.exec("INSERT INTO alerts (kind,severity,message,alert_date) VALUES (?,?,?,CURRENT_DATE)", kind, severity, message);
    }

    /**
     * Cancels PENDING_PAYMENT bookings (grouped by group_ref) that have sat
     * longer than the configured holding window with no receipt uploaded.
     */
    public static void checkExpiredPendingPayments() {
        // Uses the "Payment hold (hours)" value saved on System settings ('hold_hours').
        // (Fixed: the PHP version only read 'holding_hours', so the setting had no effect.)
        double holdingHours = toFloat(getSetting("hold_hours", getSetting("holding_hours", "24")));
        if (holdingHours <= 0) holdingHours = 24;
        Timestamp cutoff = new Timestamp(System.currentTimeMillis() - (long) (holdingHours * 3600_000L));
        // Group by COALESCE(group_ref, ref) in Java
        Map<String, Integer> groups = new LinkedHashMap<>();
        for (Row r : Db.all("SELECT group_ref, ref FROM bookings WHERE status='PENDING_PAYMENT' AND created_at < ? ORDER BY id", cutoff)) {
            String grp = r.s("group_ref") != null ? r.s("group_ref") : r.s("ref");
            groups.put(grp, groups.getOrDefault(grp, 0) + 1);
        }
        for (Map.Entry<String, Integer> g : groups.entrySet()) {
            Db.exec("UPDATE bookings SET status='CANCELLED', updated_at=CURRENT_TIMESTAMP WHERE (group_ref=? OR (group_ref IS NULL AND ref=?)) AND status='PENDING_PAYMENT'",
                    g.getKey(), g.getKey());
            String hrs = numberFormat(holdingHours, 1);
            hrs = rtrim(rtrim(hrs, '0'), '.');
            addAlert("Cancellation", "low", "Booking " + g.getKey() + " auto-cancelled — no payment received within "
                    + hrs + " hour(s) (" + g.getValue() + " item(s)).");
        }
    }

    private static String rtrim(String s, char c) {
        int end = s.length();
        while (end > 0 && s.charAt(end - 1) == c) end--;
        return s.substring(0, end);
    }

    /**
     * Flags any SCHEDULED task whose date has passed as OVERDUE and raises one
     * alert per task (idempotent).
     */
    public static void checkOverdueMaintenance() {
        List<Row> due = Db.all("SELECT * FROM maintenance_tasks WHERE status='SCHEDULED' AND scheduled_date < CURRENT_DATE");
        for (Row t : due) {
            Db.exec("UPDATE maintenance_tasks SET status='OVERDUE', updated_at=CURRENT_TIMESTAMP WHERE id=?", t.i("id"));
            addAlert("Overdue Maintenance", "high", t.s("type") + " for " + t.s("watercraft_id")
                    + " is overdue (was due " + dateLabel(t.s("scheduled_date")) + ").");
        }
    }

    /**
     * Staged advance reminders as equipment approaches its replacement_due date —
     * fires once at each of the 90/60/30-day thresholds (and once when overdue).
     */
    public static void checkReplacementReminders() {
        List<Row> items = Db.all("SELECT * FROM equipment WHERE replacement_due IS NOT NULL AND status <> 'Retired'");
        LocalDate today = LocalDate.now();
        for (Row eq : items) {
            LocalDate due;
            try { due = LocalDate.parse(eq.s("replacement_due")); } catch (Exception e) { continue; }
            long daysLeft = ChronoUnit.DAYS.between(today, due);

            String marker, message, severity;
            if (daysLeft < 0) {
                marker = "(" + eq.s("equipment_id") + ") replacement is overdue";
                message = eq.s("type") + " " + marker + " — was due " + dateLabel(eq.s("replacement_due")) + ".";
                severity = "high";
            } else {
                Integer threshold = null;
                for (int t : new int[]{30, 60, 90}) { if (daysLeft <= t) { threshold = t; break; } }
                if (threshold == null) continue;
                marker = "(" + eq.s("equipment_id") + ") is within " + threshold + " days";
                message = eq.s("type") + " " + marker + " of its replacement due date (" + dateLabel(eq.s("replacement_due")) + ").";
                severity = threshold <= 30 ? "high" : (threshold <= 60 ? "medium" : "low");
            }

            if (Db.scalarInt("SELECT COUNT(*) FROM alerts WHERE message LIKE ?", "%" + marker + "%") > 0) continue;
            addAlert("Replacement", severity, message);
        }
    }

    public static void addTransaction(String ref, String date, double amount, String method, String type) {
        Db.exec("INSERT INTO transactions (ref,transaction_date,amount,method,type) VALUES (?,?,?,?,?)",
                ref, date, amount, method, type);
    }

    public static String nextStaffId() {
        int n = Db.scalarInt("SELECT COUNT(*) FROM staff") + 1;
        return "BS-" + padLeft(n, 4);
    }

    public static String nextEquipId() {
        // Highest numeric part of IDs like "EQ-123"
        int max = 0;
        for (Row r : Db.all("SELECT equipment_id FROM equipment WHERE equipment_id LIKE 'EQ-%'")) {
            String rest = r.str("equipment_id").substring(3);
            if (!rest.isEmpty() && Character.isDigit(rest.charAt(0))) max = Math.max(max, toInt(rest));
        }
        return "EQ-" + padLeft(max + 1, 3);
    }

    public static String nextTaskId() {
        int n = Db.scalarInt("SELECT COUNT(*) FROM maintenance_tasks") + 1;
        return "M" + padLeft(n, 3);
    }

    /** Equipment IDs currently checked out in active (CHECKED_IN) bookings. */
    public static Set<String> takenEquipmentIds() {
        Set<String> taken = new HashSet<>();
        for (Row r : Db.all("SELECT equipment_assigned FROM bookings WHERE status='CHECKED_IN' AND equipment_assigned IS NOT NULL")) {
            for (String part : r.str("equipment_assigned").split(",")) {
                String id = part.trim().split(" ")[0];
                if (!empty(id)) taken.add(id);
            }
        }
        return taken;
    }

    /**
     * Groups booking rows (ordered by id) by COALESCE(group_ref, ref), giving the
     * same columns the MySQL "GROUP BY ... GROUP_CONCAT" queries produced:
     * gref, first_id, activity_id, activity_ids, booking_date, slot, amount,
     * total_amount, status, item_count, created_at, customer_name,
     * customer_phone, receipt_path  (MIN/SUM/COUNT semantics).
     */
    public static List<Row> groupBookings(List<Row> rows) {
        Map<String, Row> groups = new LinkedHashMap<>();
        Map<String, List<String>> acts = new HashMap<>();
        String[] minCols = {"activity_id", "booking_date", "slot", "status", "created_at",
                            "customer_name", "customer_phone", "receipt_path"};
        for (Row b : rows) {
            String gref = b.s("group_ref") != null ? b.s("group_ref") : b.s("ref");
            Row g = groups.get(gref);
            if (g == null) {
                g = new Row();
                g.put("gref", gref);
                g.put("first_id", b.i("id"));
                g.put("item_count", 0);
                g.put("amount", 0.0);
                groups.put(gref, g);
                acts.put(gref, new ArrayList<String>());
            }
            g.put("first_id", Math.min(g.i("first_id"), b.i("id")));
            g.put("item_count", g.i("item_count") + 1);
            g.put("amount", g.d("amount") + b.d("amount"));
            g.put("total_amount", g.d("amount"));
            acts.get(gref).add(b.str("activity_id"));
            for (String col : minCols) {
                String v = b.s(col);
                if (v == null) continue;
                String cur = g.s(col);
                if (cur == null || v.compareToIgnoreCase(cur) < 0) g.put(col, v);
            }
        }
        for (Map.Entry<String, Row> e : groups.entrySet()) {
            e.getValue().put("activity_ids", String.join(",", acts.get(e.getKey())));
        }
        return new ArrayList<>(groups.values());
    }

    /** Sorts grouped rows by their (earliest) created_at. */
    public static void sortByCreated(List<Row> rows, final boolean desc) {
        Collections.sort(rows, new Comparator<Row>() {
            @Override
            public int compare(Row a, Row b) {
                int r = a.str("created_at").compareTo(b.str("created_at"));
                return desc ? -r : r;
            }
        });
    }

    // ------------------------------------------------------------ availability (server-side)

    /** Off-site pickup times offered on the booking page. */
    public static final List<String> PICKUP_TIMES = Collections.unmodifiableList(Arrays.asList(
            "08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"));

    /** Serialises "check availability + insert bookings" so two requests can't take the same last unit. */
    public static final Object BOOKING_LOCK = new Object();

    /** Statuses that hold a watercraft (unpaid bookings hold it until auto-cancelled). */
    private static final String HOLDING_STATUSES =
            "('PENDING_PAYMENT','AWAITING_VERIFICATION','CONFIRMED','CHECKED_IN')";

    /** Free units per activity: on-site per slot, and off-site for the whole day. */
    public static class Availability {
        public final Map<String, Map<String, Integer>> onsite = new LinkedHashMap<>();
        public final Map<String, Integer> offsite = new LinkedHashMap<>();

        public int onsiteFor(String act, String slot, int hours) {
            List<String> all = slots();
            int start = all.indexOf(slot);
            if (start < 0 || !onsite.containsKey(act)) return 0;
            int min = Integer.MAX_VALUE;
            for (int i = 0; i < Math.max(1, hours); i++) {
                if (start + i >= all.size()) return 0;
                min = Math.min(min, onsite.get(act).getOrDefault(all.get(start + i), 0));
            }
            return min == Integer.MAX_VALUE ? 0 : min;
        }
    }

    /**
     * Availability on a date = fleet size minus bookings that hold a unit, minus
     * the given extra cart items. Bookings whose id is in excludeIds are ignored
     * (used when re-checking bookings that are being re-submitted).
     */
    public static Availability availability(String date, List<CartItem> extra, Collection<Integer> excludeIds) {
        List<String> allSlots = slots();
        Map<String, Map<String, Integer>> onOcc = new HashMap<>();
        Map<String, Integer> offOcc = new HashMap<>();

        for (Row bk : Db.all("SELECT id, activity_id, slot, hours, rental_type FROM bookings WHERE booking_date = ? AND status IN " + HOLDING_STATUSES, date)) {
            if (excludeIds != null && excludeIds.contains(bk.i("id"))) continue;
            occupy(onOcc, offOcc, allSlots, bk.s("activity_id"), bk.s("rental_type"), bk.s("slot"), bk.i("hours"), 1);
        }
        if (extra != null) {
            for (CartItem it : extra) {
                if (date.equals(it.date)) occupy(onOcc, offOcc, allSlots, it.activityId, it.rentalType, it.slot, it.hours, it.count);
            }
        }

        Availability a = new Availability();
        for (String act : ACTIVITY_IDS) {
            int total = Db.scalarInt("SELECT COUNT(*) FROM watercraft WHERE activity_id=? AND status NOT IN ('RETIRED','UNDER_MAINTENANCE')", act);
            Map<String, Integer> occ = onOcc.containsKey(act) ? onOcc.get(act) : new HashMap<String, Integer>();
            Map<String, Integer> m = new LinkedHashMap<>();
            for (String s : allSlots) m.put(s, Math.max(0, total - occ.getOrDefault(s, 0)));
            a.onsite.put(act, m);
            a.offsite.put(act, Math.max(0, total - offOcc.getOrDefault(act, 0)));
        }
        return a;
    }

    private static void occupy(Map<String, Map<String, Integer>> onOcc, Map<String, Integer> offOcc, List<String> allSlots,
                               String act, String rentalType, String slot, int hours, int count) {
        if ("Off-site".equals(rentalType)) {
            offOcc.put(act, offOcc.getOrDefault(act, 0) + count);
            return;
        }
        int start = allSlots.indexOf(slot);
        if (start < 0) return;
        Map<String, Integer> m = onOcc.get(act);
        if (m == null) { m = new HashMap<>(); onOcc.put(act, m); }
        for (int i = 0; i < Math.max(1, hours) && start + i < allSlots.size(); i++) {
            String s = allSlots.get(start + i);
            m.put(s, m.getOrDefault(s, 0) + count);
        }
    }

    /**
     * Validates one requested cart line and checks it still fits.
     * Returns an error message, or null when it can be booked.
     */
    public static String checkItem(CartItem it, Availability a, int closeHour) {
        if (!ACTIVITY_IDS.contains(it.activityId)) return "Please choose a valid activity.";
        if (it.count < 1) return "Please choose at least one watercraft.";
        if ("Off-site".equals(it.rentalType)) {
            if (!PICKUP_TIMES.contains(it.slot)) return "Please choose a valid pickup time.";
            if (it.hours < 1 || it.hours > 7) return "Off-site rentals are 1 to 7 days.";
            int free = a.offsite.getOrDefault(it.activityId, 0);
            if (it.count > free) return notEnough(free);
        } else {
            if (!slots().contains(it.slot)) return "Please choose a valid time slot.";
            int startHour = toInt(it.slot.split(":")[0]);
            if (it.hours < 1 || startHour + it.hours > closeHour) return "That booking would run past closing time.";
            int free = a.onsiteFor(it.activityId, it.slot, it.hours);
            if (it.count > free) return notEnough(free);
        }
        return null;
    }

    private static String notEnough(int free) {
        return free <= 0 ? "Sorry, that time is fully booked. Please choose another slot."
                         : "Sorry, only " + free + " watercraft " + (free == 1 ? "is" : "are") + " still available for that time.";
    }

    /** Booking date must be a real date, today or later. */
    public static boolean validBookingDate(String date) {
        try {
            return !LocalDate.parse(date).isBefore(LocalDate.now());
        } catch (Exception e) {
            return false;
        }
    }

    /** Closing hour from settings (falls back to 18 if the setting is invalid). */
    public static int closeHour() {
        String ct = getSetting("close_time", "18:00");
        int h = toInt(ct.split(":")[0]);
        return (h >= 1 && h <= 24) ? h : 18;
    }

    /** array_count_values(explode(',', $s)) preserving first-seen order */
    public static Map<String, Integer> countValues(String csv) {
        Map<String, Integer> m = new LinkedHashMap<>();
        if (csv == null) return m;
        for (String p : csv.split(",", -1)) m.put(p, m.getOrDefault(p, 0) + 1);
        return m;
    }
}
