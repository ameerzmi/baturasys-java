<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.io.File, javax.servlet.http.Part, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

// Support both multi-booking (current_booking_ids) and legacy single (current_booking_id)
List<Integer> bookingIds = new ArrayList<>(c.currentBookingIds());
if (bookingIds.isEmpty() && c.sess("current_booking_id") != null) {
    bookingIds.add((Integer) c.sess("current_booking_id"));
}
if (bookingIds.isEmpty()) { c.redirect(c.BASE + "booking/step1.jsp"); return; }

// Load all bookings
StringBuilder ph = new StringBuilder();
for (int i = 0; i < bookingIds.size(); i++) ph.append(i == 0 ? "?" : ",?");
List<Row> bookings = Db.all("SELECT * FROM bookings WHERE id IN (" + ph + ")", bookingIds.toArray());
if (bookings.isEmpty()) { c.redirect(c.BASE + "booking/step1.jsp"); return; }

double totalAmount = 0;
for (Row b : bookings) totalAmount += b.d("amount");
Row firstBooking = bookings.get(0);
String groupRef = Fn.coalesce(firstBooking.s("group_ref"), firstBooking.s("ref"));

// Must be allowed to see this booking (owner / created or looked up in this session / staff)
if (!c.canViewBooking(firstBooking)) {
    c.sessRemove("current_booking_ids");
    c.sessRemove("current_booking_id");
    c.redirect(c.BASE + "lookup.jsp");
    return;
}

// A receipt can only be (re)submitted while the booking is unpaid or was rejected.
// (Previously a confirmed/checked-in/completed booking could be pushed back to
//  "awaiting verification" and approved again, recording the payment twice.)
List<Row> payable = new ArrayList<>();
for (Row b : bookings) {
    if ("PENDING_PAYMENT".equals(b.s("status")) || "REJECTED".equals(b.s("status"))) payable.add(b);
}
if (payable.isEmpty()) {
    c.setFlash("This booking no longer needs a payment receipt.", "info");
    c.redirect(c.BASE + "booking/status.jsp?id=" + firstBooking.i("id"));
    return;
}

Map<String, String> settings = Fn.getAllSettings();
String qrPath   = Fn.opt(settings, "qr_image_path", "");
String bankName = Fn.opt(settings, "bank_name", "Maybank");
String bankAcct = Fn.opt(settings, "bank_account", "—");
String error = "";

