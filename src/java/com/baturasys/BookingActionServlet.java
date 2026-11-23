package com.baturasys;

import java.util.List;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;

/** Java version of api/booking-action.php */
@WebServlet(name = "BookingActionServlet", urlPatterns = {"/api/booking-action"})
@MultipartConfig
public class BookingActionServlet extends ApiServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void handle(Ctx c) {
        String action = c.has("action") ? c.post("action") : "";
        switch (action) {
            case "cancel":
                cancelBooking(c);
                break;
            default:
                jsonErr("Unknown action");
        }
    }

    private void cancelBooking(Ctx c) {
        String groupRef = p(c, "group_ref").trim();
        int bookingId = Fn.toInt(p(c, "booking_id"));

        // Load all bookings in the group (or single booking for legacy calls)
        List<Row> bookings = null;
        if (!Fn.empty(groupRef)) {
            bookings = Db.all("SELECT * FROM bookings WHERE (group_ref=? OR (group_ref IS NULL AND ref=?))", groupRef, groupRef);
        } else if (bookingId != 0) {
            bookings = Db.all("SELECT * FROM bookings WHERE id=?", bookingId);
        } else {
            jsonErr("Missing booking reference");
        }
        if (bookings.isEmpty()) jsonErr("Booking not found");

        Row first = bookings.get(0);

        // Auth: customer must own it, staff/manager may cancel any booking,
        // and guest bookings (no linked account) can be cancelled by anyone
        // holding the reference — the ref is the guest access credential.
        if (c.isCustomer()) {
            Row cust = c.currentCustomer();
            if (!first.isNull("customer_id") && first.i("customer_id") != cust.i("id")) {
                jsonErr("Not authorised");
            }
        } else if (!c.isStaff() && !c.isManager() && !first.isNull("customer_id")) {
            jsonErr("Not authorised");
        }

        String st = first.s("status");
        if (!"PENDING_PAYMENT".equals(st) && !"AWAITING_VERIFICATION".equals(st)) {
            jsonErr("This booking can no longer be cancelled — payment has already been confirmed.");
        }

        for (Row b : bookings) {
            Db.exec("UPDATE bookings SET status='CANCELLED', updated_at=CURRENT_TIMESTAMP WHERE id=?", b.i("id"));
        }

        Fn.addAlert("Cancellation", "low", "Booking " + (!Fn.empty(groupRef) ? groupRef : first.s("ref"))
                + " was cancelled (" + bookings.size() + " item(s)).");

        c.sessRemove("booking_draft");

        jsonOk(map("message", "Booking cancelled"));
    }
}
