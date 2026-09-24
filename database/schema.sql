-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 05, 2026 at 11:57 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `patient_db`
--
CREATE DATABASE IF NOT EXISTS `patient_db` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `patient_db`;

-- --------------------------------------------------------
--
-- Table structure for table `cbc_results`
--

DROP TABLE IF EXISTS `cbc_results`;
CREATE TABLE IF NOT EXISTS `cbc_results` (
  `cbc_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `wbc` decimal(5,2) DEFAULT NULL,
  `rbc` decimal(5,2) DEFAULT NULL,
  `hemoglobin` decimal(5,2) DEFAULT NULL,
  `hematocrit` decimal(5,2) DEFAULT NULL,
  `platelets` int(11) DEFAULT NULL,
  `mcv` int(11) DEFAULT NULL,
  `mch` int(11) DEFAULT NULL,
  `neutrophils` decimal(5,2) DEFAULT NULL,
  `lymphocytes` decimal(5,2) DEFAULT NULL,
  `monocytes` decimal(5,2) DEFAULT NULL,
  `eosinophils` decimal(5,2) DEFAULT NULL,
  `basophils` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`cbc_id`),
  UNIQUE KEY `order_id` (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
--
-- Table structure for table `fecalysis_results`
--

DROP TABLE IF EXISTS `fecalysis_results`;
CREATE TABLE IF NOT EXISTS `fecalysis_results` (
  `fa_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `appearance` varchar(50) DEFAULT NULL,
  `consistency` varchar(50) DEFAULT NULL,
  `occult_blood` varchar(20) DEFAULT NULL,
  `parasite_id` varchar(50) DEFAULT NULL,
  `wbc` varchar(20) DEFAULT NULL,
  `rbc` varchar(20) DEFAULT NULL,
  `bacteria` varchar(20) DEFAULT NULL,
  `other_findings` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`fa_id`),
  UNIQUE KEY `order_id` (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
--
-- Table structure for table `patients`
--

DROP TABLE IF EXISTS `patients`;
CREATE TABLE IF NOT EXISTS `patients` (
  `patient_id` varchar(10) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `age` int(11) NOT NULL CHECK (`age` >= 0),
  `sex` char(1) NOT NULL CHECK (`sex` in ('M','F')),
  `address` varchar(150) DEFAULT NULL,
  `contact` varchar(20) DEFAULT NULL,
  `registered_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`patient_id`),
  UNIQUE KEY `contact` (`contact`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
--
-- Table structure for table `test_catalog`
--

DROP TABLE IF EXISTS `test_catalog`;
CREATE TABLE IF NOT EXISTS `test_catalog` (
  `test_id` int(11) NOT NULL AUTO_INCREMENT,
  `test_name` varchar(50) NOT NULL,
  `price` decimal(10,2) NOT NULL CHECK (`price` > 0),
  `description` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`test_id`),
  UNIQUE KEY `test_name` (`test_name`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
--
-- Table structure for table `test_orders`
--

DROP TABLE IF EXISTS `test_orders`;
CREATE TABLE IF NOT EXISTS `test_orders` (
  `order_id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` varchar(10) NOT NULL,
  `test_id` int(11) NOT NULL,
  `order_date` date NOT NULL,
  `status` enum('PENDING','COMPLETED','CANCELLED') DEFAULT 'COMPLETED',
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`order_id`),
  KEY `fk_order_patient` (`patient_id`),
  KEY `fk_order_test` (`test_id`)
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
--
-- Table structure for table `urinalysis_results`
--

DROP TABLE IF EXISTS `urinalysis_results`;
CREATE TABLE IF NOT EXISTS `urinalysis_results` (
  `ua_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `appearance` varchar(50) DEFAULT NULL,
  `color` varchar(50) DEFAULT NULL,
  `ph` decimal(3,1) DEFAULT NULL,
  `specific_gravity` decimal(4,3) DEFAULT NULL,
  `glucose` varchar(20) DEFAULT NULL,
  `protein` varchar(20) DEFAULT NULL,
  `ketones` varchar(20) DEFAULT NULL,
  `nitrites` varchar(20) DEFAULT NULL,
  `other_findings` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ua_id`),
  UNIQUE KEY `order_id` (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `cbc_results`
--
ALTER TABLE `cbc_results`
  ADD CONSTRAINT `fk_cbc_order` FOREIGN KEY (`order_id`) REFERENCES `test_orders` (`order_id`) ON DELETE CASCADE;

--
-- Constraints for table `fecalysis_results`
--
ALTER TABLE `fecalysis_results`
  ADD CONSTRAINT `fk_fa_order` FOREIGN KEY (`order_id`) REFERENCES `test_orders` (`order_id`) ON DELETE CASCADE;

--
-- Constraints for table `test_orders`
--
ALTER TABLE `test_orders`
  ADD CONSTRAINT `fk_order_patient` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`patient_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_order_test` FOREIGN KEY (`test_id`) REFERENCES `test_catalog` (`test_id`) ON DELETE CASCADE;

--
-- Constraints for table `urinalysis_results`
--
ALTER TABLE `urinalysis_results`
  ADD CONSTRAINT `fk_ua_order` FOREIGN KEY (`order_id`) REFERENCES `test_orders` (`order_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;