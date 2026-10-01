-- Native MySQL 8.0 role-based access control for patient_db.
-- Demo passwords are intentionally visible for classroom/panel demonstration only.

USE `patient_db`;

-- STEP 1: Create the five database roles.
-- Dropping first makes this script re-runnable; it also removes old role grants.
DROP ROLE IF EXISTS
  'role_admin',
  'role_front_desk',
  'role_lab_tech',
  'role_doctor',
  'role_patient';

CREATE ROLE
  'role_admin',
  'role_front_desk',
  'role_lab_tech',
  'role_doctor',
  'role_patient';

-- STEP 2: Grant privileges by job responsibility.

-- Administrators need full database control for maintenance, recovery, and auditing.
GRANT ALL PRIVILEGES ON `patient_db`.* TO 'role_admin';

-- Front desk staff register and maintain patient demographics, but do not read medical result tables.
GRANT SELECT, INSERT, UPDATE ON `patient_db`.`clinic_patients` TO 'role_front_desk';
-- Front desk staff create and update orders, but cannot delete the order history.
GRANT SELECT, INSERT, UPDATE ON `patient_db`.`lab_test` TO 'role_front_desk';
-- Front desk staff need prices to quote tests and calculate bills.
GRANT SELECT ON `patient_db`.`lab_test_catalog` TO 'role_front_desk';
-- Front desk staff record payments, but do not need to delete financial history.
GRANT SELECT, INSERT ON `patient_db`.`payments` TO 'role_front_desk';
-- Grant the filtered dashboard view instead of clinical result tables because billing needs order totals/status only.
GRANT SELECT ON `patient_db`.`v_frontdesk_dashboard` TO 'role_front_desk';

-- Laboratory staff read and encode CBC results without access to payment data.
GRANT SELECT, UPDATE ON `patient_db`.`cbc` TO 'role_lab_tech';
-- Laboratory staff read and encode urinalysis results without access to payment data.
GRANT SELECT, UPDATE ON `patient_db`.`urinalysis` TO 'role_lab_tech';
-- Laboratory staff read and encode fecalysis results without access to payment data.
GRANT SELECT, UPDATE ON `patient_db`.`fecalysis` TO 'role_lab_tech';
-- Laboratory staff initially receive order update capability for status/verification workflow; STEP 5 tightens this grant.
GRANT SELECT, UPDATE ON `patient_db`.`lab_test` TO 'role_lab_tech';
-- Grant the filtered lab workspace view so technicians see work-relevant indicators without broad patient or payment access.
GRANT SELECT ON `patient_db`.`v_labtech_workspace` TO 'role_lab_tech';

-- Doctors receive clinical projections and can create or update lab orders, but have no payment privileges.
GRANT SELECT ON `patient_db`.`v_doctor_clinical_view` TO 'role_doctor';
-- Doctors need patient demographics for clinical context, but this is SELECT-only.
GRANT SELECT ON `patient_db`.`clinic_patients` TO 'role_doctor';
GRANT SELECT, INSERT, UPDATE ON `patient_db`.`lab_test` TO 'role_doctor';
-- Patients receive only the portal projection; they get no base-table access.
GRANT SELECT ON `patient_db`.`v_patient_portal` TO 'role_patient';

-- STEP 3: Create one demo MySQL user for each role.
-- Drop guards make the demo accounts re-runnable; replace these passwords outside a classroom environment.
DROP USER IF EXISTS
  'user_admin'@'localhost',
  'user_frontdesk'@'localhost',
  'user_labtech'@'localhost',
  'user_doctor'@'localhost',
  'user_patient'@'localhost';

CREATE USER 'user_admin'@'localhost' IDENTIFIED BY 'Admin@2026!';
CREATE USER 'user_frontdesk'@'localhost' IDENTIFIED BY 'Front@2026!';
CREATE USER 'user_labtech'@'localhost' IDENTIFIED BY 'Lab@2026!';
CREATE USER 'user_doctor'@'localhost' IDENTIFIED BY 'Doc@2026!';
CREATE USER 'user_patient'@'localhost' IDENTIFIED BY 'Pat@2026!';

