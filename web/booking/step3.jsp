<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

List<CartItem> cart = c.cart();
if (cart.isEmpty()) { c.redirect(c.BASE + "booking/step1.jsp"); return; }

Row customer = c.currentCustomer();
String error = "";

// Totals
double cartTotal = 0;
int cartUnits = 0;
for (CartItem item : cart) {
    cartTotal += item.rate * item.hours * item.count;
    cartUnits += item.count;
}

if (c.isPost()) {
    String name  = c.postTrim("name");
    String phone = c.postTrim("phone");
    if (Fn.empty(name) || Fn.empty(phone)) {
        error = "Please enter a valid name and phone number.";
    } else {
        Integer custId = customer != null ? customer.i("id") : null;
        List<Integer> bookingIds = new ArrayList<>();
        String groupRef = null;

        synchronized (Fn.BOOKING_LOCK) {
            // Re-check the whole cart against live availability right before booking
            // (the browser's check can be bypassed, and others may have booked meanwhile).
            int closeHour = Fn.closeHour();
            List<CartItem> checked = new ArrayList<>();
            for (CartItem item : cart) {
                String err = !Fn.validBookingDate(item.date) ? "That booking date is no longer available."
                           : Fn.checkItem(item, Fn.availability(item.date, checked, null), closeHour);
                if (err != null) { error = err + " Please update your booking."; break; }
                checked.add(item);
            }

            if (error.isEmpty()) {
                for (CartItem item : cart) {
                    for (int i = 0; i < item.count; i++) {
                        String ref = Fn.generateRef(item.date);
                        if (groupRef == null) groupRef = ref;
                        long id = Db.insert("INSERT INTO bookings (ref,group_ref,customer_id,customer_name,customer_phone,activity_id,booking_date,slot,hours,rental_type,amount,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,'PENDING_PAYMENT')",
                                ref, groupRef, custId, name, phone, item.activityId, item.date, item.slot, item.hours, item.rentalType, item.rate * item.hours);
                        bookingIds.add((int) id);
                    }
                }
            }
        }

        if (error.isEmpty()) {
            c.sessSet("current_booking_ids", bookingIds);
            c.sessSet("current_booking_id", bookingIds.get(0));
            c.allowBookingGroup(groupRef);   // this visitor may view/pay this booking
            c.clearCart();
            c.redirect(c.BASE + "booking/step4.jsp");
            return;
        }
    }
}
%><%= c.pageHead("Book · Details") %><%= c.customerNav() %>

<div class="bsy-screen" style="max-width:1000px;margin:0 auto;padding:34px 24px 80px">
  <div class="step-bar">
    <a href="<%= c.BASE %>booking/step1.jsp" class="done">1 · Build ✓</a>
    <span style="color:var(--faint)">→</span>
    <span class="cur">2 · Details</span>
    <span style="color:var(--faint)">→</span><span>3 · Pay</span>
  </div>
  <h2 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:22px">Your details</h2>

  <div style="display:grid;grid-template-columns:1fr 300px;gap:22px;align-items:start">
    <div>
      <form method="POST">
        <div class="card card-p">
          <div class="fw-800 fs-14 mb-14">Contact information</div>
          <div class="field">
            <label>Full name <span style="color:var(--danger)">*</span></label>
            <input type="text" name="name" placeholder="Your full name" value="<%= Fn.h(customer != null ? customer.s("name") : "") %>" required>
          </div>
          <div class="field">
            <label>Phone number <span style="color:var(--danger)">*</span></label>
            <input type="text" name="phone" placeholder="012-3456789" value="<%= Fn.h(customer != null ? customer.s("phone") : "") %>" required>
          </div>
          <% if (!error.isEmpty()) { %>
            <div class="error-box"><%= Fn.h(error) %></div>
          <% } %>
          <button type="submit" class="btn btn-brand w-full mt-18">Confirm — proceed to payment →</button>
        </div>
      </form>

      <% if (customer == null) { %>
      <div class="card card-p mt-14" style="background:var(--info-bg);border-color:var(--info)">
        <div class="fw-800 fs-13 mb-6" style="color:var(--info)">💡 Have an account?</div>
        <div class="fs-13 text-muted">
          <a href="<%= c.BASE %>login.jsp?redirect=<%= Fn.urlencode(c.BASE + "booking/step3.jsp") %>">Log in</a> to pre-fill your details and keep your booking history in one place.
        </div>
      </div>
      <% } %>
    </div>

    <!-- Cart summary sidebar -->
    <div class="card card-p" style="position:sticky;top:80px">
      <div class="fw-800 fs-14 mb-4">Booking summary</div>
      <div class="fs-12 text-muted mb-14"><%= Fn.h(Fn.dateLabel((String) c.sess("booking_date"))) %></div>

      <% for (CartItem item : cart) {
        double itemAmt = item.rate * item.hours * item.count;
      %>
      <div style="display:flex;align-items:flex-start;gap:10px;margin-bottom:10px;padding-bottom:10px;border-bottom:1px solid var(--border-2)">
        <span style="font-size:20px;flex:none"><%= item.emoji %></span>
        <div style="flex:1;min-width:0">
          <div class="fw-800 fs-13"><%= Fn.h(item.activityName) %><%= item.count > 1 ? " <span style=\"color:var(--brand);font-size:12px\">×" + item.count + "</span>" : "" %></div>
          <div class="fs-12 text-muted"><%= Fn.h(Fn.bookingSlotLabel(item.slot, item.hours, item.rentalType)) %></div>
          <div class="fw-800 fs-12 mt-3" style="color:var(--brand)"><%= Fn.h(Fn.fmt(itemAmt)) %></div>
        </div>
      </div>
      <% } %>

      <div style="display:flex;justify-content:space-between;margin-top:6px" class="fw-800 fs-14">
        <span>Total</span>
        <span style="color:var(--brand)"><%= Fn.h(Fn.fmt(cartTotal)) %></span>
      </div>
      <a href="<%= c.BASE %>booking/step1.jsp" class="btn btn-ghost w-full mt-10" style="font-size:13px;text-align:center">← Edit booking</a>
    </div>
  </div>
</div>

<%= c.customerFooter() %><%= c.pageFoot() %>
