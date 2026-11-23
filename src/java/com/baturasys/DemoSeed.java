package com.baturasys;

import java.time.LocalDate;
import java.util.List;

/**
 * Demo data used by setup.jsp and by the automatic first-run setup (DbInit).
 * Same data as the PHP version's setup.php. DELETES all existing data first.
 */
public final class DemoSeed {

    private DemoSeed() { }

    public static void run(List<String> messages) {
    // Clear existing seed data (Java DB: DELETE + restart the id counter)
    for (String t : new String[]{"customers","staff","managers","watercraft","equipment","bookings","maintenance_tasks","transactions","alerts","settings"}) {
        Db.exec("DELETE FROM " + t);
        Db.exec("ALTER TABLE " + t + " ALTER COLUMN id RESTART WITH 1");
    }

    LocalDate now = LocalDate.now();
    String today = now.toString();

    String defaultPw = BCrypt.hash("batura123");

    // Manager
    Db.exec("INSERT INTO managers (manager_id,name,email,password_hash) VALUES (?,?,?,?)",
            "MGR-01", "Wan Shafie", "wanshafie@baturasys.my", defaultPw);
    messages.add("Manager created: MGR-01 / batura123");

    // Staff
    String[][] staffData = {
        {"BS-0001","Faizal Rahman","960512105533","Supervisor","2026-06-18 08:42:00"},
        {"BS-0002","Siti Mariam","990223086612","Operations Staff","2026-06-18 09:05:00"},
        {"BS-0003","Arman Daud","010718141299","Operations Staff","2026-06-17 17:30:00"},
        {"BS-0004","Lina Goh","970904105588","Operations Staff","2026-04-02 10:11:00"},
    };
    for (int i = 0; i < staffData.length; i++) {
        String[] s = staffData[i];
        Db.exec("INSERT INTO staff (staff_id,name,ic_number,role,password_hash,status,last_login) VALUES (?,?,?,?,?,?,?)",
                s[0], s[1], s[2], s[3], defaultPw, i == 3 ? "Deactivated" : "Active", s[4]);
    }
    messages.add("4 staff accounts created (password: batura123)");

    // Customer demo account (password: demo1234)
    Db.exec("INSERT INTO customers (name,email,phone,ic_number,password_hash) VALUES (?,?,?,?,?)",
            "Nurul Aisyah", "aisyah@email.com", "012-3456789", "950312045521", BCrypt.hash("demo1234"));
    messages.add("Demo customer: aisyah@email.com / demo1234");

    // Watercraft
    Object[][] wcData = {
        {"WC-01","Kayak-Single-01","kayak","AVAILABLE",142,"2026-05-20",89,"Good"},
        {"WC-02","Kayak-Single-02","kayak","AVAILABLE",98,"2026-05-22",91,"Good"},
        {"WC-03","Kayak-Single-03","kayak","UNDER_MAINTENANCE",210,"2026-06-15",90,"Worn"},
        {"WC-04","Kayak-Double-01","kayak2","AVAILABLE",176,"2026-05-10",79,"Good"},
        {"WC-05","Kayak-Double-02","kayak2","IN_USE",201,"2026-05-12",81,"Good"},
        {"WC-06","Canoe-01","canoe","AVAILABLE",120,"2026-05-30",99,"Good"},
        {"WC-07","Canoe-02","canoe","AVAILABLE",88,"2026-06-01",91,"Good"},
        {"WC-08","PaddleBoat-01","paddle","AVAILABLE",240,"2026-04-28",39,"Worn"},
        {"WC-09","PaddleBoat-02","paddle","AVAILABLE",160,"2026-05-18",89,"Good"},
        {"WC-10","CruiseBoat-01","cruise","AVAILABLE",310,"2026-05-25",85,"Good"},
        {"WC-11","Kayak-Single-04","kayak","AVAILABLE",0,null,90,"Good"},
        {"WC-12","Kayak-Single-05","kayak","AVAILABLE",0,null,90,"Good"},
        {"WC-13","Kayak-Single-06","kayak","AVAILABLE",0,null,90,"Good"},
        {"WC-14","Kayak-Single-07","kayak","AVAILABLE",0,null,90,"Good"},
        {"WC-17","Kayak-Double-03","kayak2","AVAILABLE",0,null,90,"Good"},
        {"WC-18","Kayak-Double-04","kayak2","AVAILABLE",0,null,90,"Good"},
        {"WC-19","Canoe-03","canoe","AVAILABLE",0,null,90,"Good"},
        {"WC-20","Canoe-04","canoe","AVAILABLE",0,null,90,"Good"},
        {"WC-21","Canoe-05","canoe","AVAILABLE",0,null,90,"Good"},
        {"WC-22","PaddleBoat-03","paddle","AVAILABLE",0,null,90,"Good"},
        {"WC-23","PaddleBoat-04","paddle","AVAILABLE",0,null,90,"Good"},
        {"WC-24","PaddleBoat-05","paddle","AVAILABLE",0,null,90,"Good"},
        {"WC-25","CruiseBoat-02","cruise","AVAILABLE",0,null,90,"Good"},
        {"WC-26","CruiseBoat-03","cruise","AVAILABLE",0,null,90,"Good"},
        {"WC-27","CruiseBoat-04","cruise","AVAILABLE",0,null,90,"Good"},
        {"WC-28","CruiseBoat-05","cruise","AVAILABLE",0,null,90,"Good"},
    };
    for (Object[] w : wcData) {
        Db.exec("INSERT INTO watercraft (identifier,name,activity_id,status,usage_hours,last_maintenance,next_maintenance,condition_status) VALUES (?,?,?,?,?,?,?,?)",
                w[0], w[1], w[2], w[3], w[4], w[5], now.plusDays((Integer) w[6]).toString(), w[7]);
    }
    messages.add("26 watercraft added");

    // Equipment — each row is one physical item
    // [type, size, cond, purchase_date, lifespan_months, replacement_due, status, qty]
    Object[][] eqTemplates = {
        {"Life Jacket","Adult L","Good","2025-01-10",24,"2027-01-10","Active",18},
        {"Life Jacket","Adult M","Good","2024-08-01",24,"2026-08-01","Active",12},
        {"Life Jacket","Child","Worn","2024-07-05",24,"2026-07-05","Active",8},
        {"Paddle","Double","Good","2024-03-12",36,"2027-03-12","Active",20},
        {"Paddle","Single","Damaged","2023-11-20",36,"2026-11-20","Flagged",14},
        {"Helmet","Std","Good","2025-02-01",36,"2028-02-01","Active",10},
        {"Whistle","-","Good","2025-01-01",60,"2030-01-01","Active",25},
        {"Dry Bag","10L","Good","2024-09-15",36,"2027-09-15","Active",6},
    };
    int eqCounter = 100, totalEqItems = 0;
    for (Object[] tpl : eqTemplates) {
        int qty = (Integer) tpl[7];
        for (int i = 0; i < qty; i++) {
            eqCounter++;
            String eqId = "EQ-" + Fn.padLeft(eqCounter, 3);
            Db.exec("INSERT INTO equipment (equipment_id,type,size,condition_status,purchase_date,lifespan_months,replacement_due,status) VALUES (?,?,?,?,?,?,?,?)",
                    eqId, tpl[0], tpl[1], tpl[2], tpl[3], tpl[4], tpl[5], tpl[6]);
            totalEqItems++;
        }
    }
    messages.add(totalEqItems + " individual equipment items added");

    // Bookings
    Object[][] bookData = {
        {"BSY-20260618-0007",1,"Nurul Aisyah","012-3456789","kayak","WC-01",now.plusDays(2).toString(),"10:00–11:00",1,"On-site",10.00,"AWAITING_VERIFICATION"},
        {"BSY-20260618-0006",1,"Nurul Aisyah","012-3456789","paddle","WC-09",now.plusDays(4).toString(),"14:00–15:00",1,"On-site",15.00,"CONFIRMED"},
        {"BSY-20260615-0003",1,"Nurul Aisyah","012-3456789","cruise","WC-10",now.minusDays(3).toString(),"16:00–17:00",1,"On-site",6.00,"COMPLETED"},
        {"BSY-20260612-0001",1,"Nurul Aisyah","012-3456789","canoe","WC-06",now.minusDays(6).toString(),"09:00–10:00",1,"On-site",12.00,"CANCELLED"},
        {"BSY-20260618-0008",null,"Hafiz Tan","017-9988776","kayak2","WC-04",today,"11:00–12:00",1,"On-site",15.00,"AWAITING_VERIFICATION"},
        {"BSY-20260618-0009",null,"Wei Jian","011-22334455","canoe","WC-07",today,"13:00–14:00",1,"On-site",12.00,"PENDING_PAYMENT"},
        {"BSY-20260618-0005",null,"Devi Kumar","016-5544332","kayak","WC-02",today,"09:00–10:00",1,"On-site",10.00,"CONFIRMED"},
        {"BSY-20260618-0004",null,"Marcus Lee","013-7766554","kayak2","WC-05",today,"08:30–09:30",1,"On-site",15.00,"CHECKED_IN"},
    };
    for (Object[] b : bookData) {
        Db.exec("INSERT INTO bookings (ref,customer_id,customer_name,customer_phone,activity_id,watercraft_id,booking_date,slot,hours,rental_type,amount,status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", b);
    }
    // Mark AWAITING_VERIFICATION bookings with a placeholder receipt
    Db.exec("UPDATE bookings SET receipt_path='demo_receipt.jpg' WHERE status IN ('AWAITING_VERIFICATION','CONFIRMED','COMPLETED','CHECKED_IN')");
    // Mark CHECKED_IN with equipment
    Db.exec("UPDATE bookings SET checkin_at=CURRENT_TIMESTAMP, equipment_assigned='EQ-101 Life Jacket, EQ-201 Paddle' WHERE status='CHECKED_IN'");
    messages.add("8 sample bookings created");

    // Maintenance tasks
    Object[][] taskData = {
        {"M1","WC-03","Routine inspection",today,"BS-0003","IN_PROGRESS","",90},
        {"M2","WC-08","Deep clean",now.minusDays(1).toString(),"BS-0002","OVERDUE","",60},
        {"M3","WC-10","Engine check",now.plusDays(3).toString(),"BS-0003","SCHEDULED","",30},
        {"M4","WC-06","Routine inspection",now.minusDays(2).toString(),"BS-0002","COMPLETED","Hull cleaned, no cracks found. Seals intact.",90},
    };
    for (Object[] t : taskData) {
        Db.exec("INSERT INTO maintenance_tasks (task_id,watercraft_id,type,scheduled_date,assignee_id,status,notes,recurring_days) VALUES (?,?,?,?,?,?,?,?)", t);
    }
    messages.add("4 maintenance tasks created");

    // Transactions
    Object[][] txData = {
        {"BSY-20260615-0003",now.minusDays(3).toString(),96.00,"DuitNow QR","Rental"},
        {"BSY-20260616-0002",now.minusDays(2).toString(),130.00,"DuitNow QR","Rental"},
        {"Maintenance — PaddleBoat-01",now.minusDays(2).toString(),-45.00,"Cash","Expense"},
        {"BSY-20260617-0011",now.minusDays(1).toString(),114.00,"DuitNow QR","Rental"},
        {"BSY-20260618-0005",today,88.00,"DuitNow QR","Rental"},
        {"Equipment purchase",today,-180.00,"Cash","Expense"},
    };
    for (Object[] t : txData) {
        Db.exec("INSERT INTO transactions (ref,transaction_date,amount,method,type) VALUES (?,?,?,?,?)", t);
    }
    messages.add("6 sample transactions created");

    // Alerts
    Object[][] alertData = {
        {"Damaged/Missing Equipment","high","Paddle (EQ-202) flagged Damaged — removed from pool, awaiting inspection.",today,0},
        {"Overdue Maintenance","high","PaddleBoat-01 deep clean is OVERDUE (was due yesterday).",now.minusDays(1).toString(),0},
        {"Replacement","medium","Life Jacket Child (EQ-103) within 30 days of replacement due date.",today,0},
        {"Maintenance","low","Canoe-01 routine inspection completed by Siti Mariam — awaiting your approval.",now.minusDays(2).toString(),1},
    };
    for (Object[] a : alertData) {
        Db.exec("INSERT INTO alerts (kind,severity,message,alert_date,is_read) VALUES (?,?,?,?,?)", a);
    }
    messages.add("4 sample alerts created");

    // Settings
    String[][] settingsData = {
        {"open_time","09:00"},
        {"close_time","18:00"},
        {"holding_hours","24"},
        {"cancel_cutoff_hours","2"},
        {"bank_name","Maybank"},
        {"bank_account","5621 0834 1190"},
        {"qr_image_path",""},
        {"qr_label","No QR uploaded yet"},
    };
    for (String[] s : settingsData) {
        Fn.saveSetting(s[0], s[1]);
    }
    messages.add("System settings initialized");
    }
}