-- AES-256-CBC encryption for sensitive patient and payment fields.
-- MySQL 8.0 only. Run this script while connected to the patient_db database.

USE `patient_db`;

-- Shared application secret. Store this outside source control in production.
SET @secret_key = 'ClinicSecretEncryptionKey2026!';

-- STEP 1: Set encryption mode.
SET @@block_encryption_mode = 'aes-256-cbc';

-- STEP 2: Add encrypted storage, per-row IVs, and indexed lookup hashes.
-- The plaintext columns remain temporarily for application verification.
-- TODO: drop plaintext columns after the application has been verified.
-- The existing plaintext UNIQUE keys remain for now. Once encrypted values use
-- random IVs, ciphertext itself cannot provide deterministic uniqueness; the
-- SHA2 token hash is for lookup, while the old keys still enforce plaintext
-- uniqueness during this transition.

DROP PROCEDURE IF EXISTS `ensure_encryption_columns`;
DELIMITER //
CREATE PROCEDURE `ensure_encryption_columns`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'clinic_patients'
      AND COLUMN_NAME = 'contact_encrypted'
  ) THEN
    -- Holds the raw encrypted binary string
    ALTER TABLE `clinic_patients`
      ADD COLUMN `contact_encrypted` VARBINARY(256) NULL
        COMMENT 'Holds the raw encrypted binary string';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'clinic_patients'
      AND COLUMN_NAME = 'encryption_iv'
  ) THEN
    -- Holds the 16-byte initialization vector
    ALTER TABLE `clinic_patients`
      ADD COLUMN `encryption_iv` VARBINARY(16) NULL
        COMMENT 'Holds the 16-byte initialization vector';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'clinic_patients'
      AND COLUMN_NAME = 'contact_token_hash'
  ) THEN
    -- One-way hash allowing fast, indexed WHERE lookups
    ALTER TABLE `clinic_patients`
      ADD COLUMN `contact_token_hash` CHAR(64) NULL
        COMMENT 'One-way hash allowing fast, indexed WHERE lookups';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'clinic_patients'
      AND INDEX_NAME = 'idx_clinic_patients_contact_token_hash'
  ) THEN
    ALTER TABLE `clinic_patients`
      ADD INDEX `idx_clinic_patients_contact_token_hash` (`contact_token_hash`);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND COLUMN_NAME = 'receipt_number_encrypted'
  ) THEN
    -- Holds the raw encrypted binary string
    ALTER TABLE `payments`
      ADD COLUMN `receipt_number_encrypted` VARBINARY(256) NULL
        COMMENT 'Holds the raw encrypted binary string';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND COLUMN_NAME = 'encryption_iv'
  ) THEN
    -- Holds the 16-byte initialization vector
    ALTER TABLE `payments`
      ADD COLUMN `encryption_iv` VARBINARY(16) NULL
        COMMENT 'Holds the 16-byte initialization vector';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND COLUMN_NAME = 'receipt_token_hash'
  ) THEN
    -- One-way hash allowing fast, indexed WHERE lookups
    ALTER TABLE `payments`
      ADD COLUMN `receipt_token_hash` CHAR(64) NULL
        COMMENT 'One-way hash allowing fast, indexed WHERE lookups';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND INDEX_NAME = 'idx_payments_receipt_token_hash'
  ) THEN
    ALTER TABLE `payments`
      ADD INDEX `idx_payments_receipt_token_hash` (`receipt_token_hash`);
  END IF;
END//
DELIMITER ;

CALL `ensure_encryption_columns`();
DROP PROCEDURE IF EXISTS `ensure_encryption_columns`;

