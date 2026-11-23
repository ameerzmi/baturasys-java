package com.baturasys;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;
import javax.servlet.ServletContext;

/**
 * First-run setup. When the configured database has no tables yet (a teammate's
 * new Java DB, or the cloud container), it creates the tables from
 * WEB-INF/schema.sql and fills them with the demo data (DemoSeed).
 * An existing database with tables is never touched.
 */
public final class DbInit {

    private static volatile boolean done = false;

    private DbInit() { }

    /** Runs once per application start; failures (e.g. DB not up yet) are retried on the next request. */
    static void ensure(ServletContext ctx) {
        if (done) return;
        synchronized (DbInit.class) {
            if (done) return;
            try {
                if (!hasTables()) {
                    createSchema(ctx);
                    DemoSeed.run(new ArrayList<String>());
                    ctx.log("BaturaSys: empty database detected - created tables and demo data.");
                }
                done = true;
            } catch (Db.DbException e) {
                ctx.log("BaturaSys: database not ready yet (" + e.getMessage() + ")");
            } finally {
                Db.release();
            }
        }
    }

    private static boolean hasTables() {
        try (Statement st = Db.conn().createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM SYS.SYSTABLES WHERE CAST(TABLETYPE AS VARCHAR(1))='T'")) {
            rs.next();
            return rs.getInt(1) > 0;
        } catch (java.sql.SQLException e) {
            throw new Db.DbException(e.getMessage(), e);
        }
    }

    private static void createSchema(ServletContext ctx) {
        String sql;
        try (InputStream in = ctx.getResourceAsStream("/WEB-INF/schema.sql");
             Scanner sc = new Scanner(in, StandardCharsets.UTF_8.name()).useDelimiter("\\A")) {
            sql = sc.hasNext() ? sc.next() : "";
        } catch (Exception e) {
            throw new Db.DbException("Cannot read WEB-INF/schema.sql: " + e.getMessage(), e);
        }
        List<String> stmts = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        for (String line : sql.split("\\r?\\n")) {
            String t = line.trim();
            if (t.startsWith("--") || t.isEmpty()) continue;
            cur.append(line).append('\n');
            if (t.endsWith(";")) {
                String s = cur.toString().trim();
                stmts.add(s.substring(0, s.length() - 1));
                cur.setLength(0);
            }
        }
        Connection c = Db.conn();
        try (Statement st = c.createStatement()) {
            for (String s : stmts) st.execute(s);
        } catch (java.sql.SQLException e) {
            throw new Db.DbException("Creating tables failed: " + e.getMessage(), e);
        }
    }
}
