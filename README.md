# BaturaSys — Java version

Booking & operations system for Antan Batura Watersports (Taman Tasik Shah Alam).
Java EE 7 web app (JSP + Servlets + JDBC) for **NetBeans 8.2 · GlassFish 4.1.1 · Java DB**,
converted from the original PHP version.

## 👀 Just want to look at the site?

Open the **review site** link (pinned in the repository's *About* box, top right of the GitHub page).
It updates automatically a few minutes after anyone pushes to `main`.

| Role | Where | Login | Password |
|---|---|---|---|
| Customer | **Log in** (top right) | `aisyah@email.com` | `demo1234` |
| Staff | **Staff & Manager portal** (footer) | `BS-0002` | `batura123` |
| Manager | same portal → **Manager** tab | `MGR-01` | `batura123` |

Notes: the review site runs on a free plan — if nobody has used it for 15 minutes, the first
visit takes about a minute to wake up. It contains **demo data only**, and the data resets to
the demo set whenever the site restarts or redeploys, so feel free to try anything.

## 🛠 Working on the code (NetBeans 8.2)

You need: **NetBeans 8.2** (Java EE bundle, with GlassFish 4.1.1), **JDK 8**, and **Git**.

1. **Get the code** — in NetBeans: *Team → Git → Clone…*, paste the repository URL
   (GitHub → green **Code** button → HTTPS), sign in with your GitHub account, and open the
   project when NetBeans asks. (Or `git clone <url>` and *File → Open Project*.)
2. **First open only:** if NetBeans says the server is missing, right-click the project →
   *Resolve Missing Server Problem* → choose **GlassFish Server 4.1.1**.
3. **Run** — right-click the project → *Run*. GlassFish and Java DB start automatically and the
   site opens at http://localhost:8080/BaturaSysJava/.
   The first run creates your own local `baturasys` database and fills it with demo data
   (no SQL to import). If you see *Database connection failed*: *Services → Databases →
   Java DB → Start Server*, then Run again.

### Team workflow (please follow — it keeps `main` working)

1. Get the latest code: *Team → Remote → Pull* (or `git pull`).
2. Create a branch for your change: *Team → Branch/Tag → Create Branch…* e.g. `fix-login-message`.
3. Commit as you go (*Team → Commit*), then *Team → Remote → Push* your branch.
4. On GitHub, click **Compare & pull request**, describe the change, and ask a teammate to review.
5. After approval, **Merge**. The review site redeploys from `main` automatically.

Don't commit real customer data, receipts, or passwords (the `.gitignore` already blocks the
usual places: `uploads/`, `database/baturasys_derby.sql`, `nbproject/private/`).

## Project layout

```
src/java/com/baturasys/   Java classes (DB access, helpers, API servlets)
web/                      JSP pages (same names/folders as the PHP pages), assets, WEB-INF
web/WEB-INF/schema.sql    database tables (created automatically on first run)
web/WEB-INF/web.xml       configuration: db.url, db.user, db.pass, upload.dir
database/                 notes about the Java DB database
Dockerfile, render.yaml   how the review site is built and hosted (Render.com)
TEST-REPORT.md            security / test findings and their status
```

### PHP → Java map

| PHP | Java |
|---|---|
| `includes/db.php` | `Db.java` (+ `Row.java`) |
| `includes/functions.php` | `Fn.java` |
| `includes/auth.php`, `includes/layout.php` | `Ctx.java` |
| `password_hash` / `password_verify` | `BCrypt.java` (compatible with PHP `$2y$` hashes) |
| `api/*.php` | `BookingActionServlet`, `StaffActionServlet`, `ManagerActionServlet` (`/api/...`) |
| `setup.php` | `setup.jsp` + `DemoSeed.java` (manager login + confirmation required) |
| every other `X.php` | `web/X.jsp` |

### Configuration

`web/WEB-INF/web.xml` holds the settings (database URL/user/password, upload folder). Uploads
go to `BaturaSys-uploads` in your home folder. The review site overrides these with environment
variables (`BATURASYS_DB_URL`, `BATURASYS_DB_USER`, `BATURASYS_DB_PASS`, `BATURASYS_UPLOAD_DIR`).

Reset your local data to the demo set: log in as manager and open `/setup.jsp` (type `RESET`).