-- STEP 4: Assign roles and activate them at login.
-- The administrator account receives the full-control role for database operations.
GRANT 'role_admin' TO 'user_admin'@'localhost';
-- The front-desk account receives only registration, order, billing, and dashboard privileges.
GRANT 'role_front_desk' TO 'user_frontdesk'@'localhost';
-- The laboratory account receives result-encoding and lab-workspace privileges only.
GRANT 'role_lab_tech' TO 'user_labtech'@'localhost';
-- The doctor account receives read-only clinical privileges only.
GRANT 'role_doctor' TO 'user_doctor'@'localhost';
-- The patient account receives only the patient portal view privilege.
GRANT 'role_patient' TO 'user_patient'@'localhost';

-- Make every assigned role active automatically after the user logs in.
SET DEFAULT ROLE ALL TO 'user_admin'@'localhost';
SET DEFAULT ROLE ALL TO 'user_frontdesk'@'localhost';
SET DEFAULT ROLE ALL TO 'user_labtech'@'localhost';
SET DEFAULT ROLE ALL TO 'user_doctor'@'localhost';
SET DEFAULT ROLE ALL TO 'user_patient'@'localhost';

-- STEP 5: Demonstrate dynamic privilege tightening with REVOKE.
-- Lab technicians should request order-status changes through an approved workflow rather than update orders directly.
REVOKE UPDATE ON `patient_db`.`lab_test` FROM 'role_lab_tech';
-- Prove that the role no longer has direct lab_test UPDATE privilege.
SHOW GRANTS FOR 'role_lab_tech';

-- Grant a temporary direct catalog privilege to the lab user, then remove it to demonstrate user-level REVOKE.
GRANT SELECT ON `patient_db`.`lab_test_catalog` TO 'user_labtech'@'localhost';
-- User-level tightening removes the temporary exception while preserving the role design.
REVOKE SELECT ON `patient_db`.`lab_test_catalog` FROM 'user_labtech'@'localhost';
-- Prove that the temporary user-level grant is gone.
SHOW GRANTS FOR 'user_labtech'@'localhost';

-- STEP 6: Live access-control demonstration.
-- Run each block after connecting as the indicated localhost user.
-- Intentional denied commands are comments so this setup script remains executable.
-- Expected denied statements should return MySQL ERROR 1142 (command denied).

-- A) user_labtech: result access is allowed; money and demographic writes are denied.
-- SET ROLE ALL;
-- SELECT * FROM `patient_db`.`v_labtech_workspace` LIMIT 3;
-- Expected: ALLOWED. Rubric: filtered lab workspace is readable.
-- UPDATE `patient_db`.`cbc` SET `hemoglobin` = 13.0 WHERE `order_id` = <id>;
-- Expected: ALLOWED. Rubric: lab technicians can encode CBC results.
-- SELECT * FROM `patient_db`.`payments`;
-- Expected: ERROR 1142 DENIED. Rubric: lab_tech has no payment privilege.
-- UPDATE `patient_db`.`clinic_patients` SET `address` = 'x' WHERE `patient_id` = '<id>';
-- Expected: ERROR 1142 DENIED. Rubric: lab_tech cannot edit patient demographics.
-- UPDATE `patient_db`.`lab_test` SET `status` = 'COMPLETED' WHERE `order_id` = <id>;
-- Expected: ERROR 1142 DENIED after STEP 5 REVOKE. Rubric: direct status updates were tightened.

-- B) user_frontdesk: registration and billing projection are allowed; clinical tables are denied.
-- SET ROLE ALL;
-- INSERT INTO `patient_db`.`clinic_patients`
--   (`patient_id`, `first_name`, `last_name`, `age`, `sex`, `contact`)
-- VALUES ('DEMO-FD', 'Demo', 'Frontdesk', 30, 'F', '09170009999');
-- Expected: ALLOWED. Rubric: front desk can register patients.
-- SELECT * FROM `patient_db`.`v_frontdesk_dashboard` LIMIT 3;
-- Expected: ALLOWED. Rubric: front desk can view billing/order projections.
-- SELECT * FROM `patient_db`.`cbc`;
-- Expected: ERROR 1142 DENIED. Rubric: front desk never receives clinical-result SELECT.

