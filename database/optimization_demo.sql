-- =====================================================
-- OPTIMIZATION DEMO (INDEXING + EXPLAIN / EXPLAIN ANALYZE)
-- =====================================================
-- Targets the three heavier app queries:
-- 1) /patient-info
-- 2) /billing/<patient_id>
-- 3) /payments

USE `patient_db`;

SET @sample_patient_id := (SELECT patient_id FROM clinic_patients ORDER BY patient_id LIMIT 1);

-- -----------------------------------------------------
-- BASELINE EXPLAIN PLANS (before additional indexes)
-- -----------------------------------------------------

EXPLAIN FORMAT=TREE
SELECT p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address,
       p.registered_at, GROUP_CONCAT(DISTINCT t.test_name) AS tests_taken, MAX(o.order_date) AS last_visit
FROM clinic_patients p
LEFT JOIN lab_test o ON p.patient_id = o.patient_id
LEFT JOIN lab_test_catalog t ON o.test_id = t.test_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address, p.registered_at
ORDER BY p.last_name, p.first_name;

EXPLAIN FORMAT=TREE
SELECT o.order_id, o.order_date, t.test_name, t.price,
       COALESCE(SUM(CASE WHEN pay.status <> 'REFUNDED' THEN pay.amount_paid ELSE 0 END), 0) AS paid
FROM lab_test o
JOIN lab_test_catalog t ON o.test_id = t.test_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
WHERE o.patient_id = @sample_patient_id
GROUP BY o.order_id, o.order_date, t.test_name, t.price
ORDER BY o.order_date;

EXPLAIN FORMAT=TREE
SELECT pay.payment_id, pay.order_id, pay.amount_paid, pay.payment_method,
       pay.payment_date, pay.status, o.patient_id,
       CONCAT(cp.first_name, ' ', cp.last_name) AS patient_name,
       tc.test_name
FROM payments pay
JOIN lab_test o ON pay.order_id = o.order_id
JOIN clinic_patients cp ON o.patient_id = cp.patient_id
JOIN lab_test_catalog tc ON o.test_id = tc.test_id
ORDER BY pay.payment_date DESC, pay.payment_id DESC;

-- -----------------------------------------------------
-- ADDITIONAL PERFORMANCE INDEXES (idempotent)
-- -----------------------------------------------------

DROP PROCEDURE IF EXISTS `ensure_optimization_indexes`;
DELIMITER //
CREATE PROCEDURE `ensure_optimization_indexes`()
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'clinic_patients'
      AND INDEX_NAME = 'idx_clinic_patients_name'
  ) THEN
    ALTER TABLE clinic_patients
      ADD INDEX idx_clinic_patients_name (last_name, first_name);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'lab_test'
      AND INDEX_NAME = 'idx_lab_test_patient_order_date'
  ) THEN
    ALTER TABLE lab_test
      ADD INDEX idx_lab_test_patient_order_date (patient_id, order_date);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND INDEX_NAME = 'idx_payments_date_id'
  ) THEN
    ALTER TABLE payments
      ADD INDEX idx_payments_date_id (payment_date, payment_id);
  END IF;
END//
DELIMITER ;

CALL ensure_optimization_indexes();
DROP PROCEDURE IF EXISTS `ensure_optimization_indexes`;

-- -----------------------------------------------------
-- POST-INDEX PLAN CHECKS
-- -----------------------------------------------------

EXPLAIN FORMAT=TREE
SELECT p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address,
       p.registered_at, GROUP_CONCAT(DISTINCT t.test_name) AS tests_taken, MAX(o.order_date) AS last_visit
FROM clinic_patients p
LEFT JOIN lab_test o ON p.patient_id = o.patient_id
LEFT JOIN lab_test_catalog t ON o.test_id = t.test_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address, p.registered_at
ORDER BY p.last_name, p.first_name;

EXPLAIN FORMAT=TREE
SELECT o.order_id, o.order_date, t.test_name, t.price,
       COALESCE(SUM(CASE WHEN pay.status <> 'REFUNDED' THEN pay.amount_paid ELSE 0 END), 0) AS paid
FROM lab_test o
JOIN lab_test_catalog t ON o.test_id = t.test_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
WHERE o.patient_id = @sample_patient_id
GROUP BY o.order_id, o.order_date, t.test_name, t.price
ORDER BY o.order_date;

EXPLAIN FORMAT=TREE
SELECT pay.payment_id, pay.order_id, pay.amount_paid, pay.payment_method,
       pay.payment_date, pay.status, o.patient_id,
       CONCAT(cp.first_name, ' ', cp.last_name) AS patient_name,
       tc.test_name
FROM payments pay
JOIN lab_test o ON pay.order_id = o.order_id
JOIN clinic_patients cp ON o.patient_id = cp.patient_id
JOIN lab_test_catalog tc ON o.test_id = tc.test_id
ORDER BY pay.payment_date DESC, pay.payment_id DESC;

-- Optional runtime verification on realistic data volumes
EXPLAIN ANALYZE
SELECT pay.payment_id, pay.order_id, pay.amount_paid, pay.payment_method,
       pay.payment_date, pay.status, o.patient_id,
       CONCAT(cp.first_name, ' ', cp.last_name) AS patient_name,
       tc.test_name
FROM payments pay
JOIN lab_test o ON pay.order_id = o.order_id
JOIN clinic_patients cp ON o.patient_id = cp.patient_id
JOIN lab_test_catalog tc ON o.test_id = tc.test_id
ORDER BY pay.payment_date DESC, pay.payment_id DESC;