if (c.isPost()) {
    Part file = null;
    try { file = request.getPart("receipt"); } catch (Exception e) { file = null; }
    String fname = file != null ? file.getSubmittedFileName() : null;
    if (file == null || fname == null || fname.isEmpty()) {
        error = "Please choose a receipt image.";
    } else if (!fname.toLowerCase().matches(".*\\.(jpg|jpeg|png)$")) {
        error = "Only JPG, JPEG and PNG image files are allowed.";
    } else if (file.getSize() > Config.MAX_UPLOAD_BYTES) {
        error = "File size exceeds the 5 MB limit. Please upload a smaller image.";
    } else {
      synchronized (Fn.BOOKING_LOCK) {
        // Rejected bookings gave their watercraft back - make sure it's still free
        List<Integer> payableIds = new ArrayList<>();
        for (Row b : payable) payableIds.add(b.i("id"));
        List<CartItem> checked = new ArrayList<>();
        for (Row b : payable) {
            if (!"REJECTED".equals(b.s("status"))) continue;
            // legacy slots outside the bookable list aren't tracked by availability
            if (!Fn.slots().contains(b.s("slot")) && !Fn.PICKUP_TIMES.contains(b.s("slot"))) continue;
            CartItem it = new CartItem();
            it.activityId = b.s("activity_id"); it.slot = b.s("slot"); it.hours = b.i("hours");
            it.count = 1; it.date = b.s("booking_date"); it.rentalType = b.s("rental_type");
            String err = Fn.checkItem(it, Fn.availability(it.date, checked, payableIds), 24);
            if (err != null) { error = err + " Please make a new booking."; break; }
            checked.add(it);
        }
        if (error.isEmpty()) {
        String ext = fname.substring(fname.lastIndexOf('.') + 1).toLowerCase();
        File dir = new File(Config.UPLOAD_DIR + "receipts/");
        if (!dir.isDirectory()) dir.mkdirs();
        String destName = "receipt_" + firstBooking.i("id") + "_" + (System.currentTimeMillis() / 1000L) + "." + ext;
        try (java.io.InputStream in = file.getInputStream()) {
            java.nio.file.Files.copy(in, new File(dir, destName).toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
        String relPath = "receipts/" + destName;

        for (Integer bid : payableIds) {
            Db.exec("UPDATE bookings SET status='AWAITING_VERIFICATION', receipt_path=? WHERE id=? AND status IN ('PENDING_PAYMENT','REJECTED')", relPath, bid);
        }

        c.setFlash("Receipt submitted — staff will verify shortly.", "ok");
        c.redirect(c.BASE + "booking/status.jsp?id=" + firstBooking.i("id") + "&new=1");
        return;
        }
      }
    }
}
%><%= c.pageHead("Book · Pay") %><%= c.customerNav() %>

<div class="bsy-screen" style="max-width:1000px;margin:0 auto;padding:34px 24px 80px">
  <div class="step-bar">
    <span class="done" style="cursor:default">1 · Build ✓</span>
    <span style="color:var(--faint)">→</span>
    <span class="done" style="cursor:default">2 · Details ✓</span>
    <span style="color:var(--faint)">→</span>
    <span class="cur">3 · Pay</span>
  </div>

  <h2 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:8px">Complete your payment</h2>
  <p class="text-muted" style="font-size:14.5px;margin:0 0 24px">
    Scan the DuitNow QR below, transfer exactly <b><%= Fn.h(Fn.fmt(totalAmount)) %></b>, then upload your transfer receipt.
    <% if (bookings.size() > 1) { %>
    One receipt covers all <%= bookings.size() %> bookings.
    <% } %>
  </p>

  <div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;align-items:start">

    <!-- QR Panel -->
    <div class="card card-p" style="text-align:center">
      <div class="fw-800 fs-14 mb-14">DuitNow QR</div>
      <% if (!Fn.empty(qrPath) && new File(Config.UPLOAD_DIR + qrPath).exists()) { %>
        <img src="<%= c.BASE + "uploads/" + Fn.h(qrPath) %>" alt="DuitNow QR"
             style="width:180px;height:180px;object-fit:contain;border-radius:12px;border:1px solid var(--border);background:#fff;margin:0 auto;display:block">
      <% } else { %>
        <div style="width:180px;height:180px;margin:0 auto;border-radius:12px;background:repeating-conic-gradient(#0f262c 0% 25%,#fff 0% 50%) 50%/14px 14px;border:5px solid #0f262c;position:relative">
          <div style="position:absolute;inset:38%;background:#fff;border-radius:5px;display:flex;align-items:center;justify-content:center;font-size:14px">≈</div>
        </div>
      <% } %>
      <div class="mt-14 fs-13">
        <div class="text-muted">Bank: <b><%= Fn.h(bankName) %></b></div>
        <div class="text-muted mt-4">Account: <b class="mono"><%= Fn.h(bankAcct) %></b></div>
      </div>
      <div style="margin-top:14px;background:var(--warn-bg);color:var(--warn);border-radius:10px;padding:10px 12px;font-size:12.5px;font-weight:700">
        Transfer exactly <b><%= Fn.h(Fn.fmt(totalAmount)) %></b> and include your name as reference.
      </div>
    </div>

    <!-- Upload Panel -->
    <div class="card card-p">
      <div class="fw-800 fs-14 mb-14">Upload receipt</div>
      <form method="POST" enctype="multipart/form-data">
        <label class="receipt-drop bsy-tap" id="receipt-drop" style="border-color:var(--border);background:var(--surface-2);display:block">
          <input type="file" name="receipt" id="receipt-file" accept="image/jpeg,image/png" style="display:none">
          <img id="receipt-file-preview" style="display:none;max-width:100%;max-height:180px;border-radius:8px;margin-bottom:10px;object-fit:contain">
          <div style="font-size:32px;margin-bottom:10px" id="receipt-icon">⬆️</div>
          <div class="fw-800 fs-14 mb-6" id="receipt-label">Tap to choose a receipt image</div>
          <div class="fs-12 text-muted">JPG or PNG · max 5 MB</div>
        </label>
        <% if (!error.isEmpty()) { %>
          <div class="error-box mt-14"><%= Fn.h(error) %></div>
        <% } %>
        <div id="receipt-error" class="error-box mt-14" style="display:none"></div>
        <button type="submit" id="receipt-submit" class="btn btn-brand w-full mt-18" style="opacity:.5">Submit receipt</button>
      </form>

      <div style="margin-top:22px;border-top:1px solid var(--border-2);padding-top:16px">
        <div class="fw-800 fs-14 mb-4">Your booking</div>
        <div class="fs-12 text-muted mono mb-12"><%= Fn.h(groupRef) %></div>
        <% for (Row b : bookings) {
          Activity m = Fn.activityMeta(b.s("activity_id"));
        %>
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px">
          <span style="font-size:18px;flex:none"><%= m.emoji %></span>
          <div style="flex:1;min-width:0">
            <div class="fs-13 fw-800"><%= Fn.h(m.name) %></div>
            <div class="fs-12 text-muted"><%= Fn.h(Fn.bookingSlotLabel(b.s("slot"), b.i("hours"), b.s("rental_type"))) %></div>
          </div>
          <div class="fw-800 fs-13" style="color:var(--brand);white-space:nowrap;flex:none"><%= Fn.h(Fn.fmt(b.d("amount"))) %></div>
        </div>
        <% } %>
        <div style="border-top:1px solid var(--border-2);margin-top:6px;padding-top:10px;display:flex;justify-content:space-between" class="fw-800 fs-14">
          <span>Total</span>
          <span style="color:var(--brand)"><%= Fn.h(Fn.fmt(totalAmount)) %></span>
        </div>
      </div>
    </div>
  </div>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
