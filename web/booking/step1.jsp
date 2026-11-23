<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.time.LocalDate, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

// Init cart session
List<CartItem> cart = c.cart();
if (c.sess("booking_date") == null)        c.sessSet("booking_date", LocalDate.now().plusDays(1).toString());
if (c.sess("booking_rental_type") == null) c.sessSet("booking_rental_type", "On-site");

// Session date must be a valid date that hasn't passed
if (!Fn.validBookingDate((String) c.sess("booking_date"))) {
    c.sessSet("booking_date", LocalDate.now().plusDays(1).toString());
    c.clearCart();
}

int closeHour = Fn.closeHour();

// Handle POST actions
if (c.isPost()) {
    String action = c.postTrim("action");

    if (action.equals("set_date")) {
        String newDate = c.postTrim("date");
        if (!Fn.validBookingDate(newDate)) {
            c.setFlash("Please choose today or a future date.", "danger");
        } else if (!newDate.equals(c.sess("booking_date"))) {
            c.sessSet("booking_date", newDate);
            c.clearCart();
        }
    }

    if (action.equals("set_rental_type")) {
        String rt = c.postTrim("rental_type");
        if ((rt.equals("On-site") || rt.equals("Off-site")) && !rt.equals(c.sess("booking_rental_type"))) {
            c.sessSet("booking_rental_type", rt);
            c.clearCart(); // clear cart on type switch
        }
    }

    if (action.equals("add_item")) {
        String actId = c.postTrim("activity_id");
        String slot  = c.postTrim("slot");
        int hours = Fn.clamp(Fn.toInt(c.has("hours") ? c.post("hours") : "1"), 1, 7);
        int count = Fn.clamp(Fn.toInt(c.has("count") ? c.post("count") : "1"), 1, 10);
        boolean isOff = "Off-site".equals(c.sess("booking_rental_type"));
        if (!isOff && !Fn.empty(slot)) {
            // On-site bookings must finish by closing time.
            int startHour = Fn.toInt(slot.split(":")[0]);
            int maxHours = closeHour - startHour;
            if (maxHours >= 1) hours = Math.min(hours, maxHours);
        }
        if (!Fn.empty(actId) && !Fn.empty(slot)) {
            Activity meta = Fn.activityMeta(actId);
            CartItem item = new CartItem();
            item.activityId   = actId;
            item.activityName = actId.equals("kayak") ? "Kayaking (Single)" : meta.name;
            item.emoji        = meta.emoji;
            item.swatch       = meta.swatch;
            item.slot         = slot;
            item.hours        = hours;
            item.count        = count;
            item.rate         = isOff ? meta.offsiteRate : meta.rate;
            item.unit         = isOff ? meta.offsiteUnit : meta.unit;
            item.date         = (String) c.sess("booking_date");
            item.rentalType   = (String) c.sess("booking_rental_type");
            // Server-side check: valid activity/slot and enough free watercraft
            // (bookings already made + what is already in this cart).
            String err = Fn.checkItem(item, Fn.availability(item.date, c.cart(), null), closeHour);
            if (err != null) c.setFlash(err, "danger");
            else c.cart().add(item);
        }
    }

    if (action.equals("remove_item")) {
        int idx = Fn.toInt(c.has("idx") ? c.post("idx") : "-1");
        List<CartItem> cc = c.cart();
        if (idx >= 0 && idx < cc.size()) cc.remove(idx);
    }

    if (action.equals("clear_cart")) c.clearCart();

    if (action.equals("continue") && !c.cart().isEmpty()) {
        c.redirect(c.BASE + "booking/step3.jsp");
        return;
    }

    c.redirect(c.BASE + "booking/step1.jsp");
    return;
}

String date       = (String) c.sess("booking_date");
String rentalType = (String) c.sess("booking_rental_type");
cart              = c.cart();
boolean isOffsite = rentalType.equals("Off-site");

List<String> activityIds = Fn.ACTIVITY_IDS;
List<String> allSlots    = Fn.slots();

List<String> pickupTimes = Fn.PICKUP_TIMES;

// Pre-select activity from ?activity= param
String preSelectAct = activityIds.contains(c.get("activity")) ? c.get("activity") : "";

// Availability = fleet - bookings holding a unit - this session's cart
Fn.Availability av = Fn.availability(date, cart, null);
Map<String, Map<String, Integer>> avail = av.onsite;
Map<String, Integer> offsiteAvail = av.offsite;

