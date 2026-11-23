package com.baturasys;

import java.io.IOException;
import java.io.PrintWriter;
import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletResponse;

/**
 * Runs around every request:
 *  - loads configuration from web.xml (once)
 *  - forces UTF-8 for request parameters
 *  - closes the request's DB connection and settings cache afterwards
 *  - shows a friendly page when MySQL is unreachable (like includes/db.php)
 */
@WebFilter(filterName = "AppFilter", urlPatterns = {"/*"})
public class AppFilter implements Filter {

    @Override
    public void init(FilterConfig fc) {
        Config.load(fc.getServletContext());
    }

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) throws IOException, ServletException {
        if (req.getCharacterEncoding() == null) req.setCharacterEncoding("UTF-8");
        Fn.resetRequestCache();
        try {
            DbInit.ensure(req.getServletContext());   // first run on an empty DB: tables + demo data
            chain.doFilter(req, res);
        } catch (ServletException | RuntimeException e) {
            Throwable root = e;
            while (root.getCause() != null && !(root instanceof Db.DbException)) root = root.getCause();
            if (root instanceof Db.DbException && root.getMessage() != null
                    && root.getMessage().startsWith("Database connection failed") && !res.isCommitted()) {
                res.reset();
                ((HttpServletResponse) res).setStatus(500);
                res.setContentType("text/html; charset=UTF-8");
                PrintWriter out = res.getWriter();
                out.print("<div style=\"font-family:sans-serif;padding:40px;color:#bf3b2b\"><h2>Database connection failed</h2><p>"
                        + Fn.h(root.getMessage()) + "</p><p>Check the db.url / db.user / db.pass settings in <code>WEB-INF/web.xml</code>"
                        + " and make sure Java DB is running (NetBeans: Services &gt; Databases &gt; Java DB &gt; Start Server)"
                        + " and the <code>baturasys</code> database exists (see <code>database/README-database.txt</code>).</p></div>");
                return;
            }
            throw e;
        } finally {
            Db.release();
            Fn.resetRequestCache();
        }
    }

    @Override
    public void destroy() { }
}
