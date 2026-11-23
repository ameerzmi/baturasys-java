package com.baturasys;

import javax.servlet.ServletContext;

/**
 * BaturaSys configuration — Java version of includes/config.php.
 * Values are read from the context-params in WEB-INF/web.xml.
 */
public final class Config {

    /** Java DB (Derby) network server started by NetBeans / GlassFish. */
    public static String DB_URL  = "jdbc:derby://localhost:1527/baturasys";
    public static String DB_USER = "app";
    public static String DB_PASS = "app";

    /** Upload folder (receipts/, duitnow_qr.*). */
    public static String UPLOAD_DIR = System.getProperty("user.home") + "/BaturaSysJava/uploads";

    /** Max upload size: 5 MB */
    public static final long MAX_UPLOAD_BYTES = 5L * 1024 * 1024;

    private Config() { }

    static void load(ServletContext ctx) {
        DB_URL  = param(ctx, "db.url", DB_URL);
        DB_USER = param(ctx, "db.user", DB_USER);
        DB_PASS = param(ctx, "db.pass", DB_PASS);
        UPLOAD_DIR = param(ctx, "upload.dir", UPLOAD_DIR);
        // Environment variables win over web.xml (used by the Docker / cloud deployment)
        DB_URL  = env("BATURASYS_DB_URL", DB_URL);
        DB_USER = env("BATURASYS_DB_USER", DB_USER);
        DB_PASS = env("BATURASYS_DB_PASS", DB_PASS);
        UPLOAD_DIR = env("BATURASYS_UPLOAD_DIR", UPLOAD_DIR);
        // A relative upload folder is resolved against the user's home folder, so the same
        // web.xml works on every teammate's PC (e.g. C:\Users\<name>\BaturaSys-uploads).
        if (!new java.io.File(UPLOAD_DIR).isAbsolute()) {
            UPLOAD_DIR = System.getProperty("user.home") + java.io.File.separator + UPLOAD_DIR;
        }
        if (!UPLOAD_DIR.endsWith("/") && !UPLOAD_DIR.endsWith("\\")) UPLOAD_DIR += "/";
    }

    private static String env(String name, String def) {
        String v = System.getenv(name);
        return (v == null || v.trim().isEmpty()) ? def : v.trim();
    }

    private static String param(ServletContext ctx, String name, String def) {
        String v = ctx.getInitParameter(name);
        if (v == null) return def;
        v = v.trim();
        // allow an empty password, but not an empty URL / user / dir
        return (v.isEmpty() && !name.equals("db.pass")) ? def : v;
    }
}
