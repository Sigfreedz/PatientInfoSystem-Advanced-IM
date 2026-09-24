-- ✅ STEP 1: DISABLE CONSTRAINT CHECKS (Prevents #1452 Errors)
SET FOREIGN_KEY_CHECKS = 0;

-- ✅ STEP 2: SELECT DATABASE
USE `patient_db`;

-- ✅ STEP 3: CLEAR EXISTING DATA (In reverse order of dependency)
DELETE FROM `fecalysis_results`;
DELETE FROM `urinalysis_results`;
DELETE FROM `cbc_results`;
DELETE FROM `test_orders`;
DELETE FROM `test_catalog`;
DELETE FROM `patients`;

-- ✅ STEP 4: RESET AUTO-INCREMENT COUNTERS (Ensures IDs start at 1)
ALTER TABLE `test_catalog` AUTO_INCREMENT = 1;
ALTER TABLE `test_orders` AUTO_INCREMENT = 1;

-- ✅ STEP 5: INSERT PARENT DATA (Patients & Test Catalog)
-- Note: We explicitly force Test IDs 1, 2, 3 to match the Orders below.
INSERT INTO `test_catalog` (`test_id`, `test_name`, `price`, `description`) VALUES
(1, 'CBC', 200.00, 'Complete Blood Count'),
(2, 'URINALYSIS', 100.00, 'Routine Urine Test'),
(3, 'FECALYSIS', 100.00, 'Stool Examination'),
(4, 'BLOOD CHEMISTRY', 350.00, 'FBS, Cholesterol, etc.'),
(5, 'LIPID PROFILE', 300.00, 'Cholesterol, Triglycerides'),
(6, 'LIVER FUNCTION', 250.00, 'ALT, AST, Bilirubin'),
(7, 'RENAL FUNCTION', 250.00, 'Creatinine, BUN'),
(8, 'THYROID PANEL', 400.00, 'T3, T4, TSH'),
(9, 'HEPATITIS B SCREEN', 150.00, 'HBsAg Test'),
(10, 'DENGUE NS1', 180.00, 'Early Dengue Detection'),
(11, 'PREGNANCY TEST', 120.00, 'Urine hCG'),
(12, 'STREP THROAT', 130.00, 'Rapid Antigen Test'),
(13, 'URINE CULTURE', 200.00, 'Bacterial Infection Check'),
(14, 'Sputum AFB', 160.00, 'TB Screening'),
(15, 'BLOOD TYPING', 100.00, 'ABO/Rh Determination'),
(16, 'COAGULATION PROFILE', 220.00, 'PT/PTT Test'),
(17, 'VITAMIN D', 280.00, '25-OH Vitamin D'),
(18, 'IRON STUDIES', 260.00, 'Ferritin, TIBC'),
(19, 'HBA1C', 240.00, 'Diabetes Monitoring'),
(20, 'TUMOR MARKERS', 500.00, 'PSA/CEA Screening');

INSERT INTO `patients` (`patient_id`, `first_name`, `last_name`, `age`, `sex`, `address`, `contact`) VALUES
('PAT-001', 'Maria', 'Santos', 23, 'F', 'Quezon City, Metro Manila', '09171234567'),
('PAT-002', 'Juan', 'Dela Cruz', 30, 'M', 'Cebu City, Cebu', '09181234568'),
('PAT-003', 'Ana', 'Villanueva', 27, 'F', 'Iloilo City, Iloilo', '09191234569'),
('PAT-004', 'Miguel', 'Torres', 21, 'M', 'Bacolod City, Negros Occidental', '09151234560'),
('PAT-005', 'Sarah', 'Lim', 19, 'F', 'Pasig City, Metro Manila', '09161234561'),
('PAT-006', 'Paolo', 'Mercado', 35, 'M', 'Davao City, Davao del Sur', '09156234559'),
('PAT-007', 'Christine', 'Bautista', 32, 'F', 'Taguig City, Metro Manila', '09151234557'),
('PAT-008', 'Diego', 'Ramos', 29, 'M', 'San Fernando City, Pampanga', '09146234555'),
('PAT-009', 'Julia', 'Fernandez', 22, 'F', 'Cagayan de Oro City, Misamis Oriental', '09141234553'),
('PAT-010', 'Mark', 'Reyes', 40, 'M', 'Legazpi City, Albay', '09136234551'),
('PAT-011', 'Joanna', 'Garcia', 26, 'F', 'General Santos City, South Cotabato', '09131234549'),
('PAT-012', 'Kevin', 'Lopez', 34, 'M', 'Baguio City, Benguet', '09126234547'),
('PAT-013', 'Sophia', 'Tan', 25, 'F', 'Zamboanga City, Zamboanga', '09121234545'),
('PAT-014', 'Carlo', 'Cruz', 37, 'M', 'Dasmarinas City, Cavite', '09116234543'),
('PAT-015', 'Angela', 'Rivera', 31, 'F', 'Naga City, Camarines Sur', '09111234541'),
('PAT-016', 'Jason', 'Medina', 24, 'M', 'Caloocan City, Metro Manila', '09106234539'),
('PAT-017', 'Nina', 'Aquino', 20, 'F', 'Tacloban City, Leyte', '09101234537'),
('PAT-018', 'Ryan', 'Castillo', 28, 'M', 'Butuan City, Agusan del Norte', '09096234535'),
('PAT-019', 'Camille', 'Vega', 33, 'F', 'Vigan City, Ilocos Sur', '09091234533'),
('PAT-020', 'Patrick', 'Mendoza', 36, 'M', 'Puerto Princesa City, Palawan', '09687540028');

-- ✅ STEP 6: INSERT CHILD DATA (Orders)
-- References IDs 1, 2, 3 which we forced in Step 5.
INSERT INTO `test_orders` (`patient_id`, `test_id`, `order_date`, `status`) VALUES
('PAT-001', 1, '2023-01-05', 'COMPLETED'), ('PAT-002', 2, '2023-02-01', 'COMPLETED'),
('PAT-003', 3, '2023-03-10', 'COMPLETED'), ('PAT-004', 1, '2023-04-15', 'COMPLETED'),
('PAT-004', 2, '2023-04-15', 'COMPLETED'), ('PAT-004', 3, '2023-04-15', 'COMPLETED'),
('PAT-005', 1, '2023-05-05', 'COMPLETED'), ('PAT-005', 2, '2023-05-05', 'COMPLETED'),
('PAT-006', 2, '2023-06-09', 'COMPLETED'), ('PAT-006', 3, '2023-06-09', 'COMPLETED'),
('PAT-007', 1, '2023-07-14', 'COMPLETED'), ('PAT-007', 3, '2023-07-14', 'COMPLETED'),
('PAT-008', 1, '2023-09-18', 'COMPLETED'), ('PAT-008', 2, '2023-09-18', 'COMPLETED'),
('PAT-008', 3, '2023-09-18', 'COMPLETED'), ('PAT-009', 1, '2023-10-12', 'COMPLETED'),
('PAT-010', 3, '2023-11-08', 'COMPLETED'), ('PAT-011', 3, '2023-12-01', 'COMPLETED'),
('PAT-012', 2, '2024-01-20', 'COMPLETED'), ('PAT-013', 2, '2024-03-02', 'COMPLETED'),
('PAT-013', 3, '2024-03-02', 'COMPLETED'), ('PAT-014', 3, '2024-04-10', 'COMPLETED'),
('PAT-015', 1, '2024-02-11', 'COMPLETED'), ('PAT-015', 2, '2024-02-11', 'COMPLETED'),
('PAT-015', 3, '2024-02-11', 'COMPLETED'), ('PAT-016', 3, '2024-05-15', 'COMPLETED'),
('PAT-017', 1, '2024-06-05', 'COMPLETED'), ('PAT-017', 2, '2024-06-05', 'COMPLETED'),
('PAT-017', 3, '2024-06-05', 'COMPLETED'), ('PAT-018', 1, '2024-07-03', 'COMPLETED'),
('PAT-018', 3, '2024-07-03', 'COMPLETED'), ('PAT-019', 1, '2024-08-20', 'COMPLETED'),
('PAT-019', 2, '2024-08-20', 'COMPLETED'), ('PAT-019', 3, '2024-08-20', 'COMPLETED'),
('PAT-020', 1, '2024-11-12', 'COMPLETED'), ('PAT-020', 3, '2024-11-12', 'COMPLETED');

-- ✅ STEP 7: INSERT GRANDCHILD DATA (Results)
-- Uses the same order IDs generated in Step 6.
INSERT INTO `cbc_results` (`order_id`, `wbc`, `rbc`, `hemoglobin`, `hematocrit`, `platelets`, `mcv`, `mch`, `neutrophils`, `lymphocytes`, `monocytes`, `eosinophils`, `basophils`) VALUES
(1, 6.50, 4.80, 13.50, 40.20, 250, 87, 29, 55.00, 35.00, 5.00, 4.00, 1.00),
(2, 7.10, 4.90, 14.00, 41.00, 280, 88, 30, 58.00, 32.00, 5.00, 4.00, 1.00),
(4, 7.20, 5.00, 14.10, 42.50, 300, 88, 31, 60.00, 30.00, 4.00, 4.00, 2.00),
(5, 6.00, 4.70, 13.00, 39.00, 270, 86, 29, 54.00, 36.00, 5.50, 3.50, 1.00),
(7, 5.80, 4.60, 12.80, 37.80, 280, 85, 28, 50.00, 40.00, 6.00, 3.00, 1.00),
(8, 6.10, 4.70, 13.20, 39.50, 290, 86, 29, 52.00, 38.00, 5.50, 3.50, 1.00),
(9, 6.80, 4.80, 13.40, 40.00, 275, 87, 30, 56.00, 34.00, 5.00, 4.00, 1.00),
(11, 8.00, 4.90, 13.90, 41.30, 270, 86, 30, 58.00, 32.00, 5.00, 4.00, 1.00),
(13, 6.90, 4.70, 13.00, 38.90, 260, 89, 29, 56.00, 34.00, 6.00, 3.00, 1.00),
(14, 7.40, 5.10, 14.20, 42.00, 295, 88, 31, 59.00, 31.00, 5.00, 4.00, 1.00),
(16, 7.50, 4.80, 14.00, 40.00, 310, 87, 30, 59.00, 31.00, 4.00, 4.00, 2.00),
(20, 6.60, 4.50, 12.70, 38.00, 265, 85, 28, 53.00, 37.00, 6.00, 3.00, 1.00),
(23, 5.90, 4.50, 12.50, 36.50, 295, 84, 27, 53.00, 38.00, 6.00, 3.00, 0.00),
(24, 7.00, 4.90, 13.80, 40.50, 285, 87, 30, 57.00, 33.00, 5.50, 3.50, 1.00),
(27, 8.30, 5.20, 15.00, 44.20, 310, 88, 32, 62.00, 29.00, 5.00, 3.00, 1.00),
(28, 6.70, 4.60, 12.90, 38.50, 270, 86, 29, 55.00, 35.00, 5.00, 4.00, 1.00),
(30, 7.00, 4.90, 13.80, 40.70, 275, 86, 30, 57.00, 33.00, 6.00, 3.00, 1.00),
(33, 6.70, 4.80, 13.60, 39.50, 265, 87, 29, 55.00, 35.00, 5.00, 4.00, 1.00),
(34, 7.60, 5.00, 14.40, 42.80, 300, 89, 31, 60.00, 30.00, 5.00, 4.00, 1.00),
(36, 6.40, 4.60, 12.90, 38.00, 260, 85, 28, 54.00, 36.00, 5.50, 3.50, 1.00);

INSERT INTO `urinalysis_results` (`order_id`, `appearance`, `color`, `ph`, `specific_gravity`, `glucose`, `protein`, `ketones`, `nitrites`, `other_findings`) VALUES
(1, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(3, 'Slightly Turbid', 'Yellow', 5.5, 1.015, 'Negative', 'Trace', 'Negative', 'Negative', 'Occasional WBCs'),
(4, 'Clear', 'Pale Yellow', 7.0, 1.008, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(6, 'Turbid', 'Dark Yellow', 5.0, 1.020, 'Trace', '1+', 'Negative', 'Negative', 'RBCs Present'),
(7, 'Slightly Turbid', 'Yellow', 6.5, 1.012, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(8, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(10, 'Slightly Turbid', 'Yellow', 5.5, 1.015, 'Trace', 'Trace', 'Negative', 'Negative', 'Few Epithelial Cells'),
(11, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(12, 'Turbid', 'Dark Yellow', 5.0, 1.020, 'Trace', '2+', '1+', 'Positive', 'Moderate WBCs'),
(13, 'Slightly Turbid', 'Yellow', 6.5, 1.012, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(15, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(16, 'Slightly Turbid', 'Yellow', 5.5, 1.015, 'Trace', 'Trace', 'Negative', 'Negative', 'Few Epithelial Cells'),
(17, 'Clear', 'Pale Yellow', 6.5, 1.008, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(18, 'Turbid', 'Dark Yellow', 5.0, 1.020, 'Trace', '1+', 'Negative', 'Negative', 'RBCs Present'),
(19, 'Slightly Turbid', 'Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(20, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(21, 'Slightly Turbid', 'Yellow', 5.5, 1.015, 'Trace', 'Trace', 'Negative', 'Negative', 'Few Epithelial Cells'),
(22, 'Clear', 'Pale Yellow', 6.5, 1.008, 'Negative', 'Negative', 'Negative', 'Negative', 'None'),
(25, 'Turbid', 'Dark Yellow', 5.0, 1.020, 'Trace', '2+', '1+', 'Positive', 'Moderate WBCs'),
(26, 'Clear', 'Pale Yellow', 6.0, 1.010, 'Negative', 'Negative', 'Negative', 'Negative', 'None');

INSERT INTO `fecalysis_results` (`order_id`, `appearance`, `consistency`, `occult_blood`, `parasite_id`, `wbc`, `rbc`, `bacteria`, `other_findings`) VALUES
(1, 'Yellow', 'Soft', 'Negative', 'None', '3/hpf', '1/hpf', 'Moderate', 'No Abnormalities'),
(2, 'Brown', 'Formed', 'Negative', 'Giardia spp.', '5/hpf', '2/hpf', 'Few', 'Presence of undigested food'),
(3, 'Green', 'Soft', 'Positive', 'None', '4/hpf', '3/hpf', 'Abundant', 'Mucus detected'),
(4, 'Yellow', 'Watery', 'Negative', 'Ascaris spp.', '2/hpf', '0/hpf', 'Moderate', 'Ova detected'),
(5, 'Brown', 'Formed', 'Negative', 'None', '1/hpf', '1/hpf', 'Few', 'No Abnormalities'),
(6, 'Yellow', 'Soft', 'Negative', 'Hookworm spp.', '3/hpf', '2/hpf', 'Moderate', 'Blood Streaked'),
(7, 'Green', 'Soft', 'Negative', 'None', '4/hpf', '2/hpf', 'Few', 'Excess fat'),
(8, 'Brown', 'Formed', 'Positive', 'None', '5/hpf', '3/hpf', 'Moderate', 'Inflammatory cells'),
(9, 'Yellow', 'Watery', 'Positive', 'Strongyloides', '6/hpf', '4/hpf', 'Abundant', 'Visible parasites'),
(10, 'Brown', 'Formed', 'Negative', 'None', '1/hpf', '1/hpf', 'Few', 'No Abnormalities'),
(11, 'Yellow', 'Soft', 'Negative', 'Giardia spp.', '3/hpf', '2/hpf', 'Moderate', 'Mild inflammation noted'),
(12, 'Green', 'Soft', 'Positive', 'None', '5/hpf', '4/hpf', 'Abundant', 'Presence of mucus and ova'),
(13, 'Yellow', 'Soft', 'Negative', 'Ascaris spp.', '2/hpf', '0/hpf', 'Few', 'Parasite eggs'),
(14, 'Brown', 'Formed', 'Negative', 'Hookworm spp.', '3/hpf', '1/hpf', 'Few', 'Slightly elevated fat'),
(15, 'Brown', 'Formed', 'Negative', 'None', '2/hpf', '1/hpf', 'Moderate', 'Normal Findings'),
(16, 'Yellow', 'Soft', 'Negative', 'None', '3/hpf', '1/hpf', 'Moderate', 'No Abnormalities'),
(17, 'Brown', 'Formed', 'Negative', 'Hookworm spp.', '3/hpf', '1/hpf', 'Few', 'Slightly elevated fat'),
(18, 'Yellow', 'Watery', 'Positive', 'Strongyloides', '6/hpf', '4/hpf', 'Abundant', 'Visible parasites'),
(19, 'Brown', 'Formed', 'Negative', 'None', '2/hpf', '1/hpf', 'Moderate', 'Normal Findings'),
(20, 'Yellow', 'Soft', 'Negative', 'Giardia spp.', '3/hpf', '2/hpf', 'Moderate', 'Mild inflammation noted');

-- ✅ STEP 8: RE-ENABLE CONSTRAINT CHECKS (Security)
SET FOREIGN_KEY_CHECKS = 1;
