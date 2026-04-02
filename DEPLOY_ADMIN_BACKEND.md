## Admin Deployment Checklist

### 1. Deploy the PHP API to Railway

Deploy this folder as its own service:

`welding_api`

Railway should detect the included `Dockerfile` automatically.

### 2. Add a MySQL database in Railway

Create a `MySQL` service in the same Railway project.

### 3. Set Railway environment variables for the API service

Add these variables to the `welding_api` service:

`SMTP_HOST=smtp.gmail.com`

`SMTP_PORT=587`

`SMTP_SECURE=tls`

`SMTP_USER=your-email@gmail.com`

`SMTP_PASS=your-gmail-app-password`

`SMTP_FROM=your-email@gmail.com`

`SMTP_FROM_NAME=Welding Works`

`TESDA_CC_EMAIL=your-email@gmail.com`

`DEV_SHOW_OTP=0`

Database variables are usually provided automatically by Railway MySQL:

`MYSQLHOST`

`MYSQLPORT`

`MYSQLDATABASE`

`MYSQLUSER`

`MYSQLPASSWORD`

### 4. Import the database schema

Run/import this SQL against Railway MySQL:

`welding_api/schema_railway.sql`

Then import any seed/admin data you still need.

### 5. Point Netlify admin to the Railway API

Edit this file before redeploying the admin site:

`admin_web/runtime-config.js`

Set:

`window.__ADMIN_API_BASE__ = "https://your-api.up.railway.app";`

Then redeploy the `admin_web` site to Netlify.

### 6. Security cleanup

Rotate the Gmail app password if `mail_config.php` has ever been committed or shared.