// Cart totals
double cartTotal = 0;
int cartUnits = 0;
for (CartItem item : cart) {
    cartTotal += item.rate * item.hours * item.count;
    cartUnits += item.count;
}

Map<String, Object> rates = new LinkedHashMap<>(), offRates = new LinkedHashMap<>(), names = new LinkedHashMap<>();
for (String a : activityIds) {
    Activity am = Fn.activityMeta(a);
    rates.put(a, am.rate);
    offRates.put(a, am.offsiteRate);
    names.put(a, a.equals("kayak") ? "Kayaking (Single)" : am.name);
}
%><%= c.pageHead("Book — Build your booking") %><%= c.customerNav() %>

<div class="bsy-screen" style="max-width:1100px;margin:0 auto;padding:34px 24px 80px">

  <div class="step-bar">
    <span class="cur">1 · Build</span>
    <span style="color:var(--faint)">→</span><span>2 · Details</span>
    <span style="color:var(--faint)">→</span><span>3 · Pay</span>
  </div>
  <h2 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:4px">Build your booking</h2>
  <p class="text-muted" style="font-size:14.5px;margin:0 0 24px">Add one or more activities. You can book multiple watercraft and choose how long for each.</p>

  <div style="display:grid;grid-template-columns:1fr 300px;gap:22px;align-items:start">

    <!-- LEFT: pickers + configurator -->
    <div>

      <!-- Date + rental type -->
      <div class="card card-p mb-18">
        <div class="fw-800 fs-14 mb-12">When &amp; how?</div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;align-items:end">
          <form method="POST" style="margin:0">
            <input type="hidden" name="action" value="set_date">
            <div class="field sm" style="margin:0">
              <label>Booking date<% if (!cart.isEmpty()) { %> <span class="fs-11 fw-400 text-muted">(changing clears cart)</span><% } %></label>
              <input type="date" name="date" value="<%= Fn.h(date) %>" min="<%= Fn.today() %>"
                     onchange="this.form.submit()"
                     style="width:100%;padding:10px 12px;border:1px solid var(--border);border-radius:10px;font-size:14px;font-family:inherit">
            </div>
          </form>
          <form method="POST" style="margin:0">
            <input type="hidden" name="action" value="set_rental_type">
            <div class="field sm" style="margin:0">
              <label>Rental type<% if (!cart.isEmpty()) { %> <span class="fs-11 fw-400 text-muted">(changing clears cart)</span><% } %></label>
              <div style="display:flex;gap:8px">
                <% for (String rt : new String[]{"On-site", "Off-site"}) { boolean on = rentalType.equals(rt); %>
                <button type="submit" name="rental_type" value="<%= Fn.h(rt) %>"
                  style="flex:1;padding:10px 12px;border-radius:10px;font-size:13px;font-weight:700;font-family:inherit;cursor:pointer;transition:.15s;
                         border:1px solid <%= on ? "var(--brand)" : "var(--border)" %>;
                         background:<%= on ? "var(--brand)" : "#fff" %>;
                         color:<%= on ? "#fff" : "var(--ink)" %>">
                  <%= Fn.h(rt) %>
                </button>
                <% } %>
              </div>
              <% if (isOffsite) { %>
              <div class="fs-11 text-muted mt-6" style="line-height:1.4">Off-site rentals are billed per day. Customer collects the watercraft at the chosen pickup time.</div>
              <% } %>
            </div>
          </form>
        </div>
      </div>

      <!-- Activity cards -->
      <div class="fw-800 fs-14 mb-12">Select an activity to add</div>
      <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:20px">
        <% for (String actId : activityIds) {
          Activity m = Fn.activityMeta(actId);
          int maxAvail;
          if (isOffsite) {
              maxAvail = offsiteAvail.getOrDefault(actId, 0);
          } else {
              maxAvail = 0;
              for (int v : avail.get(actId).values()) maxAvail = Math.max(maxAvail, v);
          }
          String displayRate = isOffsite ? Fn.fmt(m.offsiteRate) + m.offsiteUnit : Fn.fmt(m.rate) + m.unit;
        %>
        <button type="button" onclick="selectActivity('<%= Fn.jsAttr(actId) %>')"
          id="act-card-<%= actId %>" class="bsy-tap"
          style="display:flex;gap:14px;align-items:center;text-align:left;background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:16px;cursor:pointer;font-family:inherit;width:100%;transition:.15s">
          <div style="width:52px;height:52px;border-radius:12px;background:<%= Fn.h(m.swatch) %>;display:flex;align-items:center;justify-content:center;font-size:24px;flex:none">
            <%= m.emoji %>
          </div>
          <div>
            <div class="fw-800 fs-14"><%= Fn.h(actId.equals("kayak") ? "Kayaking (Single)" : m.name) %></div>
            <div style="font-size:13px;font-weight:800;color:var(--brand);margin:2px 0"><%= Fn.h(displayRate) %></div>
            <div class="fs-12 <%= maxAvail > 0 ? "fw-800 text-ok" : "text-muted" %>">
              <%= maxAvail > 0 ? maxAvail + " watercraft available" : "None available today" %>
            </div>
          </div>
        </button>
        <% } %>
      </div>

      <!-- Configurator panel -->
      <div id="conf-panel" class="card card-p" style="display:none">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px">
          <div class="fw-800 fs-15" id="conf-title">Configure</div>
          <button type="button" onclick="closeConf()" class="btn btn-ghost btn-xs">✕ Close</button>
        </div>

        <!-- ON-SITE: time slot grid -->
        <div id="conf-slot-section">
          <div class="fw-800 fs-12 text-muted mb-8">Select a time slot</div>
          <div id="conf-slots" style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:18px"></div>
        </div>

        <!-- OFF-SITE: pickup time -->
        <div id="conf-pickup-section" style="display:none">
          <div class="fw-800 fs-12 text-muted mb-8">Pickup time</div>
          <select id="conf-pickup-select" onchange="selectPickupTime(this.value)"
            style="width:100%;padding:10px 12px;border:1px solid var(--border);border-radius:10px;font-size:14px;font-family:inherit;margin-bottom:18px;background:#fff">
            <option value="">— Select pickup time —</option>
            <% for (String pt : pickupTimes) {
              int hInt = Fn.toInt(pt.split(":")[0]);
              String ap = hInt < 12 ? "AM" : "PM";
              int hh = hInt % 12 == 0 ? 12 : hInt % 12;
            %>
            <option value="<%= Fn.h(pt) %>"><%= hh %>:00 <%= ap %></option>
            <% } %>
          </select>
        </div>

        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px;align-items:start">

          <!-- ON-SITE: hours -->
          <div id="conf-hours-section" class="field sm" style="margin:0">
            <label>Duration</label>
            <div style="display:flex;gap:6px">
              <% for (int hv = 1; hv <= 4; hv++) { %>
              <button type="button" id="dur-h-<%= hv %>" onclick="setHours(<%= hv %>)"
                class="bsy-tap" style="flex:1;padding:9px 2px;border-radius:9px;font-size:12px;font-weight:800;font-family:inherit;cursor:pointer;transition:.15s;
                       border:1px solid <%= hv == 1 ? "var(--brand)" : "var(--border)" %>;
                       background:<%= hv == 1 ? "var(--brand)" : "#fff" %>;
                       color:<%= hv == 1 ? "#fff" : "var(--ink)" %>">
                <%= hv %>h
              </button>
              <% } %>
            </div>
          </div>

          <!-- OFF-SITE: days -->
          <div id="conf-days-section" class="field sm" style="margin:0;display:none">
            <label>Number of days</label>
            <div style="display:flex;flex-wrap:wrap;gap:5px">
              <% for (int dv = 1; dv <= 7; dv++) { %>
              <button type="button" id="dur-d-<%= dv %>" onclick="setDays(<%= dv %>)"
                class="bsy-tap" style="flex:1;min-width:30px;padding:9px 4px;border-radius:9px;font-size:11px;font-weight:800;font-family:inherit;cursor:pointer;transition:.15s;
                       border:1px solid <%= dv == 1 ? "var(--brand)" : "var(--border)" %>;
                       background:<%= dv == 1 ? "var(--brand)" : "#fff" %>;
                       color:<%= dv == 1 ? "#fff" : "var(--ink)" %>">
                <%= dv %>d
              </button>
              <% } %>
            </div>
          </div>

          <!-- Quantity (both modes) -->
          <div class="field sm" style="margin:0">
            <label>Qty (watercraft)</label>
            <div style="display:flex;align-items:center;gap:10px;height:38px">
              <button type="button" onclick="adjustCount(-1)"
                style="width:34px;height:34px;border-radius:8px;border:1px solid var(--border);background:#fff;font-size:20px;cursor:pointer;font-family:inherit;display:flex;align-items:center;justify-content:center">−</button>
              <span id="conf-count-display" class="fw-800 fs-18" style="min-width:20px;text-align:center">1</span>
              <button type="button" onclick="adjustCount(1)"
                style="width:34px;height:34px;border-radius:8px;border:1px solid var(--border);background:#fff;font-size:20px;cursor:pointer;font-family:inherit;display:flex;align-items:center;justify-content:center">+</button>
            </div>
          </div>
        </div>

        <div id="conf-avail" style="font-size:13px;font-weight:700;margin-bottom:14px;min-height:18px"></div>

        <form method="POST" id="conf-form">
          <input type="hidden" name="action"      value="add_item">
          <input type="hidden" name="activity_id" id="conf-act-id">
          <input type="hidden" name="slot"        id="conf-slot">
          <input type="hidden" name="hours"       id="conf-hours" value="1">
          <input type="hidden" name="count"       id="conf-count" value="1">
          <button type="submit" id="conf-submit" disabled
            class="btn btn-brand w-full" style="opacity:.5">Select a <%= isOffsite ? "pickup time" : "time slot" %> first</button>
        </form>
      </div>

    </div><!-- /LEFT -->

    <!-- RIGHT: cart -->
    <div style="position:sticky;top:80px">
      <div class="card card-p">
        <div class="fw-800 fs-14 mb-14">
          Your cart
          <% if (cartUnits > 0) { %>
          <span style="background:var(--brand);color:#fff;border-radius:999px;font-size:11px;padding:2px 8px;margin-left:6px"><%= cartUnits %></span>
          <% } %>
        </div>

        <% if (cart.isEmpty()) { %>
        <div class="text-muted fs-13" style="text-align:center;padding:24px 0;line-height:1.7">
          No items yet.<br>Select an activity to start.
        </div>
        <% } else { %>

        <% for (int idx = 0; idx < cart.size(); idx++) {
          CartItem item = cart.get(idx);
          double itemAmt = item.rate * item.hours * item.count;
          boolean isOff = "Off-site".equals(item.rentalType);
          String slotLbl = isOff
            ? "Pickup " + item.slot + " · " + item.hours + " day" + (item.hours > 1 ? "s" : "")
            : Fn.slotDisplay(item.slot, item.hours) + " · " + item.hours + "h";
          String priceLbl = isOff
            ? Fn.fmt(item.rate) + "/day × " + item.hours + "d" + (item.count > 1 ? " × ×" + item.count : "")
            : Fn.fmt(item.rate) + "/h" + (item.hours > 1 ? " ×" + item.hours + "h" : "") + (item.count > 1 ? " ×" + item.count : "");
        %>
        <div style="background:var(--surface-2);border-radius:12px;padding:12px;margin-bottom:10px">
          <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:4px">
            <div style="display:flex;align-items:center;gap:8px">
              <span style="font-size:18px"><%= item.emoji %></span>
              <span class="fw-800 fs-13"><%= Fn.h(item.activityName) %></span>
              <% if (item.count > 1) { %><span class="fs-12 fw-800" style="color:var(--brand)">×<%= item.count %></span><% } %>
            </div>
            <form method="POST" style="margin:0">
              <input type="hidden" name="action" value="remove_item">
              <input type="hidden" name="idx" value="<%= idx %>">
              <button type="submit" style="background:none;border:none;cursor:pointer;font-size:17px;color:var(--muted);padding:0 4px;line-height:1">×</button>
            </form>
          </div>
          <div class="fs-12 text-muted" style="margin-left:26px"><%= Fn.h(slotLbl) %></div>
          <div style="display:flex;justify-content:space-between;margin-top:8px;margin-left:26px">
            <span class="fs-12 text-muted"><%= Fn.h(priceLbl) %></span>
            <span class="fw-800 fs-13" style="color:var(--brand)"><%= Fn.h(Fn.fmt(itemAmt)) %></span>
          </div>
        </div>
        <% } %>

        <div style="border-top:1px solid var(--border-2);margin-top:4px;padding-top:12px;margin-bottom:14px">
          <div style="display:flex;justify-content:space-between" class="fw-800 fs-14">
            <span>Total</span>
            <span style="color:var(--brand)"><%= Fn.h(Fn.fmt(cartTotal)) %></span>
          </div>
        </div>

        <form method="POST">
          <input type="hidden" name="action" value="continue">
          <button type="submit" class="btn btn-brand w-full">Continue to details →</button>
        </form>
        <form method="POST" style="margin-top:8px">
          <input type="hidden" name="action" value="clear_cart">
          <button type="submit" class="btn btn-ghost w-full" style="font-size:12px">Clear cart</button>
        </form>

        <% } %>
      </div>
    </div><!-- /RIGHT -->

  </div>
