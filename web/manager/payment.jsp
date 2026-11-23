<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, com.baturasys.*" %><%
Ctx c = new Ctx(request, response);

if (!c.requireManager()) return;

Map<String, String> settings = Fn.getAllSettings();
// Same setting the QR upload saves (and the customer payment page reads).
// (Fixed: the PHP version read 'duitnow_qr_path', so the QR never showed here.)
String qrPath = Fn.opt(settings, "qr_image_path", "");
String qrName = !Fn.empty(qrPath) ? new java.io.File(qrPath).getName() : "";
String qrUrl  = (!qrName.isEmpty() && new java.io.File(Config.UPLOAD_DIR + qrName).isFile())
        ? c.UPLOAD_URL + qrName + "?v=" + new java.io.File(Config.UPLOAD_DIR + qrName).lastModified() : "";
String bankName   = Fn.opt(settings, "bank_name", "");
String bankAcc    = Fn.opt(settings, "bank_account", "");
String bankHolder = Fn.opt(settings, "bank_holder", "");
%><%= c.pageHead("Payment Settings") %>
<div class="portal-wrap">
<%= c.managerSidebar("payment") %>
<main class="portal-main bsy-scroll">
<div class="portal-content bsy-screen" style="max-width:720px">
  <h1 style="font-size:24px;font-weight:800;letter-spacing:-.5px;margin-bottom:3px">Payment settings</h1>
  <p class="fs-14 text-muted mb-22">Upload your DuitNow QR and update bank account details shown to customers.</p>

  <!-- DuitNow QR -->
  <div class="card card-p mb-18">
    <div class="fw-800 fs-15 mb-4">DuitNow QR code</div>
    <p class="fs-13 text-muted mb-18">This QR is displayed on the booking payment page. Upload a PNG or JPG exported from your bank app.</p>

    <% if (!qrUrl.isEmpty()) { %>
    <div style="margin-bottom:16px;text-align:center">
      <img src="<%= Fn.h(qrUrl) %>" alt="DuitNow QR" style="max-width:220px;border-radius:12px;border:1px solid var(--border-2);padding:12px">
      <div class="fs-12 text-muted mt-8">Current QR code</div>
    </div>
    <% } %>

    <div class="receipt-drop" id="qr-drop" onclick="document.getElementById('qr-file').click()" style="cursor:pointer">
      <div id="qr-preview-wrap" style="display:none;text-align:center">
        <img id="qr-preview" style="max-height:160px;border-radius:8px">
        <div class="fs-12 text-muted mt-8" id="qr-filename"></div>
      </div>
      <div id="qr-placeholder">
        <div style="font-size:32px;margin-bottom:10px">📲</div>
        <div class="fw-700 fs-14">Click to upload QR image</div>
        <div class="fs-12 text-muted mt-4">PNG or JPG, max 5MB</div>
      </div>
    </div>
    <input type="file" id="qr-file" accept="image/png,image/jpeg" style="display:none">

    <button class="btn btn-brand mt-14" id="qr-upload-btn" style="display:none" onclick="uploadQr()">Upload QR</button>
  </div>

  <!-- Bank account -->
  <div class="card card-p">
    <div class="fw-800 fs-15 mb-4">Bank account details</div>
    <p class="fs-13 text-muted mb-18">Shown as reference when customers transfer manually.</p>
    <form id="bank-form">
      <input type="hidden" name="action" value="save_payment">
      <div class="field sm">
        <label>Bank name</label>
        <input type="text" name="bank_name" value="<%= Fn.h(bankName) %>" placeholder="e.g. Maybank, CIMB" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="field sm">
        <label>Account number</label>
        <input type="text" name="bank_account" value="<%= Fn.h(bankAcc) %>" placeholder="e.g. 1234 5678 9012" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="field sm">
        <label>Account holder name</label>
        <input type="text" name="bank_holder" value="<%= Fn.h(bankHolder) %>" placeholder="e.g. Antan Batura Sdn Bhd" style="width:100%;padding:11px 13px;border:1px solid var(--border);border-radius:10px;font-size:14px">
      </div>
      <div class="mt-18">
        <button type="button" class="btn btn-brand" onclick="submitManagerForm('bank-form','save_payment','Payment settings saved')">Save changes</button>
      </div>
    </form>
  </div>
</div>
</main>
</div>

<script>
const qrDrop = document.getElementById('qr-drop');
const qrFile = document.getElementById('qr-file');
const qrPreviewWrap = document.getElementById('qr-preview-wrap');
const qrPreview = document.getElementById('qr-preview');
const qrPlaceholder = document.getElementById('qr-placeholder');
const qrFilename = document.getElementById('qr-filename');
const qrUploadBtn = document.getElementById('qr-upload-btn');

qrFile.addEventListener('change', () => {
  const file = qrFile.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    qrPreview.src = e.target.result;
    qrFilename.textContent = file.name;
    qrPreviewWrap.style.display = 'block';
    qrPlaceholder.style.display = 'none';
    qrUploadBtn.style.display = 'inline-block';
  };
  reader.readAsDataURL(file);
});

async function uploadQr() {
  const file = qrFile.files[0];
  if (!file) return;
  const fd = new FormData();
  fd.append('action', 'upload_qr');
  fd.append('qr_file', file);
  const res = await postJson(BASE_URL + 'api/manager-action', fd);
  if (res.success) { showToast('QR code updated', 'ok'); setTimeout(()=>location.reload(), 900); }
  else showToast(res.message, 'danger');
}
</script>

<%= c.logoutFab() %><%= c.pageFoot() %>
