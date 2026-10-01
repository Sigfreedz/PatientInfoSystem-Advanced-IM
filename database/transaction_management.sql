-- PATIENT INFO SYSTEM - TRANSACTION MANAGEMENT DEMONSTRATION
-- Uses the live schema: clinic_patients, lab_test_catalog, lab_test, cbc,
-- urinalysis, fecalysis, and payments.
-- The main demonstration ends with ROLLBACK, so it does not change production data.

USE `patient_db`;

-- 1. Transaction engine configuration.
SELECT @@autocommit AS autocommit_mode,
       @@transaction_isolation AS transaction_isolation;

SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'patient_db'
  AND TABLE_NAME IN ('lab_test', 'cbc', 'urinalysis', 'fecalysis', 'payments')
ORDER BY TABLE_NAME;

-- 2. Atomic order demonstration.
-- Both the lab_test row and its pending CBC row are part of one transaction.
SET @demo_patient_id = (SELECT MIN(patient_id) FROM clinic_patients);
SET @demo_cbc_test_id = (SELECT MIN(test_id) FROM lab_test_catalog WHERE test_name = 'CBC');

SELECT COUNT(*) AS orders_before
FROM lab_test
WHERE patient_id = @demo_patient_id;

START TRANSACTION;

INSERT INTO lab_test (patient_id, test_id, order_date, status)
VALUES (@demo_patient_id, @demo_cbc_test_id, CURRENT_DATE, 'PENDING');
SET @demo_order_id = LAST_INSERT_ID();

INSERT INTO cbc (order_id)
VALUES (@demo_order_id);

-- Both records are visible inside the current transaction.
SELECT o.order_id, o.patient_id, o.status, c.cbc_id
FROM lab_test o
JOIN cbc c ON c.order_id = o.order_id
WHERE o.order_id = @demo_order_id;

-- Undo both INSERT statements as one atomic unit.
ROLLBACK;

-- The temporary order and result row no longer exist after ROLLBACK.
SELECT COUNT(*) AS orders_after_rollback
FROM lab_test
WHERE order_id = @demo_order_id;

SELECT COUNT(*) AS results_after_rollback
FROM cbc
WHERE order_id = @demo_order_id;

-- 3. Payment isolation demonstration.
-- FOR UPDATE locks the selected order until COMMIT or ROLLBACK.
SET @demo_existing_order_id = (SELECT MIN(order_id) FROM lab_test);

START TRANSACTION;

SELECT o.order_id,
       t.price AS order_total
FROM lab_test o
JOIN lab_test_catalog t ON t.test_id = o.test_id
WHERE o.order_id = @demo_existing_order_id
FOR UPDATE;

SELECT COALESCE(SUM(CASE WHEN status <> 'REFUNDED' THEN amount_paid ELSE 0 END), 0) AS amount_paid
FROM payments
WHERE order_id = @demo_existing_order_id;

-- A payment process would validate the balance here, then INSERT into payments.
-- This demonstration releases the lock without changing data.
ROLLBACK;

-- 4. Persistent COMMIT pattern for the application workflow.
-- Uncomment only when a permanent test order is intended.
-- START TRANSACTION;
-- INSERT INTO lab_test (patient_id, test_id, order_date, status)
-- VALUES (@demo_patient_id, @demo_cbc_test_id, CURRENT_DATE, 'PENDING');
-- SET @committed_order_id = LAST_INSERT_ID();
-- INSERT INTO cbc (order_id) VALUES (@committed_order_id);
-- COMMIT;

-- 5. Error-handling pattern.
-- A foreign-key or check-constraint error must be followed by ROLLBACK.
-- START TRANSACTION;
-- INSERT INTO lab_test (patient_id, test_id, order_date, status)
-- VALUES ('INVALID-PATIENT', @demo_cbc_test_id, CURRENT_DATE, 'PENDING');
-- ROLLBACK;
