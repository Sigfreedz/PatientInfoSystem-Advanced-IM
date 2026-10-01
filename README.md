# Patient Info System
Diagnostic clinic database and Flask CRUD interface.

## ️ Tech Stack
- **DBMS:** MySQL (XAMPP)
- **Backend/UI:** Flask, Jinja, Bootstrap
- **Version Control:** GitHub

## 📥 Setup Instructions
### 1) Install prerequisites
1. Install [Python 3.10+](https://www.python.org/downloads/).
2. Install [XAMPP](https://www.apachefriends.org/) (or any MySQL 8.0 server).
3. Start the MySQL service.

### 2) Prepare the Python environment
1. Open a terminal in the project root.
2. Create a virtual environment:
   ```bash
   python -m venv .venv
   ```
3. Activate it:
   - Windows (PowerShell): `.\.venv\Scripts\Activate.ps1`
   - macOS/Linux: `source .venv/bin/activate`
4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### 3) Create and initialize the database
1. Create a database named `patient_db`.
2. Apply the SQL files in this order:
   1. `database/renamed_schema.sql`
   2. Seed/insert your table data (from your dataset)
   3. `database/rolve_views.sql`
   4. `database/encryption.sql`
   5. `database/app_auth.sql`
3. Confirm the expected table names exist: `clinic_patients`, `lab_test_catalog`, `lab_test`, `cbc`, `urinalysis`, `fecalysis`, `payments`, and `app_users`.

### 4) Create MySQL users with correct permissions
1. Create one least-privilege account for regular app traffic (`DB_USER`).
2. Create a separate account for admin-only grant/revoke actions (`DB_ADMIN_USER`).
3. Grant only the minimum required privileges to each account.

### 5) Configure environment variables
1. Copy `.env.example` to `.env`.
2. Update all values in `.env`, especially:
   - `FLASK_SECRET_KEY`
   - `PATIENT_ENCRYPTION_KEY`
   - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
   - `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD`
3. Set `FLASK_DEBUG=true` only for local development.

### 6) Create the first admin app account
1. Generate a password hash:
   ```bash
   python -c "from getpass import getpass; from werkzeug.security import generate_password_hash; print(generate_password_hash(getpass()))"
   ```
2. Insert a row into `app_users` using the generated hash and assign `role_admin`.

### 7) Run the application
1. Start Flask:
   ```bash
   python app.py
   ```
2. Open the app in your browser (default Flask URL is `http://127.0.0.1:5000`).

The application targets `patient_db`. Legacy names `patients`, `test_orders`, and `test_catalog` are not supported.

## Environment

Required for a deployed configuration:

- `FLASK_SECRET_KEY`
- `PATIENT_ENCRYPTION_KEY`
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD` for the admin-only MySQL `GRANT`/`REVOKE` dashboard

Set `FLASK_DEBUG=true` only during local development. Never commit `.env`, database passwords, demo passwords, or encryption keys.

The application encrypts contact and receipt values with AES-256-CBC and per-row IVs, and stores SHA-256 token hashes for equality lookup. Plaintext columns remain during the verification phase documented in `database/encryption.sql`.

## 👥 Team Roles & Tasks
| Member | Responsibility |
|--------|----------------|
| Sigfrid | Database Design, Normalization, SQL Queries |
| Sigfrid | UI |
| Jerwin| Documentation, ERD, Presentation |

## 📋 Rubric Alignment
- ✅ 6 Tables (5–8 required) | ✅ UNF→3NF Normalization | ✅ 20+ Records/Table
- ✅ 20 SQL Queries (JOIN, Aggregate, Subquery, UPDATE, DELETE)
- ✅ Full CRUD Interface | ✅ Documentation & 5–10 min Demo
