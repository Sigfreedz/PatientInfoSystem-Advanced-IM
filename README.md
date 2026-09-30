# Patient Info System
Diagnostic clinic database and Flask CRUD interface.

## ️ Tech Stack
- **DBMS:** MySQL (XAMPP)
- **Backend/UI:** Flask, Jinja, Bootstrap
- **Version Control:** GitHub

## 📥 Setup Instructions
1. Install [XAMPP](https://www.apachefriends.org/) or MySQL 8.0, then start MySQL.
2. Apply `database/renamed_schema.sql`, seed the current tables, and apply `database/rolve_views.sql` and `database/encryption.sql`.
3. Apply `database/app_auth.sql`. The live `patient_db` connection already has this table created by DBCode.
4. Create a least-privilege MySQL account for normal application traffic and a separate account with role-management privileges for the admin dashboard.
5. Copy `.env.example` to `.env` or set the variables in the process environment.
6. Generate a password hash without storing the plaintext password:

	```text
	python -c "from getpass import getpass; from werkzeug.security import generate_password_hash; print(generate_password_hash(getpass()))"
	```

7. Insert the generated hash into `app_users` with `role_admin`, then start the Flask application.

The application targets `patient_db`. It uses `clinic_patients`, `lab_test_catalog`, `lab_test`, `cbc`, `urinalysis`, `fecalysis`, and `payments`; the legacy names `patients`, `test_orders`, and `test_catalog` are not supported.

## Demo/Defense SQL Artifacts

- `sample.sql` — clean run bundle using live schema names only
- `database/transaction_demo.sql` — ACID + COMMIT/ROLLBACK + `FOR UPDATE` consistency demonstration
- `database/optimization_demo.sql` — baseline and post-index `EXPLAIN`/`EXPLAIN ANALYZE` flow for heavy app queries
- `database/role_priveleges.sql` — least-privilege GRANT/REVOKE matrix and deny-proof checks
- `database/encryption.sql` — AES-256-CBC encryption/decryption and token-hash lookup proof

## Legacy Archive Note

- `database/schema.sql` is retained only as a legacy archive dump with old names.
- Use `database/renamed_schema.sql` and `db_context.md` as the current source of truth.

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