-- STEP 2 CHECKER: Confirm every encrypted column and lookup index exists
-- before the migration procedure is created or any data is changed.
DROP PROCEDURE IF EXISTS `check_encryption_columns`;
DELIMITER //
CREATE PROCEDURE `check_encryption_columns`()
BEGIN
  DECLARE v_column_count INT DEFAULT 0;
  DECLARE v_index_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_column_count
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND (
      (TABLE_NAME = 'clinic_patients' AND COLUMN_NAME IN
        ('contact_encrypted', 'encryption_iv', 'contact_token_hash'))
      OR
      (TABLE_NAME = 'payments' AND COLUMN_NAME IN
        ('receipt_number_encrypted', 'encryption_iv', 'receipt_token_hash'))
    );

  SELECT COUNT(*) INTO v_index_count
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND INDEX_NAME IN (
      'idx_clinic_patients_contact_token_hash',
      'idx_payments_receipt_token_hash'
    );

  IF v_column_count <> 6 OR v_index_count <> 2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'STEP 2 FAILED: encryption columns or indexes are missing';
  END IF;

  SELECT 'STEP 2 SUCCESS: six encryption columns and two lookup indexes verified'
    AS `step_2_status`,
    v_column_count AS `verified_columns`,
    v_index_count AS `verified_indexes`;
END//
DELIMITER ;

CALL `check_encryption_columns`();
DROP PROCEDURE IF EXISTS `check_encryption_columns`;


-- STEP 3: Migrate existing plaintext values.
-- A cursor is used so one RANDOM_BYTES(16) value is generated per row and the
-- exact same IV is passed to AES_ENCRYPT and stored beside its ciphertext.
-- IV-per-row prevents equal plaintexts from producing equal ciphertexts;
-- SHA2 provides a non-reversible lookup token that remains indexable without
-- decrypting rows. The transaction makes the two table migrations atomic.

DROP PROCEDURE IF EXISTS `migrate_encrypted_values`;
DELIMITER //
CREATE PROCEDURE `migrate_encrypted_values`()
BEGIN
  DECLARE v_done BOOLEAN DEFAULT FALSE;
  DECLARE v_patient_id VARCHAR(10);
  DECLARE v_contact VARCHAR(20);
  DECLARE v_payment_id INT;
  DECLARE v_receipt_number VARCHAR(50);

  DECLARE patient_cursor CURSOR FOR
    SELECT `patient_id`, `contact`
    FROM `clinic_patients`
    WHERE `contact` IS NOT NULL
      AND `contact_encrypted` IS NULL;
  DECLARE payment_cursor CURSOR FOR
    SELECT `payment_id`, `receipt_number`
    FROM `payments`
    WHERE `receipt_number` IS NOT NULL
      AND `receipt_number_encrypted` IS NULL;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

  SET @@block_encryption_mode = 'aes-256-cbc';
  SET @secret_key = 'ClinicSecretEncryptionKey2026!';

  SET v_done = FALSE;
  OPEN patient_cursor;
  patient_loop: LOOP
    FETCH patient_cursor INTO v_patient_id, v_contact;
    IF v_done THEN
      LEAVE patient_loop;
    END IF;

    SET @raw_contact = v_contact;
    SET @row_iv = RANDOM_BYTES(16);
    UPDATE `clinic_patients`
    SET `contact_encrypted` = AES_ENCRYPT(@raw_contact, @secret_key, @row_iv),
        `encryption_iv` = @row_iv,
        `contact_token_hash` = SHA2(@raw_contact, 256)
    WHERE BINARY `patient_id` = BINARY v_patient_id;
  END LOOP;
  CLOSE patient_cursor;

  SET v_done = FALSE;
  OPEN payment_cursor;
  payment_loop: LOOP
    FETCH payment_cursor INTO v_payment_id, v_receipt_number;
    IF v_done THEN
      LEAVE payment_loop;
    END IF;

    SET @raw_receipt = v_receipt_number;
    SET @row_iv = RANDOM_BYTES(16);
    UPDATE `payments`
    SET `receipt_number_encrypted` = AES_ENCRYPT(@raw_receipt, @secret_key, @row_iv),
        `encryption_iv` = @row_iv,
        `receipt_token_hash` = SHA2(@raw_receipt, 256)
    WHERE `payment_id` = v_payment_id;
  END LOOP;
  CLOSE payment_cursor;
END//
DELIMITER ;

-- Re-assert the mode in the same session immediately before encryption. This
-- also makes STEP 3 safe when the migration block is run by itself.
SET @@block_encryption_mode = 'aes-256-cbc';
START TRANSACTION;
CALL `migrate_encrypted_values`();

