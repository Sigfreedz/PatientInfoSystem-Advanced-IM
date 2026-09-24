-- Patient Info System - MySQL 8.0+ replacement schema
-- Recreates the legacy tables under professional names.

SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `patient_db`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE `patient_db`;

DROP TABLE IF EXISTS `cbc_reports`;
DROP TABLE IF EXISTS `urinalysis`;
DROP TABLE IF EXISTS `fecalysis`;
DROP TABLE IF EXISTS `lab_orders`;
DROP TABLE IF EXISTS `fa_reports`;
DROP TABLE IF EXISTS `ua_reports`;
DROP TABLE IF EXISTS `cbc`;
DROP TABLE IF EXISTS `clinic_patients`;

DROP TABLE IF EXISTS `cbc_results`;
DROP TABLE IF EXISTS `urinalysis_results`;
DROP TABLE IF EXISTS `fecalysis_results`;
DROP TABLE IF EXISTS `lab_test`;
DROP TABLE IF EXISTS `lab_test_catalog`;
DROP TABLE IF EXISTS `patients`;

CREATE TABLE `clinic_patients` (
  `patient_id` VARCHAR(10) NOT NULL,
  `first_name` VARCHAR(50) NOT NULL,
  `last_name` VARCHAR(50) NOT NULL,
  `age` INT NOT NULL,
  `sex` CHAR(1) NOT NULL,
  `address` VARCHAR(150) DEFAULT NULL,
  `contact` VARCHAR(20) DEFAULT NULL,
  `registered_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`patient_id`),
  UNIQUE KEY `uq_clinic_patients_contact` (`contact`),
  CONSTRAINT `chk_clinic_patients_age` CHECK (`age` >= 0),
  CONSTRAINT `chk_clinic_patients_sex` CHECK (`sex` IN ('M', 'F'))
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `lab_test_catalog` (
  `test_id` INT NOT NULL AUTO_INCREMENT,
  `test_name` VARCHAR(50) NOT NULL,
  `price` DECIMAL(10,2) NOT NULL,
  `description` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`test_id`),
  UNIQUE KEY `uq_lab_test_name` (`test_name`),
  CONSTRAINT `chk_lab_test_price` CHECK (`price` > 0)
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `lab_test` (
  `order_id` INT NOT NULL AUTO_INCREMENT,
  `patient_id` VARCHAR(10) NOT NULL,
  `test_id` INT NOT NULL,
  `order_date` DATE NOT NULL,
  `status` ENUM('PENDING', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`order_id`),
  KEY `idx_lab_test_patient_id` (`patient_id`),
  KEY `idx_lab_test_test_id` (`test_id`),
  CONSTRAINT `fk_lab_test_patient`
    FOREIGN KEY (`patient_id`) REFERENCES `clinic_patients` (`patient_id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_lab_test_test`
    FOREIGN KEY (`test_id`) REFERENCES `lab_test_catalog` (`test_id`)
    ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `cbc` (
  `cbc_id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `wbc` DECIMAL(5,2) DEFAULT NULL,
  `rbc` DECIMAL(5,2) DEFAULT NULL,
  `hemoglobin` DECIMAL(5,2) DEFAULT NULL,
  `hematocrit` DECIMAL(5,2) DEFAULT NULL,
  `platelets` INT DEFAULT NULL,
  `mcv` INT DEFAULT NULL,
  `mch` INT DEFAULT NULL,
  `neutrophils` DECIMAL(5,2) DEFAULT NULL,
  `lymphocytes` DECIMAL(5,2) DEFAULT NULL,
  `monocytes` DECIMAL(5,2) DEFAULT NULL,
  `eosinophils` DECIMAL(5,2) DEFAULT NULL,
  `basophils` DECIMAL(5,2) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cbc_id`),
  UNIQUE KEY `uq_cbc_order_id` (`order_id`),
  CONSTRAINT `fk_cbc_order`
    FOREIGN KEY (`order_id`) REFERENCES `lab_test` (`order_id`)
    ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `urinalysis` (
  `ua_id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `appearance` VARCHAR(50) DEFAULT NULL,
  `color` VARCHAR(50) DEFAULT NULL,
  `ph` DECIMAL(3,1) DEFAULT NULL,
  `specific_gravity` DECIMAL(4,3) DEFAULT NULL,
  `glucose` VARCHAR(20) DEFAULT NULL,
  `protein` VARCHAR(20) DEFAULT NULL,
  `ketones` VARCHAR(20) DEFAULT NULL,
  `nitrites` VARCHAR(20) DEFAULT NULL,
  `other_findings` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ua_id`),
  UNIQUE KEY `uq_urinalysis_order_id` (`order_id`),
  CONSTRAINT `fk_urinalysis_order`
    FOREIGN KEY (`order_id`) REFERENCES `lab_test` (`order_id`)
    ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE `fecalysis` (
  `fa_id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `appearance` VARCHAR(50) DEFAULT NULL,
  `consistency` VARCHAR(50) DEFAULT NULL,
  `occult_blood` VARCHAR(20) DEFAULT NULL,
  `parasite_id` VARCHAR(50) DEFAULT NULL,
  `wbc` VARCHAR(20) DEFAULT NULL,
  `rbc` VARCHAR(20) DEFAULT NULL,
  `bacteria` VARCHAR(20) DEFAULT NULL,
  `other_findings` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`fa_id`),
  UNIQUE KEY `uq_fecalysis_order_id` (`order_id`),
  CONSTRAINT `fk_fecalysis_order`
    FOREIGN KEY (`order_id`) REFERENCES `lab_test` (`order_id`)
    ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- query to view all the renamed tables in the database

SHOW TABLES FROM `patient_db`;

CREATE TABLE `payments` (
  `payment_id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `amount_paid` DECIMAL(10,2) NOT NULL,
  `payment_method` ENUM('CASH', 'CARD', 'GCASH', 'INSURANCE') NOT NULL DEFAULT 'CASH',
  `payment_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `receipt_number` VARCHAR(50) DEFAULT NULL,
  `status` ENUM('PAID', 'PARTIAL', 'REFUNDED') NOT NULL DEFAULT 'PAID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`payment_id`),
  UNIQUE KEY `uq_payments_receipt` (`receipt_number`),
  KEY `idx_payments_order` (`order_id`),
  KEY `idx_payments_status` (`status`),
  CONSTRAINT `fk_payments_order`
    FOREIGN KEY (`order_id`) REFERENCES `lab_test` (`order_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `chk_payment_positive`
    CHECK (`amount_paid` > 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Cumulative payment validation SUM(amount_paid) <= lab_test.total_amount enforced at application layer';