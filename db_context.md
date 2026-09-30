# Patient Info System Database Context

## Source of Truth

This context was generated from the live MySQL database through DBCode on 2026-09-30. Treat the live database metadata below as authoritative over older SQL dumps in `database/`.

- Connection: `clinic`
- Database: `patient_db`
- Base tables verified: `cbc`, `clinic_patients`, `fecalysis`, `lab_test`, `lab_test_catalog`, `payments`, `urinalysis`
- Views verified: `v_admin_audit_log`, `v_doctor_clinical_view`, `v_frontdesk_dashboard`, `v_labtech_workspace`, `v_patient_portal`, `v_patients_decrypted`, `v_payments_decrypted`
- Storage engine: InnoDB
- Table character set: utf8mb4
- Table collation: utf8mb4_0900_ai_ci

### Current row counts

| Table | Rows |
| --- | ---: |
| `clinic_patients` | 20 |
| `lab_test_catalog` | 20 |
| `lab_test` | 36 |
| `cbc` | 20 |
| `urinalysis` | 20 |
| `fecalysis` | 20 |
| `payments` | 5 |

View row counts are not stored in `INFORMATION_SCHEMA.TABLES`; query each view when a current count is needed.

## Relationship Overview

```text
clinic_patients (1) ────< lab_test >──── (1) lab_test_catalog
                           |
                           | 1-to-0/1
                           +──── cbc
                           +──── urinalysis
                           +──── fecalysis
                           |
                           +────< payments
```

The result tables each have a unique `order_id`, so each lab order can have at most one CBC, urinalysis, and fecalysis record. Payments do not have a unique `order_id`, so an order can have multiple payment records.

## Tables

### `clinic_patients`

Patient master records.

- Primary key: `patient_id`
- Unique key: `uq_clinic_patients_contact` on `contact`
- Columns:
  - `patient_id` VARCHAR(10), required
  - `first_name` VARCHAR(50), required
  - `last_name` VARCHAR(50), required
  - `age` INT, required
  - `sex` CHAR(1), required
  - `address` VARCHAR(150), nullable
  - `contact` VARCHAR(20), nullable
  - `registered_at` DATETIME, nullable, default `CURRENT_TIMESTAMP`
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `lab_test_catalog`

Catalog of available laboratory tests.

- Primary key: `test_id` (auto-increment)
- Unique key: `uq_lab_test_name` on `test_name`
- Columns:
  - `test_id` INT, required, auto-increment
  - `test_name` VARCHAR, required
  - `price` DECIMAL, required
  - `description` VARCHAR, nullable
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `lab_test`

Orders connecting patients to catalog tests.

- Primary key: `order_id` (auto-increment)
- Indexes:
  - `idx_lab_test_patient_id` on `patient_id`
  - `idx_lab_test_test_id` on `test_id`
- Columns:
  - `order_id` INT, required, auto-increment
  - `patient_id` VARCHAR, required
  - `test_id` INT, required
  - `order_date` DATE, required
  - `status` ENUM('PENDING', 'COMPLETED', 'CANCELLED'), required, default `PENDING`
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `cbc`

Complete blood count results for a lab order.

- Primary key: `cbc_id` (auto-increment)
- Unique key: `uq_cbc_order_id` on `order_id`
- Columns:
  - `cbc_id` INT, required, auto-increment
  - `order_id` INT, required
  - `wbc`, `rbc`, `hemoglobin`, `hematocrit`, `neutrophils`, `lymphocytes`, `monocytes`, `eosinophils`, `basophils` DECIMAL, nullable
  - `platelets`, `mcv`, `mch` INT, nullable
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `urinalysis`

Urinalysis results for a lab order.

- Primary key: `ua_id` (auto-increment)
- Unique key: `uq_urinalysis_order_id` on `order_id`
- Columns:
  - `ua_id` INT, required, auto-increment
  - `order_id` INT, required
  - `appearance`, `color`, `glucose`, `protein`, `ketones`, `nitrites`, `other_findings` VARCHAR, nullable
  - `ph`, `specific_gravity` DECIMAL, nullable
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `fecalysis`

Fecalysis results for a lab order.

- Primary key: `fa_id` (auto-increment)
- Unique key: `uq_fecalysis_order_id` on `order_id`
- Columns:
  - `fa_id` INT, required, auto-increment
  - `order_id` INT, required
  - `appearance`, `consistency`, `occult_blood`, `parasite_id`, `wbc`, `rbc`, `bacteria`, `other_findings` VARCHAR, nullable
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

### `payments`

Payment records linked to laboratory orders.

- Primary key: `payment_id` (auto-increment)
- Unique key: `uq_payments_receipt` on `receipt_number`
- Indexes:
  - `idx_payments_order` on `order_id`
  - `idx_payments_status` on `status`
- Table comment: `Cumulative payment validation SUM(amount_paid) <= lab_test.total_amount enforced at application layer`
- Columns:
  - `payment_id` INT, required, auto-increment
  - `order_id` INT, required
  - `amount_paid` DECIMAL(10,2), required, must be greater than zero (`chk_payment_positive`)
  - `payment_method` ENUM('CASH', 'CARD', 'GCASH', 'INSURANCE'), required, default `CASH`
  - `payment_date` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `receipt_number` VARCHAR(50), nullable
  - `status` ENUM('PAID', 'PARTIAL', 'REFUNDED'), required, default `PAID`
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