</div>

<script>
const AVAIL         = <%= Json.encode(avail) %>;
const OFFSITE_AVAIL = <%= Json.encode(offsiteAvail) %>;
const ALL_SLOTS     = <%= Json.encode(allSlots) %>;
const RENTAL_TYPE   = <%= Json.encode(rentalType) %>;
const RATES         = <%= Json.encode(rates) %>;
const OFFSITE_RATES = <%= Json.encode(offRates) %>;
const NAMES         = <%= Json.encode(names) %>;
const CLOSE_HOUR    = <%= closeHour %>;

let selActivity = null;
let selSlot     = null;
let selHours    = 1;
let selDays     = 1;
let selCount    = 1;
const isOffsite = RENTAL_TYPE === 'Off-site';

function getAvailCount(actId, slot, hours) {
  if (!AVAIL[actId]) return 0;
  const startIdx = ALL_SLOTS.indexOf(slot);
  if (startIdx === -1) return 0;
  const startHour = parseInt(slot.split('–')[0].split(':')[0], 10);
  if (startHour + hours > CLOSE_HOUR) return 0; // would run past closing time
  let min = Infinity;
  for (let i = 0; i < hours; i++) {
    const s = ALL_SLOTS[startIdx + i];
    if (!s) break;
    min = Math.min(min, AVAIL[actId][s] || 0);
  }
  return min === Infinity ? 0 : min;
}