-- C) user_doctor: clinical reads and lab-order writes are allowed; money access is denied.
-- SET ROLE ALL;
-- SELECT * FROM `patient_db`.`v_doctor_clinical_view` WHERE `patient_id` = '<id>';
-- Expected: ALLOWED. Rubric: doctor receives read-only clinical projection.
-- INSERT INTO `patient_db`.`lab_test` (`patient_id`, `test_id`, `order_date`, `status`)
-- VALUES ('<patient_id>', <test_id>, CURRENT_DATE, 'PENDING');
-- Expected: ALLOWED. Rubric: doctor can create lab orders.
-- UPDATE `patient_db`.`lab_test` SET `status` = 'COMPLETED' WHERE `order_id` = <id>;
-- Expected: ALLOWED. Rubric: doctor can update lab orders.
-- INSERT INTO `patient_db`.`payments` (`order_id`, `amount_paid`, `payment_method`)
-- VALUES (<id>, 1.00, 'CASH');
-- Expected: ERROR 1142 DENIED. Rubric: doctor has no money privilege.
-- UPDATE `patient_db`.`clinic_patients` SET `address` = 'x' WHERE `patient_id` = '<id>';
-- Expected: ERROR 1142 DENIED. Rubric: doctor is read-only.

-- D) user_patient: only the portal view is granted.
-- SET ROLE ALL;
-- SET @current_patient_id = 'PAT-004';
-- SELECT * FROM `patient_db`.`v_patient_portal`;
-- Expected: ALLOWED for the portal projection. Rubric: patient has no base-table access.
-- Note: the current v_patient_portal definition filters COMPLETED orders but does not
-- consume @current_patient_id. Application code or a revised filtered view must enforce own-patient filtering.
-- SELECT * FROM `patient_db`.`clinic_patients`;
-- Expected: ERROR 1142 DENIED. Rubric: patient cannot browse all patient records.

-- E) user_admin: unrestricted database administration is allowed.
-- SET ROLE ALL;
-- SELECT * FROM `patient_db`.`v_admin_audit_log`;
-- Expected: ALLOWED. Rubric: administrator can audit all order/payment projections.
-- UPDATE `patient_db`.`lab_test` SET `status` = 'COMPLETED' WHERE `order_id` = <id>;
-- Expected: ALLOWED. Rubric: administrator has full DML control.

-- STEP 7: Verification and audit queries.
-- Show effective grants for every demo user.
SHOW GRANTS FOR 'user_admin'@'localhost';
SHOW GRANTS FOR 'user_frontdesk'@'localhost';
SHOW GRANTS FOR 'user_labtech'@'localhost';
SHOW GRANTS FOR 'user_doctor'@'localhost';
SHOW GRANTS FOR 'user_patient'@'localhost';

-- Show role-to-user assignments maintained by MySQL.
SELECT *
FROM `mysql`.`role_edges`;

-- Show table/view privilege rows granted to roles in patient_db.
SELECT
  `GRANTEE`,
  `TABLE_SCHEMA`,
  `TABLE_NAME`,
  `PRIVILEGE_TYPE`
FROM `information_schema`.`TABLE_PRIVILEGES`
WHERE `TABLE_SCHEMA` = 'patient_db'
  AND `GRANTEE` LIKE '%role_%'
ORDER BY `GRANTEE`, `TABLE_NAME`, `PRIVILEGE_TYPE`;

-- Summary privilege matrix for every role and patient_db object.
SELECT
  `GRANTEE` AS `role_name`,
  `TABLE_NAME` AS `object_name`,
  GROUP_CONCAT(DISTINCT `PRIVILEGE_TYPE` ORDER BY `PRIVILEGE_TYPE` SEPARATOR ', ') AS `privileges`
FROM `information_schema`.`TABLE_PRIVILEGES`
WHERE `TABLE_SCHEMA` = 'patient_db'
  AND `GRANTEE` LIKE '%role_%'
GROUP BY `GRANTEE`, `TABLE_NAME`
ORDER BY `GRANTEE`, `TABLE_NAME`;

-- How to present this:
-- 1. Connect as user_labtech and run SELECT * FROM patient_db.payments;
--    The panel should see ERROR 1142 because lab_tech has no money access.
-- 2. Connect as user_frontdesk and run SELECT * FROM patient_db.cbc;
--    The panel should see ERROR 1142 because front_desk has no clinical access.
-- 3. Connect as user_doctor and run UPDATE patient_db.clinic_patients SET address='x' WHERE patient_id='PAT-001';
--    The panel should see ERROR 1142 because doctor is read-only.

FLUSH PRIVILEGES;