-- STEP 3 CHECKER: Do not attempt NOT NULL conversion if AES_ENCRYPT returned
-- NULL. In CBC mode, every row must have ciphertext, an IV, and a token hash.
DROP PROCEDURE IF EXISTS `check_migrated_values`;
DELIMITER //
CREATE PROCEDURE `check_migrated_values`()
BEGIN
  DECLARE v_missing_values INT DEFAULT 0;

  SELECT COUNT(*) INTO v_missing_values
  FROM `clinic_patients`
  WHERE `contact_encrypted` IS NULL
     OR `encryption_iv` IS NULL
     OR `contact_token_hash` IS NULL;

  SELECT v_missing_values + COUNT(*) INTO v_missing_values
  FROM `payments`
  WHERE `receipt_number_encrypted` IS NULL
     OR `encryption_iv` IS NULL
     OR `receipt_token_hash` IS NULL;

  IF v_missing_values <> 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'STEP 3 FAILED: encrypted values are still NULL; verify aes-256-cbc mode';
  END IF;

  SELECT 'STEP 3 SUCCESS: all encrypted values, IVs, and token hashes verified'
    AS `step_3_status`;
END//
DELIMITER ;

CALL `check_migrated_values`();
DROP PROCEDURE IF EXISTS `check_migrated_values`;

-- The live source columns currently contain no NULL values. Make the new
-- encrypted columns strict only after every existing source value is migrated.
ALTER TABLE `clinic_patients`
  MODIFY COLUMN `contact_encrypted` VARBINARY(256) NOT NULL
    COMMENT 'Holds the raw encrypted binary string',
  MODIFY COLUMN `encryption_iv` VARBINARY(16) NOT NULL
    COMMENT 'Holds the 16-byte initialization vector',
  MODIFY COLUMN `contact_token_hash` CHAR(64) NOT NULL
    COMMENT 'One-way hash allowing fast, indexed WHERE lookups';

ALTER TABLE `payments`
  MODIFY COLUMN `receipt_number_encrypted` VARBINARY(256) NOT NULL
    COMMENT 'Holds the raw encrypted binary string',
  MODIFY COLUMN `encryption_iv` VARBINARY(16) NOT NULL
    COMMENT 'Holds the 16-byte initialization vector',
  MODIFY COLUMN `receipt_token_hash` CHAR(64) NOT NULL
    COMMENT 'One-way hash allowing fast, indexed WHERE lookups';

COMMIT;
DROP PROCEDURE IF EXISTS `migrate_encrypted_values`;

-- STEP 4: Insert fresh sample rows using the canonical inline-variable pattern.
-- These fake values are inserted only once so rerunning the script is safe.

SET @secret_key = 'ClinicSecretEncryptionKey2026!';
SET @raw_contact = '09170001111';
SET @row_iv = RANDOM_BYTES(16);
INSERT INTO `clinic_patients`
  (`patient_id`, `first_name`, `last_name`, `age`, `sex`, `address`, `contact`,
   `contact_encrypted`, `encryption_iv`, `contact_token_hash`)
SELECT
  'DEMO-001', 'Demo', 'Patient', 30, 'M', 'Demo Address', @raw_contact,
  AES_ENCRYPT(@raw_contact, @secret_key, @row_iv), @row_iv,
  SHA2(@raw_contact, 256)
WHERE NOT EXISTS (
  SELECT 1 FROM `clinic_patients`
  WHERE BINARY `patient_id` = BINARY 'DEMO-001'
);

SET @secret_key = 'ClinicSecretEncryptionKey2026!';
SET @raw_receipt = 'REC-DEMO-001';
SET @row_iv = RANDOM_BYTES(16);
SET @demo_order_id = (SELECT MIN(`order_id`) FROM `lab_test`);
INSERT INTO `payments`
  (`order_id`, `amount_paid`, `payment_method`, `receipt_number`,
   `receipt_number_encrypted`, `encryption_iv`, `receipt_token_hash`)
SELECT
  @demo_order_id, 1.00, 'CASH', @raw_receipt,
  AES_ENCRYPT(@raw_receipt, @secret_key, @row_iv), @row_iv,
  SHA2(@raw_receipt, 256)