function maxOffsiteAvail(actId) {
  return OFFSITE_AVAIL[actId] || 0;
}

function slotEndLabel(slot, hours) {
  if (hours <= 1) return slot;
  const start = slot.split('–')[0];
  const parts = start.split(':').map(Number);
  const endH  = String(parts[0] + hours).padStart(2, '0');
  return start + '–' + endH + ':' + String(parts[1]).padStart(2, '0');
}

function renderSlots() {
  const container = document.getElementById('conf-slots');
  container.innerHTML = '';
  ALL_SLOTS.forEach(slot => {
    const cnt    = getAvailCount(selActivity, slot, selHours);
    const isFull = cnt === 0;
    const isSel  = slot === selSlot;

    const btn = document.createElement('button');
    btn.type      = 'button';
    btn.className = 'bsy-tap';
    btn.disabled  = isFull;

    let bg = '#fff', fg = 'var(--ink)', bc = 'var(--border)', op = '1';
    if (isSel)  { bg = 'var(--brand)'; fg = '#fff'; bc = 'var(--brand)'; }
    if (isFull) { bg = 'var(--surface-2)'; fg = 'var(--faint)'; bc = 'var(--border-2)'; op = '.6'; }

    btn.style.cssText = `width:100%;padding:8px 4px;border-radius:10px;font-size:11px;font-weight:800;font-family:inherit;border:1px solid ${bc};background:${bg};color:${fg};cursor:${isFull?'not-allowed':'pointer'};text-align:center;line-height:1.5;opacity:${op};transition:.1s`;

    const slotStart = slot.split('–')[0];
    btn.innerHTML = `<div>${slotStart}</div><div style="font-size:9px;font-weight:700;opacity:.75">${isFull ? 'Full' : cnt + ' left'}</div>`;
    if (!isFull) btn.onclick = () => selectSlot(slot);
    container.appendChild(btn);
  });
}

