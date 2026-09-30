-- Application login records for Flask. Generate password_hash values with
-- werkzeug.security.generate_password_hash before inserting real accounts.
USE `patient_db`;

CREATE TABLE IF NOT EXISTS `app_users` (
  `user_id` INT NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(80) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role_name` ENUM('role_admin', 'role_front_desk', 'role_lab_tech', 'role_doctor', 'role_patient') NOT NULL,
  `patient_id` VARCHAR(10) DEFAULT NULL,
  `mysql_username` VARCHAR(80) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_app_users_username` (`username`),
  UNIQUE KEY `uq_app_users_patient_id` (`patient_id`),
  CONSTRAINT `fk_app_users_patient`
    FOREIGN KEY (`patient_id`) REFERENCES `clinic_patients` (`patient_id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARACTER SET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- Example only. Replace the hash and account values before use.
-- INSERT INTO app_users (username, password_hash, role_name, mysql_username)
-- VALUES ('admin', '<generated-password-hash>', 'role_admin', 'user_admin');
