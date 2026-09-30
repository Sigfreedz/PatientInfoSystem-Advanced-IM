-- =====================================================
-- TRANSACTION DEMO (ACID / COMMIT / ROLLBACK)
-- =====================================================
-- Purpose:
-- 1) Demonstrate a successful multi-step transaction that COMMITs.
-- 2) Demonstrate a forced-failure transaction that ROLLBACKs.
-- 3) Demonstrate consistency locking via SELECT ... FOR UPDATE.

USE `patient_db`;
SET autocommit = 0;
SET @secret_key = 'ClinicSecretEncryptionKey2026!';
SET @@block_encryption_mode = 'aes-256-cbc';

-- -----------------------------------------------------
-- SCENARIO A: Successful transaction (COMMIT)
-- -----------------------------------------------------

DROP PROCEDURE IF EXISTS `demo_payment_commit`;
DELIMITER //
CREATE PROCEDURE `demo_payment_commit`()
BEGIN
  DECLARE v_order_id INT;
  DECLARE v_demo_receipt VARCHAR(64);

  SELECT MIN(order_id) INTO v_order_id FROM lab_test;
  IF v_order_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No lab_test rows found for commit demo.';
  END IF;

  SET v_demo_receipt = CONCAT('TX-COMMIT-', UNIX_TIMESTAMP());

  START TRANSACTION;

  SELECT t.price AS total_amount
  FROM lab_test o
  JOIN lab_test_catalog t ON t.test_id = o.test_id
  WHERE o.order_id = v_order_id
  FOR UPDATE;

  SELECT COALESCE(SUM(CASE WHEN status <> 'REFUNDED' THEN amount_paid ELSE 0 END), 0) AS already_paid
  FROM payments
  WHERE order_id = v_order_id
  FOR UPDATE;

  SET @row_iv = RANDOM_BYTES(16);
  INSERT INTO payments (
    order_id, amount_paid, payment_method, receipt_number,
    receipt_number_encrypted, encryption_iv, receipt_token_hash, status
  )
  VALUES (
    v_order_id, 1.00, 'CASH', v_demo_receipt,
    AES_ENCRYPT(v_demo_receipt, @secret_key, @row_iv), @row_iv, SHA2(v_demo_receipt, 256), 'PAID'
  );

  COMMIT;

  SELECT 'COMMIT executed successfully.' AS result, v_demo_receipt AS receipt_number;
  SELECT payment_id, order_id, amount_paid, status, payment_date
  FROM payments
  WHERE receipt_number = v_demo_receipt;
END//
DELIMITER ;

CALL `demo_payment_commit`();
DROP PROCEDURE IF EXISTS `demo_payment_commit`;

-- -----------------------------------------------------
-- SCENARIO B: Forced failure transaction (ROLLBACK)
-- -----------------------------------------------------

DROP PROCEDURE IF EXISTS `demo_payment_rollback`;
DELIMITER //
CREATE PROCEDURE `demo_payment_rollback`()
BEGIN
  DECLARE v_order_id INT;
  DECLARE v_total_amount DECIMAL(10,2);
  DECLARE v_already_paid DECIMAL(10,2);
  DECLARE v_invalid_amount DECIMAL(10,2);
  DECLARE v_demo_receipt VARCHAR(64);

  SELECT MIN(order_id) INTO v_order_id FROM lab_test;
  IF v_order_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No lab_test rows found for rollback demo.';
  END IF;

  START TRANSACTION;

  SELECT t.price INTO v_total_amount
  FROM lab_test o
  JOIN lab_test_catalog t ON t.test_id = o.test_id
  WHERE o.order_id = v_order_id
  FOR UPDATE;

  SELECT COALESCE(SUM(CASE WHEN status <> 'REFUNDED' THEN amount_paid ELSE 0 END), 0)
  INTO v_already_paid
  FROM payments
  WHERE order_id = v_order_id
  FOR UPDATE;

  SET v_invalid_amount = v_total_amount;
  SET v_demo_receipt = CONCAT('TX-ROLLBACK-', UNIX_TIMESTAMP());

  IF (v_already_paid + v_invalid_amount) > v_total_amount THEN
    ROLLBACK;
    SELECT 'ROLLBACK executed: payment would exceed allowed amount.' AS result,
           v_order_id AS order_id,
           v_total_amount AS total_amount,
           v_already_paid AS already_paid,
           v_invalid_amount AS attempted_amount;
  ELSE
    SET @row_iv = RANDOM_BYTES(16);
    INSERT INTO payments (
      order_id, amount_paid, payment_method, receipt_number,
      receipt_number_encrypted, encryption_iv, receipt_token_hash, status
    )
    VALUES (
      v_order_id, v_invalid_amount, 'CASH', v_demo_receipt,
      AES_ENCRYPT(v_demo_receipt, @secret_key, @row_iv), @row_iv, SHA2(v_demo_receipt, 256), 'PAID'
    );

    COMMIT;
    SELECT 'Unexpected COMMIT path: adjust seed data for rollback demonstration.' AS result,
           v_demo_receipt AS receipt_number;
  END IF;

  SELECT payment_id, receipt_number, amount_paid
  FROM payments
  WHERE receipt_number LIKE 'TX-ROLLBACK-%'
  ORDER BY payment_id DESC
  LIMIT 5;
END//
DELIMITER ;

CALL `demo_payment_rollback`();
DROP PROCEDURE IF EXISTS `demo_payment_rollback`;

SET autocommit = 1;