function selectActivity(actId) {
  selActivity = actId;
  selSlot     = null;
  selHours    = 1;
  selDays     = 1;
  selCount    = 1;

  document.getElementById('conf-act-id').value              = actId;
  document.getElementById('conf-title').textContent         = 'Add ' + (NAMES[actId] || actId);
  document.getElementById('conf-hours').value               = '1';
  document.getElementById('conf-count').value               = '1';
  document.getElementById('conf-count-display').textContent = '1';
  document.getElementById('conf-slot').value                = '';
  document.getElementById('conf-avail').textContent         = '';

  // Show/hide sections
  document.getElementById('conf-slot-section').style.display   = isOffsite ? 'none' : '';
  document.getElementById('conf-pickup-section').style.display = isOffsite ? '' : 'none';
  document.getElementById('conf-hours-section').style.display  = isOffsite ? 'none' : '';
  document.getElementById('conf-days-section').style.display   = isOffsite ? '' : 'none';

  if (isOffsite) {
    document.getElementById('conf-pickup-select').value = '';
    [1,2,3,4,5,6,7].forEach(d => setDayStyle(d, d === 1));
  } else {
    [1,2,3,4].forEach(h => setDurStyle(h, h === 1));
    renderSlots();
  }

  const sub = document.getElementById('conf-submit');
  sub.disabled = true;
  sub.style.opacity = '.5';
  sub.textContent = isOffsite ? 'Select a pickup time first' : 'Select a time slot first';

  const panel = document.getElementById('conf-panel');
  panel.style.display = 'block';
  panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function closeConf() {
  document.getElementById('conf-panel').style.display = 'none';
  selActivity = null; selSlot = null;
}

/* ── ON-SITE ── */
function selectSlot(slot) {
  selSlot = slot;
  document.getElementById('conf-slot').value = slot;
  renderSlots();
  updateAvailDisplay();
  updateSubmitBtn();
}

function setHours(h) {
  selHours = h;
  document.getElementById('conf-hours').value = h;
  [1,2,3,4].forEach(n => setDurStyle(n, n === h));
  if (selSlot && getAvailCount(selActivity, selSlot, h) === 0) {
    selSlot = null;
    document.getElementById('conf-slot').value = '';
  }
  renderSlots();
  if (selSlot) { updateAvailDisplay(); updateSubmitBtn(); }
  else {
    document.getElementById('conf-avail').textContent = '';
    const sub = document.getElementById('conf-submit');
    sub.disabled = true; sub.style.opacity = '.5'; sub.textContent = 'Select a time slot first';
  }
}

function setDurStyle(h, active) {
  const btn = document.getElementById('dur-h-' + h);
  if (!btn) return;
  btn.style.background  = active ? 'var(--brand)' : '#fff';
  btn.style.color       = active ? '#fff' : 'var(--ink)';
  btn.style.borderColor = active ? 'var(--brand)' : 'var(--border)';
}

function updateAvailDisplay() {
  if (!selSlot) return;
  const cnt = getAvailCount(selActivity, selSlot, selHours);
  const el  = document.getElementById('conf-avail');
  el.textContent = cnt + ' watercraft available · ' + slotEndLabel(selSlot, selHours);
  el.style.color = cnt > 0 ? 'var(--ok)' : 'var(--danger)';
}

/* ── OFF-SITE ── */
function selectPickupTime(time) {
  if (!time) return;
  selSlot = time;
  document.getElementById('conf-slot').value = time;
  const cnt = maxOffsiteAvail(selActivity);
  const el  = document.getElementById('conf-avail');
  el.textContent = cnt + ' watercraft available';
  el.style.color = cnt > 0 ? 'var(--ok)' : 'var(--danger)';
  updateSubmitBtn();
}

function setDays(d) {
  selDays = d;
  document.getElementById('conf-hours').value = d;
  [1,2,3,4,5,6,7].forEach(n => setDayStyle(n, n === d));
  if (selSlot) updateSubmitBtn();
}

function setDayStyle(d, active) {
  const btn = document.getElementById('dur-d-' + d);
  if (!btn) return;
  btn.style.background  = active ? 'var(--brand)' : '#fff';
  btn.style.color       = active ? '#fff' : 'var(--ink)';
  btn.style.borderColor = active ? 'var(--brand)' : 'var(--border)';
}

/* ── SHARED ── */
function adjustCount(delta) {
  const maxAvail = isOffsite
    ? maxOffsiteAvail(selActivity)
    : (selSlot ? getAvailCount(selActivity, selSlot, selHours) : 0);
  selCount = Math.max(1, Math.min(maxAvail || 1, selCount + delta));
  document.getElementById('conf-count').value = selCount;
  document.getElementById('conf-count-display').textContent = selCount;
  if (selSlot) updateSubmitBtn();
}

function updateSubmitBtn() {
  if (!selSlot) return;
  const rate  = isOffsite ? (OFFSITE_RATES[selActivity] || 0) : (RATES[selActivity] || 0);
  const dur   = isOffsite ? selDays : selHours;
  const unit  = isOffsite ? 'd' : 'h';
  const total = rate * dur * selCount;
  const sub   = document.getElementById('conf-submit');
  sub.disabled = false;
  sub.style.opacity = '1';
  sub.textContent = 'Add to cart — RM' + total.toFixed(2) + ' (' + dur + unit + (selCount > 1 ? ' ×' + selCount : '') + ')';
}

<% if (!preSelectAct.isEmpty()) { %>
document.addEventListener('DOMContentLoaded', () => selectActivity('<%= Fn.js(preSelectAct) %>'));
<% } %>
</script>

<%= c.customerFooter() %><%= c.pageFoot() %>
