-- Sample CRUD workflow for the renamed patient_db schema.
-- Run renamed_schema.sql and load the catalog first.

USE `patient_db`;

START TRANSACTION;

-- CREATE: admit/register a patient.
INSERT INTO `clinic_patients`
    (`patient_id`, `first_name`, `last_name`, `age`, `sex`, `address`, `contact`)
VALUES
    ('PAT-021', 'Elena', 'Garcia', 28, 'F', 'Makati City, Metro Manila', '09170000021');

SET @patient_id = 'PAT-021';

-- READ: confirm the admission record.
SELECT *
FROM `clinic_patients`
WHERE `patient_id` = @patient_id;

-- CREATE: order a CBC for the admitted patient.
INSERT INTO `lab_test` (`patient_id`, `test_id`, `order_date`, `status`)
SELECT @patient_id, `test_id`, CURRENT_DATE, 'PENDING'
FROM `lab_test_catalog`
WHERE `test_name` = 'CBC';

SET @cbc_order_id = LAST_INSERT_ID();

-- CREATE: order a urinalysis for the same patient.
INSERT INTO `lab_test` (`patient_id`, `test_id`, `order_date`, `status`)
SELECT @patient_id, `test_id`, CURRENT_DATE, 'PENDING'
FROM `lab_test_catalog`
WHERE `test_name` = 'URINALYSIS';

SET @urinalysis_order_id = LAST_INSERT_ID();

-- READ: list the patient's test orders and catalog prices.
SELECT
    o.`order_id`,
    o.`order_date`,
    t.`test_name`,
    t.`price`,
    o.`status`
FROM `lab_test` AS o
JOIN `lab_test_catalog` AS t ON t.`test_id` = o.`test_id`
WHERE o.`patient_id` = @patient_id
ORDER BY o.`order_id`;

-- CREATE: record payment for the CBC order.
INSERT INTO `payments`
    (`order_id`, `amount_paid`, `payment_method`, `payment_date`, `receipt_number`, `status`)
SELECT
    @cbc_order_id,
    `price`,
    'CASH',
    CURRENT_TIMESTAMP,
    'RCPT-0021',
    'PAID'
FROM `lab_test_catalog` AS t
JOIN `lab_test` AS o ON o.`test_id` = t.`test_id`
WHERE o.`order_id` = @cbc_order_id;

-- UPDATE: correct the patient's contact information.
UPDATE `clinic_patients`
SET `contact` = '09170000099',
    `address` = 'Makati City, Metro Manila'
WHERE `patient_id` = @patient_id;

-- UPDATE: mark the CBC as completed after results are available.
UPDATE `lab_test`
SET `status` = 'COMPLETED'
WHERE `order_id` = @cbc_order_id
  AND `patient_id` = @patient_id;

-- CREATE: save the CBC result for the completed order.
INSERT INTO `cbc`
    (`order_id`, `wbc`, `rbc`, `hemoglobin`, `hematocrit`, `platelets`,
     `mcv`, `mch`, `neutrophils`, `lymphocytes`, `monocytes`, `eosinophils`, `basophils`)
VALUES
    (@cbc_order_id, 6.80, 4.75, 13.40, 40.10, 275,
     86, 29, 56.00, 35.00, 5.00, 3.00, 1.00);

-- READ: review the patient's current orders, payments, and CBC result.
SELECT
    p.`patient_id`,
    CONCAT(p.`first_name`, ' ', p.`last_name`) AS `patient_name`,
    t.`test_name`,
    o.`status` AS `order_status`,
    pay.`amount_paid`,
    pay.`payment_method`,
    pay.`status` AS `payment_status`,
    c.`hemoglobin`,
    c.`wbc`
FROM `clinic_patients` AS p
JOIN `lab_test` AS o ON o.`patient_id` = p.`patient_id`
JOIN `lab_test_catalog` AS t ON t.`test_id` = o.`test_id`
LEFT JOIN `payments` AS pay ON pay.`order_id` = o.`order_id`
LEFT JOIN `cbc` AS c ON c.`order_id` = o.`order_id`
WHERE p.`patient_id` = @patient_id
ORDER BY o.`order_id`;

-- DELETE: examples only. Uncomment deliberately when cleanup is required.
-- DELETE FROM `payments` WHERE `order_id` IN (@cbc_order_id, @urinalysis_order_id);
-- DELETE FROM `lab_test` WHERE `patient_id` = @patient_id;
-- DELETE FROM `clinic_patients` WHERE `patient_id` = @patient_id;

COMMIT;