# Patient Info System Database Context

## Source of Truth

This context was generated from the live MySQL database through DBCode.

- Connection: `clinic`
- Database: `patient_db`
- Tables verified: `cbc`, `clinic_patients`, `fecalysis`, `lab_test`, `lab_test_catalog`, `payments`, `urinalysis`
- Storage engine: InnoDB
- Table character set: utf8mb4
- Table collation: utf8mb4_0900_ai_ci

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
  - `status` ENUM, required, default `PENDING`
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
  - `amount_paid` DECIMAL(10,2), required, must be greater than zero
  - `payment_method` ENUM('CASH', 'CARD', 'GCASH', 'INSURANCE'), required, default `CASH`
  - `payment_date` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `receipt_number` VARCHAR(50), nullable
  - `status` ENUM('PAID', 'PARTIAL', 'REFUNDED'), required, default `PAID`
  - `created_at` DATETIME, required, default `CURRENT_TIMESTAMP`
  - `updated_at` DATETIME, required, default `CURRENT_TIMESTAMP`

## Foreign Keys

| Constraint | Child table and column | Parent table and column |
| --- | --- | --- |
| `fk_lab_test_patient` | `lab_test.patient_id` | `clinic_patients.patient_id` |
| `fk_lab_test_test` | `lab_test.test_id` | `lab_test_catalog.test_id` |
| `fk_cbc_order` | `cbc.order_id` | `lab_test.order_id` |
| `fk_urinalysis_order` | `urinalysis.order_id` | `lab_test.order_id` |
| `fk_fecalysis_order` | `fecalysis.order_id` | `lab_test.order_id` |
| `fk_payments_order` | `payments.order_id` | `lab_test.order_id` |

## Implementation Notes

- Use the live table names documented here in application queries.
- `lab_test` is the live order table name; it is not currently named `lab_orders`.
- `lab_test_catalog` is the live catalog table name; it is not currently named `diagnostic_tests`.
- `cbc`, `urinalysis`, and `fecalysis` use one-to-one result relationships with `lab_test` through unique `order_id` values.
- `payments` uses a many-to-one relationship with `lab_test`; `ON DELETE CASCADE` and `ON UPDATE CASCADE` apply through `fk_payments_order`.
- The payment amount check constraint is `chk_payment_positive` (`amount_paid` > 0).
- DBCode reported zero rows in the six original tables when this context was generated; row-count metadata was not returned for `payments`.
