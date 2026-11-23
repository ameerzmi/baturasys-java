package com.baturasys;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.http.*;

/**
 * Base class for the JSON endpoints in /api (booking-action, staff-action,
 * manager-action). Provides PHP-style jsonOk()/jsonErr() which end the request.
 */
public abstract class ApiServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    /** Thrown by jsonOk / jsonErr to stop processing (PHP "exit"). */
    protected static class JsonExit extends RuntimeException {
        private static final long serialVersionUID = 1L;
        final int code;
        final String body;
        JsonExit(int code, String body) {
            super(null, null, false, false);
            this.code = code;
            this.body = body;
        }
    }

    protected static void jsonOk(Object data) { jsonOk(data, "OK"); }

    protected static void jsonOk(Object data, String msg) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("success", true);
        m.put("message", msg);
        m.put("data", data);
        throw new JsonExit(200, Json.encode(m));
    }

    protected static void jsonErr(String msg) { jsonErr(msg, 400); }

    protected static void jsonErr(String msg, int code) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("success", false);
        m.put("message", msg);
        throw new JsonExit(code, Json.encode(m));
    }

    /** Small helper to build {"key": value, ...} maps. */
    protected static Map<String, Object> map(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(String.valueOf(kv[i]), kv[i + 1]);
        return m;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        run(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        run(req, res);
    }

    private void run(HttpServletRequest req, HttpServletResponse res) throws IOException {
        Ctx c = new Ctx(req, res);
        try {
            handle(c);
        } catch (JsonExit e) {
            if (!res.isCommitted()) {
                res.setStatus(e.code);
                res.setContentType("application/json");
                res.setCharacterEncoding("UTF-8");
                res.getWriter().print(e.body);
            }
        }
    }

    /** $data['k'] ?? '' — the front end always posts FormData, so this reads request parameters. */
    protected static String p(Ctx c, String k) {
        return c.post(k);
    }

    protected abstract void handle(Ctx c) throws IOException;
}
