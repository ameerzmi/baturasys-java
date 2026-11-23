package com.baturasys;

import java.io.*;
import java.nio.file.Files;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;

/**
 * Serves uploaded files (receipts, DuitNow QR) from Config.UPLOAD_DIR at
 * /uploads/... — the PHP version served them straight from the uploads folder.
 */
@WebServlet(name = "UploadServlet", urlPatterns = {"/uploads/*"})
public class UploadServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String path = req.getPathInfo();
        if (path == null || path.contains("..") || path.contains("\0")) {
            res.sendError(404);
            return;
        }
        File base = new File(Config.UPLOAD_DIR).getCanonicalFile();
        File f = new File(base, path).getCanonicalFile();
        if (!f.getPath().startsWith(base.getPath()) || !f.isFile()) {
            res.sendError(404);
            return;
        }
        // Payment receipts are private: only staff/manager, the booking's owner, or the
        // visitor who made / looked up that booking may download them.
        if (path.startsWith("/receipts/")) {
            Row b = Db.one("SELECT * FROM bookings WHERE receipt_path=? FETCH FIRST 1 ROWS ONLY", path.substring(1));
            if (!new Ctx(req, res).canViewBooking(b)) {
                res.sendError(404);
                return;
            }
        }
        String type = getServletContext().getMimeType(f.getName());
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setContentType(type != null ? type : "application/octet-stream");
        res.setContentLengthLong(f.length());
        Files.copy(f.toPath(), res.getOutputStream());
    }
}
