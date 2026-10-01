-- PATIENT INFO SYSTEM - ENCRYPTION/DECRYPTION DEMONSTRATION
-- Read-only presentation queries for patient contacts and payment receipts.
-- Replace the placeholder below with the same key configured in PATIENT_ENCRYPTION_KEY.

USE `patient_db`;

SET @secret_key = 'ClinicSecretEncryptionKey2026!';

-- 1. Show that sensitive values are stored as ciphertext, not readable text.
SELECT
    patient_id,
    HEX(contact_encrypted) AS contact_ciphertext,
    HEX(encryption_iv) AS contact_iv,
    contact_token_hash
FROM clinic_patients
WHERE contact_encrypted IS NOT NULL
LIMIT 3;

SELECT
    payment_id,
    order_id,
    HEX(receipt_number_encrypted) AS receipt_ciphertext,
    HEX(encryption_iv) AS receipt_iv,
    receipt_token_hash
FROM payments
WHERE receipt_number_encrypted IS NOT NULL
LIMIT 3;

-- 2. Authorized decryption of patient contact numbers.
SELECT
    patient_id,
    first_name,
    last_name,
    CAST(AES_DECRYPT(contact_encrypted, @secret_key, encryption_iv) AS CHAR)
        AS visible_contact
FROM clinic_patients
WHERE contact_encrypted IS NOT NULL
LIMIT 10;

-- 3. Authorized decryption of payment receipt numbers.
SELECT
    payment_id,
    order_id,
    amount_paid,
    payment_method,
    payment_date,
    CAST(AES_DECRYPT(receipt_number_encrypted, @secret_key, encryption_iv) AS CHAR)
        AS visible_receipt,
    status
FROM payments
WHERE receipt_number_encrypted IS NOT NULL
ORDER BY payment_date DESC
LIMIT 10;

-- 4. Indexed lookup using a one-way token hash.
-- Replace the demo value with a known contact number for a live test.
SET @search_contact = 'REPLACE_WITH_CONTACT_NUMBER';

SELECT
    patient_id,
    first_name,
    last_name,
    CAST(AES_DECRYPT(contact_encrypted, @secret_key, encryption_iv) AS CHAR)
        AS visible_contact
FROM clinic_patients
WHERE contact_token_hash = CONVERT(SHA2(@search_contact, 256) USING utf8mb4)
  COLLATE utf8mb4_0900_ai_ci;

-- 5. IV demonstration: the same plaintext produces different ciphertext
-- when encrypted with different random IVs.
SET @demo_plaintext = 'DEMO-CONTACT-VALUE';
SET @iv_one = RANDOM_BYTES(16);
SET @iv_two = RANDOM_BYTES(16);

SELECT
    HEX(AES_ENCRYPT(@demo_plaintext, @secret_key, @iv_one)) AS ciphertext_one,
    HEX(@iv_one) AS iv_one,
    HEX(AES_ENCRYPT(@demo_plaintext, @secret_key, @iv_two)) AS ciphertext_two,
    HEX(@iv_two) AS iv_two,
    'Same plaintext, different ciphertext because each row uses a random IV' AS explanation;

-- 6. Optional decryption-view demonstration.
-- These views use the configured encryption key from the migration script.
SELECT * FROM v_patients_decrypted LIMIT 10;
SELECT * FROM v_payments_decrypted ORDER BY payment_date DESC LIMIT 10;
