package com.baturasys;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.LinkedHashMap;

/**
 * One database row (column name -> value), like a PHP PDO::FETCH_ASSOC array.
 * The typed getters mimic PHP's loose casting: (string), (int), (float).
 */
public class Row extends LinkedHashMap<String, Object> {

    private static final long serialVersionUID = 1L;

    /** Value as a string, or null when the column is NULL / missing. */
    public String s(String key) {
        Object v = get(key);
        if (v == null) return null;
        if (v instanceof Timestamp) return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format((Timestamp) v);
        if (v instanceof BigDecimal) return ((BigDecimal) v).toPlainString();
        if (v instanceof byte[]) return new String((byte[]) v, StandardCharsets.UTF_8);
        return v.toString();
    }

    /** Value as a string, "" when NULL (like PHP's "$row['x'] ?? ''"). */
    public String str(String key) {
        String v = s(key);
        return v == null ? "" : v;
    }

    /** (int) cast */
    public int i(String key) {
        Object v = get(key);
        if (v == null) return 0;
        if (v instanceof Number) return ((Number) v).intValue();
        if (v instanceof Boolean) return ((Boolean) v) ? 1 : 0;
        return Fn.toInt(s(key));
    }

    /** (float) cast */
    public double d(String key) {
        Object v = get(key);
        if (v == null) return 0;
        if (v instanceof Number) return ((Number) v).doubleValue();
        return Fn.toFloat(s(key));
    }

    /** NULL check */
    public boolean isNull(String key) {
        return get(key) == null;
    }

    /** PHP truthiness of the column value. */
    public boolean truthy(String key) {
        Object v = get(key);
        if (v == null) return false;
        if (v instanceof Number) return ((Number) v).doubleValue() != 0;
        if (v instanceof Boolean) return (Boolean) v;
        return !Fn.empty(s(key));
    }

    public Timestamp ts(String key) {
        Object v = get(key);
        if (v instanceof Timestamp) return (Timestamp) v;
        if (v == null) return null;
        try { return Timestamp.valueOf(s(key)); } catch (IllegalArgumentException e) { return null; }
    }
}
