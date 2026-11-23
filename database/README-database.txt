BaturaSys (Java) - Java DB database
===================================

The app uses NetBeans 8.2's built-in Java DB (Apache Derby 10.10, bundled with
GlassFish 4.1.1). No XAMPP / MySQL is needed.

  Database : baturasys
  URL      : jdbc:derby://localhost:1527/baturasys
  User     : app      Password: app      Schema: APP
  Stored in: <your home>\AppData\Roaming\NetBeans\Derby\baturasys

FIRST RUN (teammates)
  Nothing to import. When you Run the project, the database is created
  automatically and filled with demo data (tables from web/WEB-INF/schema.sql,
  data from DemoSeed.java). A database that already has tables is never touched.

BROWSING IT IN NETBEANS
  Services tab > Databases > Java DB > right-click > Start Server
  (Running the project starts GlassFish, which starts Java DB automatically.)
  Databases > New Connection > Java DB (Network): host localhost, port 1527,
  database baturasys, user app, password app > Connect.
  Browse APP > Tables, or right-click > Execute Command to run SQL.

RESET TO DEMO DATA
  Log in as manager (MGR-01 / batura123), open /setup.jsp, type RESET.
  Or: stop the app, delete the "baturasys" database (Services > Databases >
  Java DB > right-click baturasys > Delete), and Run again.

REAL DATA (project owner's PC only)
  database/baturasys_derby.sql is a full copy of the real data (customers,
  bookings, password hashes). It is in .gitignore and must never be committed.

Differences from MySQL that the Java code handles
  NOW()/CURDATE()  -> CURRENT_TIMESTAMP / CURRENT_DATE
  LIMIT n          -> FETCH FIRST n ROWS ONLY
  FIELD(...)       -> CASE WHEN ... END
  GROUP_CONCAT     -> grouped in Java (Fn.groupBookings)
  ON DUPLICATE KEY -> Fn.saveSetting (update, else insert)
  ENUM columns     -> VARCHAR + CHECK constraints