## Encryption

The encryption migration is defined in `database/encryption.sql` for MySQL 8.0. It uses AES-256-CBC with a per-row 16-byte IV. The migration encrypts only `clinic_patients.contact` and `payments.receipt_number`; all other columns remain unchanged.

### Encrypted patient contact

`clinic_patients` receives:

- `contact_encrypted` VARBINARY(256): AES ciphertext for `contact`
- `encryption_iv` VARBINARY(16): the IV used for that row
- `contact_token_hash` CHAR(64): SHA-256 lookup token with index `idx_clinic_patients_contact_token_hash`

### Encrypted payment receipt

`payments` receives:

- `receipt_number_encrypted` VARBINARY(256): AES ciphertext for `receipt_number`
- `encryption_iv` VARBINARY(16): the IV used for that row
- `receipt_token_hash` CHAR(64): SHA-256 lookup token with index `idx_payments_receipt_token_hash`

The original plaintext columns remain during the verification phase. The token hashes support indexed equality searches without decrypting every row. Because each row uses a random IV, equal plaintext values do not produce equal ciphertext values.

The migration uses cursor-based updates so each row's IV is generated once and stored alongside the ciphertext. STEP 2 verifies all six columns and both indexes. STEP 3 verifies that ciphertext, IV, and token values are not NULL before converting the new columns to `NOT NULL`. The script also includes idempotent demo inserts and ciphertext/IV proof queries.

### Decryption views

- `v_patients_decrypted` returns patient identity fields and decrypts `contact_encrypted` as `visible_contact`.
- `v_payments_decrypted` returns payment details and decrypts `receipt_number_encrypted` as `visible_receipt`.

Decryption requires the same AES mode, secret key, and row IV used during encryption. The session-key lookup queries at the end of `database/encryption.sql` are preferred for application access. The views currently contain the configured key literal because MySQL 8.0 view definitions cannot reference a user session variable; move the key to application secret storage before production use.

## Foreign Keys

| Constraint | Child table and column | Parent table and column |
| --- | --- | --- |
| `fk_lab_test_patient` | `lab_test.patient_id` | `clinic_patients.patient_id` |
| `fk_lab_test_test` | `lab_test.test_id` | `lab_test_catalog.test_id` |
| `fk_cbc_order` | `cbc.order_id` | `lab_test.order_id` |
| `fk_urinalysis_order` | `urinalysis.order_id` | `lab_test.order_id` |
| `fk_fecalysis_order` | `fecalysis.order_id` | `lab_test.order_id` |
| `fk_payments_order` | `payments.order_id` | `lab_test.order_id` |

All foreign keys use `ON DELETE CASCADE` and `ON UPDATE CASCADE`. Deleting a patient cascades through their orders and then through result and payment records. Deleting a catalog test cascades through matching orders and their dependent records.

## Views

The views are read-oriented projections over the base tables. They are defined with `SQL SECURITY DEFINER` and are not a replacement for the underlying tables when inserting or updating records.

### `v_frontdesk_dashboard`

One row per patient/order, with `patient_id`, patient `name`, `test_name`, `total_amount` (from catalog `price`), order `status`, and `order_date`. This view is updatable according to MySQL metadata, but application writes should target base tables so foreign-key and workflow rules remain explicit.

### `v_patient_portal`

Completed orders only (`status = 'COMPLETED'`). Returns `patient_id`, `first_name`, `last_name`, `order_date`, `test_name`, and `status`. It is updatable according to MySQL metadata, but should be treated as a read projection.

### `v_labtech_workspace`

Pending and completed orders only. Returns order and patient identity fields, `test_name`, order `status`, and the key result indicators `hemoglobin`, `wbc`, `protein`, and `parasite_id`. Result columns are nullable because each result table is optional per order.

### `v_doctor_clinical_view`

Returns patient demographics, test name/date, and selected clinical values: `hemoglobin`, urinalysis `protein`, and fecalysis `parasite_id`. All result joins are left joins, so missing result records remain visible with NULL values.

### `v_admin_audit_log`

Combines every order with patient, catalog, and optional payment data. It exposes order identifiers/status/timestamps plus payment id, amount, method, date, receipt number, and payment status. Orders with multiple payments produce multiple rows.

## Application Compatibility

The current Flask code in `app.py` still queries the older dump names `patients`, `test_orders`, `test_catalog`, `cbc_results`, `urinalysis_results`, and `fecalysis_results`. Those names are not present in the verified live schema. Queries must be migrated to the live names documented here, or the application must be pointed at a database containing the legacy schema before those routes can work.

The live schema also includes `payments`, which is not currently used by the Flask routes. Billing totals in the current app are calculated from catalog prices, not from cumulative payment records.

## Implementation Notes

- Use the live table names documented here in application queries.
- `lab_test` is the live order table name; it is not currently named `lab_orders`.
- `lab_test_catalog` is the live catalog table name; it is not currently named `diagnostic_tests`.
- `cbc`, `urinalysis`, and `fecalysis` use one-to-one result relationships with `lab_test` through unique `order_id` values.
- `payments` uses a many-to-one relationship with `lab_test`; `ON DELETE CASCADE` and `ON UPDATE CASCADE` apply through `fk_payments_order`.
- The payment amount check constraint is `chk_payment_positive` (`amount_paid` > 0).
- DBCode reported the current row counts listed above. The seven views are metadata objects and do not have persisted row-count metadata.
