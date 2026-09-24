-- Role-based views for the live patient_db schema.
-- The filename is kept as requested: rolve_views.sql.

USE `patient_db`;

-- 1. PATIENT VIEW: Released results for patient portal use.
-- MySQL views cannot reference @current_patient_id. The application should
-- filter this view by patient_id after setting its authenticated patient.
CREATE OR REPLACE VIEW `v_patient_portal` AS
SELECT
  p.patient_id,
  p.first_name,
  p.last_name,
  o.order_date,
  t.test_name,
  o.status
FROM `clinic_patients` p
JOIN `lab_test` o ON p.patient_id = o.patient_id
JOIN `lab_test_catalog` t ON o.test_id = t.test_id
WHERE o.status = 'COMPLETED';

-- 2. FRONT DESK VIEW: Patient orders and billing, without clinical results.
-- The live schema stores the test price in lab_test_catalog, not total_amount
-- in lab_test, so price is exposed using the requested total_amount alias.
CREATE OR REPLACE VIEW `v_frontdesk_dashboard` AS
SELECT
  p.patient_id,
  CONCAT(p.first_name, ' ', p.last_name) AS name,
  t.test_name,
  t.price AS total_amount,
  o.status,
  o.order_date
FROM `clinic_patients` p
JOIN `lab_test` o ON p.patient_id = o.patient_id
JOIN `lab_test_catalog` t ON o.test_id = t.test_id;

-- 3. LAB TECH VIEW: Work queue and selected result fields, without billing.
CREATE OR REPLACE VIEW `v_labtech_workspace` AS
SELECT
  o.order_id,
  p.first_name,
  p.last_name,
  t.test_name,
  o.status,
  c.hemoglobin,
  c.wbc,
  u.protein,
  f.parasite_id
FROM `lab_test` o
JOIN `clinic_patients` p ON o.patient_id = p.patient_id
JOIN `lab_test_catalog` t ON o.test_id = t.test_id
LEFT JOIN `cbc` c ON o.order_id = c.order_id
LEFT JOIN `urinalysis` u ON o.order_id = u.order_id
LEFT JOIN `fecalysis` f ON o.order_id = f.order_id
WHERE o.status IN ('PENDING', 'COMPLETED');

-- 4. DOCTOR VIEW: Clinical history without billing details.
CREATE OR REPLACE VIEW `v_doctor_clinical_view` AS
SELECT
  p.patient_id,
  CONCAT(p.first_name, ' ', p.last_name) AS name,
  p.age,
  p.sex,
  t.test_name,
  o.order_date,
  c.hemoglobin,
  u.protein,
  f.parasite_id
FROM `clinic_patients` p
JOIN `lab_test` o ON p.patient_id = o.patient_id
JOIN `lab_test_catalog` t ON o.test_id = t.test_id
LEFT JOIN `cbc` c ON o.order_id = c.order_id
LEFT JOIN `urinalysis` u ON o.order_id = u.order_id
LEFT JOIN `fecalysis` f ON o.order_id = f.order_id;

-- 5. ADMIN VIEW: Live order and payment audit information.
-- The live schema has no audit_logs table, so this view uses the available
-- order, patient, test, and payment data instead.
CREATE OR REPLACE VIEW `v_admin_audit_log` AS
SELECT
  o.order_id,
  o.patient_id,
  CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
  t.test_name,
  t.price AS total_amount,
  o.status AS order_status,
  o.order_date,
  pay.payment_id,
  pay.amount_paid,
  pay.payment_method,
  pay.payment_date,
  pay.receipt_number,
  pay.status AS payment_status,
  o.created_at AS order_created_at,
  o.updated_at AS order_updated_at
FROM `lab_test` o
JOIN `clinic_patients` p ON o.patient_id = p.patient_id
JOIN `lab_test_catalog` t ON o.test_id = t.test_id
LEFT JOIN `payments` pay ON o.order_id = pay.order_id;

USE patient_db;

SELECT * FROM v_patient_portal;
SELECT * FROM v_frontdesk_dashboard;
SELECT * FROM v_labtech_workspace;
SELECT * FROM v_doctor_clinical_view;
SELECT * FROM v_admin_audit_log;