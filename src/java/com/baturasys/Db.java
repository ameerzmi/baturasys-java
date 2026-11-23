package com.baturasys;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Database access — Java version of includes/db.php (PDO helper).
 * One JDBC connection per HTTP request (opened lazily, closed by AppFilter),
 * just like PHP's static $pdo.
 */
public final class Db {

    private static final ThreadLocal<Connection> CONN = new ThreadLocal<>();

    /** Loads the JDBC driver matching Config.DB_URL (Java DB network or embedded). */
    private static void loadDriver() {
        String cls = Config.DB_URL.startsWith("jdbc:derby://") ? "org.apache.derby.jdbc.ClientDriver"
                   : Config.DB_URL.startsWith("jdbc:derby:")   ? "org.apache.derby.jdbc.EmbeddedDriver"
                   : null;
        if (cls == null) return;
        try {
            Class.forName(cls);
        } catch (ClassNotFoundException e) {
            throw new DbException("Database connection failed: JDBC driver " + cls + " not found (WEB-INF/lib/derbyclient.jar)", e);
        }
    }

    private Db() { }

    public static Connection conn() {
        try {
            Connection c = CONN.get();
            if (c == null || c.isClosed()) {
                loadDriver();
                c = DriverManager.getConnection(Config.DB_URL, Config.DB_USER, Config.DB_PASS);
                CONN.set(c);
            }
            return c;
        } catch (SQLException e) {
            throw new DbException("Database connection failed: " + e.getMessage(), e);
        }
    }

    /** Closes this request's connection (called by AppFilter). */
    public static void release() {
        Connection c = CONN.get();
        CONN.remove();
        if (c != null) {
            try { c.close(); } catch (SQLException ignored) { }
        }
    }

    private static PreparedStatement prepare(String sql, Object[] params, boolean keys) throws SQLException {
        PreparedStatement ps = keys
                ? conn().prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)
                : conn().prepareStatement(sql);
        ParameterMetaData pmd = null;
        for (int i = 0; i < params.length; i++) {
            Object p = params[i];
            if (p == null) {
                // Java DB needs the real column type for NULLs
                int type = Types.VARCHAR;
                try {
                    if (pmd == null) pmd = ps.getParameterMetaData();
                    type = pmd.getParameterType(i + 1);
                } catch (SQLException ignored) { }
                ps.setNull(i + 1, type);
            } else if (p instanceof Boolean) {
                ps.setInt(i + 1, ((Boolean) p) ? 1 : 0);
            } else {
                ps.setObject(i + 1, p);
            }
        }
        return ps;
    }

    /** fetchAll() */
    public static List<Row> all(String sql, Object... params) {
        try (PreparedStatement ps = prepare(sql, params, false); ResultSet rs = ps.executeQuery()) {
            ResultSetMetaData md = rs.getMetaData();
            int n = md.getColumnCount();
            List<Row> out = new ArrayList<>();
            while (rs.next()) {
                Row r = new Row();
                // Java DB returns upper-case names (ID, STATUS...) -> use lower case like MySQL
                for (int i = 1; i <= n; i++) r.put(md.getColumnLabel(i).toLowerCase(java.util.Locale.ROOT), rs.getObject(i));
                out.add(r);
            }
            return out;
        } catch (SQLException e) {
            throw new DbException(e.getMessage(), e);
        }
    }

    /** fetch() — first row or null */
    public static Row one(String sql, Object... params) {
        List<Row> rows = all(sql, params);
        return rows.isEmpty() ? null : rows.get(0);
    }

    /** fetchColumn() */
    public static Object scalar(String sql, Object... params) {
        try (PreparedStatement ps = prepare(sql, params, false); ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getObject(1) : null;
        } catch (SQLException e) {
            throw new DbException(e.getMessage(), e);
        }
    }

    public static int scalarInt(String sql, Object... params) {
        Object v = scalar(sql, params);
        if (v == null) return 0;
        if (v instanceof Number) return ((Number) v).intValue();
        return Fn.toInt(v.toString());
    }

    public static double scalarDouble(String sql, Object... params) {
        Object v = scalar(sql, params);
        if (v == null) return 0;
        if (v instanceof Number) return ((Number) v).doubleValue();
        return Fn.toFloat(v.toString());
    }

    /** execute() for UPDATE / DELETE / INSERT — returns affected rows */
    public static int exec(String sql, Object... params) {
        try (PreparedStatement ps = prepare(sql, params, false)) {
            return ps.executeUpdate();
        } catch (SQLException e) {
            throw new DbException(e.getMessage(), e);
        }
    }

    /** INSERT and return lastInsertId() */
    public static long insert(String sql, Object... params) {
        try (PreparedStatement ps = prepare(sql, params, true)) {
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        } catch (SQLException e) {
            throw new DbException(e.getMessage(), e);
        }
    }

    /** Unchecked wrapper so pages don't need try/catch everywhere (like PDO::ERRMODE_EXCEPTION). */
    public static class DbException extends RuntimeException {
        private static final long serialVersionUID = 1L;
        public DbException(String msg, Throwable cause) { super(msg, cause); }
    }
}
