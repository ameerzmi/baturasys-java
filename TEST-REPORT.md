# BaturaSys (Java) — Test Report

Tested on 23 Nov 2026 against the Java version running on GlassFish 4.1.1 + Java DB,
as guest, customer, staff and manager. Every finding below was reproduced, except
where marked *(code review)*. Because the Java version is a faithful port, all bugs
except #11 also exist in the PHP version (`C:\xampp\htdocs\baturasys`).

After testing, the database was rebuilt from `database/baturasys_derby.sql`, test
uploads were deleted, and GlassFish / Java DB were stopped. No code was changed.

## Fix status (Java version) — updated after the fix round

Fixed and re-tested (each exploit re-run against the fixed build, plus a real browser booking):

| # | Fix |
|---|-----|
| 1 + 11 | `setup.jsp` requires a manager login and only runs from a POST confirmation (type `RESET`); a plain visit just shows a warning. Its Java DB crash is fixed. |
| 2 | Booking status page, receipt upload and receipt images only for: staff/manager, the owning customer, or a visitor who made / looked up that booking (by reference) in their session. Strangers are sent to the lookup page; receipt files return 404. |
| 3 | Login role is forced to `staff` or `manager`, so the lockout can't be dodged. |
| 4 | Values inside JavaScript strings in onclick handlers are now JavaScript-escaped (`Fn.jsAttr`), on all affected pages and in check-in search results. Verified in a browser: the payload shows as plain text and does not run. |
| 5 | Receipts can only be submitted while a booking is unpaid or rejected; confirmed/checked-in/completed bookings can't be re-submitted (no double revenue). |
| 6 | Server-side availability check when adding to the cart and again (inside a lock) right before bookings are created. Unpaid bookings now hold their watercraft until auto-cancelled. As part of this, the cart also rejects past/invalid dates, unknown activities and slots outside opening hours (#9). |
| NEW | **Found while re-testing:** in the Java version the booking page (step 1) was cut off half-way since the conversion (JSP treated the slot picker's JavaScript `${...}` as server-side EL and crashed), so customers could not book from a browser. Fixed by disabling EL in `web.xml`; all 26 pages now render completely and a full booking was completed in a browser. |

Still open: #7–#10 (except the parts of #9 above) and #12–#23 (medium/low).
The PHP version (`C:\xampp\htdocs\baturasys`) has NOT been changed — bugs #1–#10 and #12–#23 still apply there.

## Summary

| # | Severity | Finding |
|---|----------|---------|
| 1 | Critical | `setup.jsp` / `setup.php` has no login check — any visitor can wipe and reseed the database |
| 2 | High | Booking status page has no owner check — anyone can read every customer's name/phone and upload receipts to other people's bookings |
| 3 | High | Login lockout can be bypassed (unlimited password guessing) |
| 4 | High | Stored XSS: a guest's name runs JavaScript in staff/manager pages (confirmed in a browser) |
| 5 | High | Re-uploading a receipt after confirmation reverts the booking and records revenue twice |
| 6 | High | No server-side availability check — overbooking (20 bookings accepted for 5 boats) |
| 7 | Medium | Anyone can cancel any guest booking by guessing its (sequential) reference |
| 8 | Medium | Open redirect after customer login (`login.jsp?redirect=`) |
| 9 | Medium | Booking accepts past dates, made-up activities, out-of-hours slots |
| 10 | Medium | Single kayak and double kayak share the `WC-KA-` ID prefix → manager can't add watercraft once IDs collide |
| 11 | Medium | `setup.jsp` crashes on Java DB (collation error) — *bug from the Java DB conversion* |
| 12 | Medium | Deactivated staff keep access until they log out |
| 13 | Medium | No CSRF protection on any form or API |
| 14 | Medium | Staff check-in accepts a watercraft of the wrong type and retired/non-existent equipment |
| 15 | Low | Over-long or malformed input crashes pages with a 500 error (name/phone length, dates, settings) |
| 16 | Low | Error pages and API messages leak internals (stack traces, constraint names, server version) |
| 17 | Low | Settings accept invalid values (e.g. close time "abc" breaks the booking page and homepage hours) |
| 18 | Low | Receipt upload only checks the file name, not the content |
| 19 | Low | No security headers (X-Frame-Options, CSP, X-Content-Type-Options) |
| 20 | Low | Missing "not found" checks: updating/retiring a non-existent item reports success |
| 21 | Low | Registration accepts an invalid email address; maintenance can be scheduled for non-existent watercraft/staff |
| 22 | Low | 60 MB upload shows the wrong message ("Please choose a receipt image") |
| 23 | Low *(code review)* | Booking refs / staff IDs / task IDs come from `COUNT(*)+1` — two simultaneous requests can get the same ID (did not reproduce in a 6-way test) |

## Details

### 1. Unauthenticated database reset — Critical
`setup.jsp` (and `setup.php`) runs immediately on a plain GET with no login. On PHP it truncates
every table and reseeds demo data. Fix: delete it from the deployed app, or require the manager
login plus a POST confirmation.

### 2. Booking status IDOR — High
`booking/status.jsp?id=1`, `?id=2`, … shows any booking's customer name, phone, items and receipt
to anyone. Opening a PENDING/REJECTED booking also loads it into the visitor's session, so
`step4.jsp` then lets them upload a receipt to **someone else's** booking (reproduced: a stranger
moved customer #2's rejected booking to "Awaiting verification"). Receipts in `/uploads/receipts/`
are publicly downloadable. Fix: only show a booking to its owner (customer_id) or to a session that
created it or looked it up by reference.

### 3. Login lockout bypass — High
The lockout is keyed on `(identifier, role)`, and `portal-login` treats any `role` other than
`manager` as staff. Sending `role=foo1`, `role=foo2`, … gives a fresh 5 attempts each time
(reproduced: BS-0003 locked under `staff`, then logged in successfully with `role=foo`).
Fix: reject any role except `staff`/`manager`.

### 4. Stored XSS — High (confirmed in a browser)
Names and other user text are HTML-escaped, but then placed inside JavaScript strings in `onclick`
attributes, e.g. `openCheckinModal(61, 'BSY-…', 'NAME')`. The browser decodes `&#039;` back to `'`,
so a guest booking named `Eve');alert(1);//` runs script when staff click *Check in*. The script runs
as the logged-in staff member (it could approve payments). The session cookie is HttpOnly, so it can't
be stolen directly. Affected: staff check-in (page + search results), returns, maintenance,
equipment; manager equipment, staff, watercraft. Fix: pass values with `data-*` attributes, or
JavaScript-escape them (`\'`, `\\`, `<`) instead of HTML-escaping.

### 5. Double revenue after re-upload — High
`step4.jsp` updates every booking in the session to AWAITING_VERIFICATION without checking the current
status. After staff approve, the same guest can upload again; the booking goes back to
"Awaiting verification" (this also works from CHECKED_IN / COMPLETED), and a second approval adds a
second transaction (reproduced: RM12.00 recorded twice). Fix: only allow upload when status is
PENDING_PAYMENT or REJECTED.

### 6. Overbooking — High
Availability is only enforced in the browser. Posting `add_item` directly booked 20 cruise rides for
one slot when only 5 cruise boats exist. Fix: re-check availability in `step3.jsp` before inserting.

### 7. Cancel other guests' bookings — Medium
Guest bookings can be cancelled by anyone who has the reference, and references are predictable
(`BSY-<date>-<running number>`). Reproduced from a fresh session. Fix: random references, or require
the phone number too.

### 8. Open redirect — Medium
`login.jsp?redirect=https://evil.example.com` sends the user there after a real login. Fix: only accept
paths that start with the app's own context path.

### 9. Booking input not validated — Medium
Server accepted: date 2020-01-01; activity `yacht` (priced as kayak); slot `03:00–04:00` for 7 hours.
A garbage date such as `not-a-date` gives a 500 error. Fix: validate the date (today or later), the activity
against the list, and the slot against `slots()`.

### 10. Watercraft ID collision — Medium
`add_watercraft` builds the ID from the first two letters of the activity (`kayak` and `kayak2` →
`WC-KA-`) plus a per-activity count. After adding double kayaks WC-KA-005…013, adding a single kayak
fails with a duplicate-key error. Fix: use a unique prefix per activity, or the max existing number.

### 11. setup.jsp crashes on Java DB — Medium (Java version only)
`SELECT COUNT(*) FROM SYS.SYSTABLES WHERE TABLETYPE='T'` fails because the database uses
case-insensitive collation and system columns don't. Fix: `CAST(TABLETYPE AS VARCHAR(1))='T'` or use
`DatabaseMetaData`. (Fix #1 at the same time.)

### 12. Deactivated staff stay logged in — Medium
After the manager deactivated BS-0001, that staff member's open session still had full access.
Fix: re-check `status='Active'` on each staff request (or in `requireStaff`).

### 13. No CSRF protection — Medium
No tokens or Origin checks; a request with `Origin: https://evil.example.com` was accepted by the manager
API. Modern browsers' default SameSite=Lax cookies reduce the risk, but the app doesn't rely on anything itself.
Logout also works via a plain GET link.

### 14. Check-in not validated — Medium
A paddle-boat booking was checked in with cruise boat WC-25, retired equipment EQ-480 and non-existent EQ-999.

### 15–23. Low
- **15**: Phone longer than 20 characters crashes step 3 with a 500 error (likewise other column limits); bad report dates give a 500.
- **16**: 500 pages show full Java stack traces; API errors show raw database messages; `Server:` and `X-Powered-By:` headers disclose versions.
- **17**: `close_time=abc` was saved; the homepage then showed "Open daily 6pm–12am" and slot logic broke.
- **18**: An HTML file renamed `.png` is accepted as a receipt (the manager QR upload does check the content).
- **19**: No X-Frame-Options / Content-Security-Policy / X-Content-Type-Options headers.
- **20**: `equip_update`, `retire_equipment`, `mark_alert_read` report success for ids that don't exist.
- **21**: `not-an-email` registers fine; maintenance can be scheduled for WC-NOPE / BS-9999.
- **22**: A 60 MB upload exceeds the multipart limit and shows "Please choose a receipt image."
- **23**: Sequential IDs from `COUNT(*)+1` can collide under concurrent requests.

## What passed
- Page access control: all 17 protected pages × 4 roles behave correctly.
- API access control: staff/manager APIs reject other roles.
- SQL injection: none found (all queries are parameterized).
- Path traversal on `/uploads`: blocked.
- Passwords: bcrypt; session ID rotates on login; session cookie is HttpOnly.
- HTML-text output escaping is correct (only the JavaScript-in-attribute cases fail).
- Customer cannot cancel another customer's booking; double approval / double return rejected.
- 5 MB upload limit and QR content check work.
