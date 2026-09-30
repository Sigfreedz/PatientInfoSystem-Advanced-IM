-- =====================================================
-- CLEAN SQL BUNDLE (LIVE SCHEMA ONLY)
-- =====================================================
-- Run in this order from MySQL client:
--   SOURCE database/renamed_schema.sql;
--   SOURCE database/new_seed.sql;
--   SOURCE database/rolve_views.sql;
--   SOURCE database/encryption.sql;
--   SOURCE database/app_auth.sql;
--   SOURCE database/role_priveleges.sql;
--   SOURCE database/transaction_demo.sql;
--   SOURCE database/optimization_demo.sql;
--
-- Smoke checks (all live object names):

USE `patient_db`;

SELECT COUNT(*) AS patient_count FROM clinic_patients;
SELECT COUNT(*) AS order_count FROM lab_test;
SELECT COUNT(*) AS payment_count FROM payments;

SELECT * FROM v_frontdesk_dashboard LIMIT 5;
SELECT * FROM v_labtech_workspace LIMIT 5;
SELECT * FROM v_doctor_clinical_view LIMIT 5;

-- Example live joins used by the app:
SELECT o.order_id, o.patient_id, t.test_name, t.price, o.status
FROM lab_test o
JOIN lab_test_catalog t ON t.test_id = o.test_id
ORDER BY o.order_date DESC, o.order_id DESC
LIMIT 10;
