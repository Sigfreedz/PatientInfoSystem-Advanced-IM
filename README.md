# Patient Info System

Diagnostic clinic database and Flask CRUD interface for patient registration, laboratory orders, results, billing, role-based access, and patient self-service.

## Technology

- MySQL 8.0 or MariaDB-compatible local server
- Flask, PyMySQL, Jinja, Bootstrap
- AES-256-CBC field encryption for contacts and receipts
- MySQL roles and grants for database access control

## Database Setup

Run the scripts in this order against a local MySQL server. The commands below assume the MySQL client is available on `PATH`; alternatively, open MySQL Workbench and run each file in the same order.

```text
mysql -u root -p
SOURCE C:/sbarrera/PatientInfoSystem/database/renamed_schema.sql;
SOURCE C:/sbarrera/PatientInfoSystem/database/new_seed.sql;
SOURCE C:/sbarrera/PatientInfoSystem/database/rolve_views.sql;
SOURCE C:/sbarrera/PatientInfoSystem/database/encryption.sql;
SOURCE C:/sbarrera/PatientInfoSystem/database/app_auth.sql;
SOURCE C:/sbarrera/PatientInfoSystem/database/role_priveleges.sql;
```

The scripts perform these tasks:

1. `renamed_schema.sql` creates the current `patient_db` tables and foreign keys.
2. `new_seed.sql` inserts sample patients, tests, orders, results, and payments. It clears existing application data first, so use it only for a fresh demo database.
3. `rolve_views.sql` creates the patient, front-desk, lab, doctor, and audit views.
4. `encryption.sql` adds encrypted columns, migrates existing contacts and receipts, creates decryption views, and runs encryption checks.
5. `app_auth.sql` creates the Flask `app_users` table and includes a safe account-listing query.
6. `role_priveleges.sql` creates MySQL roles, grants table/view privileges, creates demo MySQL users, and runs grant verification queries.

Do not use the older `schema.sql`, `seed.sql`, or legacy `queries.sql` for the live application. Those files use names such as `patients`, `test_orders`, and `test_catalog`. For current-schema CRUD examples, use `database/crud_examples.sql`.

## Encryption Key

The value used by `PATIENT_ENCRYPTION_KEY` must match the key used when `encryption.sql` encrypts the database. If the key changes after data is encrypted, decryption will return invalid or empty values. Keep the key outside source control and never paste it into documentation or presentations.

To run the read-only encryption presentation queries:

```text
SOURCE C:/sbarrera/PatientInfoSystem/database/demo_decrypt.sql;
```

Replace the key placeholder in that file only in a local copy. It displays ciphertext, IVs, token hashes, decrypted contacts/receipts, indexed lookups, and the random-IV proof.

## Application Configuration

Create a local `.env` file from `.env.example`:

```dotenv
FLASK_SECRET_KEY=replace-with-a-long-random-secret
PATIENT_ENCRYPTION_KEY=replace-with-the-database-encryption-key
DB_HOST=localhost
DB_PORT=3306
DB_NAME=patient_db
DB_USER=patient_app
DB_PASSWORD=replace-with-app-password
DB_ADMIN_USER=patient_role_admin
DB_ADMIN_PASSWORD=replace-with-admin-password
FLASK_DEBUG=false
SESSION_COOKIE_SECURE=false
```

For quick local testing, root may be used temporarily, but the application should use a least-privilege account in a real deployment. Do not commit `.env`, database passwords, encryption keys, or demo credentials.

Install dependencies and start Flask:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m flask --app app run --host 127.0.0.1 --port 5000
```

The application opens at `http://127.0.0.1:5000`. Use `FLASK_DEBUG=true` only during local development.

## Demo Accounts and Roles

The role script creates these classroom accounts:

| Account | Role | Purpose |
| --- | --- | --- |
| `user_admin` | Admin | User, role, and database administration |
| `user_frontdesk` | Front desk | Patients, orders, billing, and payments |
| `user_labtech` | Lab technician | Laboratory result entry and updates |
| `user_doctor` | Doctor | Clinical views and lab-order workflow |
| `user_patient` | Patient | Own patient portal only |

The passwords are defined in the SQL demonstration script and should be replaced outside a classroom environment.

## Demonstration Queries

Use these files during the presentation:

- `queries.sql`: legacy query collection; update table names before using it with the live schema.
- `database/crud_examples.sql`: current-schema CRUD examples.
- `database/transaction_management.sql`: `START TRANSACTION`, `COMMIT`, `ROLLBACK`, and payment `FOR UPDATE` demonstrations. The main test ends with `ROLLBACK`.
- `database/demo_decrypt.sql`: encryption/decryption and IV demonstrations.
- `database/role_priveleges.sql`: role grants, revokes, and access-control verification.

## Team Testing Through a Tunnel

Keep Flask bound to localhost and expose only the web server through a temporary Cloudflare Tunnel:

```powershell
python -m flask --app app run --host 127.0.0.1 --port 5000
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://127.0.0.1:5000
```

Share the generated HTTPS URL with testers. The quick-tunnel URL changes when the process restarts, while MySQL remains private on the host computer.

## Database Context

See [db_context.md](db_context.md) for the verified table relationships, foreign keys, views, encryption columns, and application compatibility notes.