WHERE @demo_order_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM `payments`
    WHERE BINARY `receipt_number` = BINARY @raw_receipt
  );

-- STEP 5: Create decryption views.
-- MySQL 8.0 does not allow a view definition to reference a user variable.
-- Therefore the executable views use the same configured secret literal.
-- The application should prefer the parameterized Decryption queries below,
-- which set @secret_key in its session before querying.

CREATE OR REPLACE VIEW `v_patients_decrypted` AS
SELECT
  `patient_id`,
  `first_name`,
  `last_name`,
  `age`,
  `sex`,
  CAST(AES_DECRYPT(
    `contact_encrypted`,
    'ClinicSecretEncryptionKey2026!',
    `encryption_iv`
  ) AS CHAR) AS `visible_contact`
FROM `clinic_patients`;

CREATE OR REPLACE VIEW `v_payments_decrypted` AS
SELECT
  `payment_id`,
  `order_id`,
  `amount_paid`,
  `payment_method`,
  `payment_date`,
  CAST(AES_DECRYPT(
    `receipt_number_encrypted`,
    'ClinicSecretEncryptionKey2026!',
    `encryption_iv`
  ) AS CHAR) AS `visible_receipt`,
  `status`
FROM `payments`;

-- Decryption:
SET @secret_key = 'ClinicSecretEncryptionKey2026!';

SET @search_contact = '09170001111';
SELECT
  `patient_id`,
  `first_name`,
  `last_name`,
  CAST(AES_DECRYPT(`contact_encrypted`, @secret_key, `encryption_iv`) AS CHAR)
    AS `visible_contact`
FROM `clinic_patients`
WHERE `contact_token_hash` = CONVERT(SHA2(@search_contact, 256) USING utf8mb4)
  COLLATE utf8mb4_0900_ai_ci; -- High-performance indexed lookup

SET @search_receipt = 'REC-DEMO-001';
SELECT
  `payment_id`,
  `order_id`,
  `amount_paid`,
  `payment_method`,
  `payment_date`,
  CAST(AES_DECRYPT(`receipt_number_encrypted`, @secret_key, `encryption_iv`) AS CHAR)
    AS `visible_receipt`,
  `status`
FROM `payments`
WHERE `receipt_token_hash` = CONVERT(SHA2(@search_receipt, 256) USING utf8mb4)
  COLLATE utf8mb4_0900_ai_ci; -- High-performance indexed lookup

-- Raw ciphertext proof: ciphertext and IV are displayed as hexadecimal binary,
-- while the token hash remains a one-way indexed lookup value.
SELECT
  HEX(`contact_encrypted`) AS `ciphertext_hex`,
  HEX(`encryption_iv`) AS `iv_hex`,
  `contact_token_hash`
FROM `clinic_patients`
LIMIT 3;

-- Salt/IV proof: the same plaintext is encrypted twice with two random IVs.
-- The two HEX values should differ even though @raw_contact is identical.
DROP TEMPORARY TABLE IF EXISTS `encryption_iv_proof`;
CREATE TEMPORARY TABLE `encryption_iv_proof` (
  `contact_encrypted` VARBINARY(256) NOT NULL,
  `encryption_iv` VARBINARY(16) NOT NULL
) ENGINE = InnoDB;

SET @raw_contact = '09170001111';
SET @row_iv = RANDOM_BYTES(16);
INSERT INTO `encryption_iv_proof` (`contact_encrypted`, `encryption_iv`)
VALUES (AES_ENCRYPT(@raw_contact, @secret_key, @row_iv), @row_iv);

SET @row_iv = RANDOM_BYTES(16);
INSERT INTO `encryption_iv_proof` (`contact_encrypted`, `encryption_iv`)
VALUES (AES_ENCRYPT(@raw_contact, @secret_key, @row_iv), @row_iv);

SELECT HEX(`contact_encrypted`) AS `ciphertext_hex`, HEX(`encryption_iv`) AS `iv_hex`
FROM `encryption_iv_proof`;

DROP TEMPORARY TABLE `encryption_iv_proof`;
