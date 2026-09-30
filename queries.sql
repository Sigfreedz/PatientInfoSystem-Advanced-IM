-- =====================================================
-- PATIENT INFO SYSTEM - LIVE SCHEMA QUERY PACK
-- Database: patient_db (clinic_patients / lab_test / lab_test_catalog)
-- =====================================================

-- =====================================================
-- SECTION 1: BASIC SELECT QUERIES
-- =====================================================

-- Q1: List all patients
SELECT patient_id, first_name, last_name, age, sex, contact
FROM clinic_patients
ORDER BY last_name, first_name;

-- Q2: Find patients by age range
SELECT patient_id, CONCAT(first_name, ' ', last_name) AS full_name, age, address
FROM clinic_patients
WHERE age BETWEEN 20 AND 30
ORDER BY age, last_name;

-- Q3: Search patients by location
SELECT patient_id, first_name, last_name, address, contact
FROM clinic_patients
WHERE address LIKE '%Metro Manila%'
   OR address LIKE '%Cebu%'
   OR address LIKE '%Davao%';

-- Q4: List all available tests with prices
SELECT test_id, test_name, price, description
FROM lab_test_catalog
ORDER BY price DESC;

-- Q5: List premium tests
SELECT test_id, test_name, price
FROM lab_test_catalog
WHERE price >= 250
ORDER BY price DESC;

-- Q6: Show distinct order statuses
SELECT DISTINCT status
FROM lab_test
ORDER BY status;

-- Q7: List orders from year 2024
SELECT order_id, patient_id, test_id, order_date, status
FROM lab_test
WHERE YEAR(order_date) = 2024
ORDER BY order_date DESC;

-- Q8: Display CBC results with low hemoglobin
SELECT cbc_id, order_id, hemoglobin, hematocrit, platelets
FROM cbc
WHERE hemoglobin < 13.0
ORDER BY hemoglobin;

-- Q9: Urinalysis results with abnormal protein
SELECT ua_id, order_id, ph, protein, other_findings
FROM urinalysis
WHERE protein <> 'Negative'
ORDER BY protein;

-- Q10: Fecalysis results with parasite detection
SELECT fa_id, order_id, appearance, parasite_id, other_findings
FROM fecalysis
WHERE parasite_id <> 'None'
ORDER BY parasite_id;

-- =====================================================
-- SECTION 2: JOIN QUERIES
-- =====================================================

-- Q11: JOIN - Patient + Order + Test Type
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    t.test_name,
    t.price,
    o.order_date,
    o.status
FROM clinic_patients p
INNER JOIN lab_test o ON p.patient_id = o.patient_id
INNER JOIN lab_test_catalog t ON o.test_id = t.test_id
ORDER BY o.order_date DESC;

-- Q12: JOIN - Order + CBC Results + Patient Info
SELECT
    o.order_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    o.order_date,
    c.wbc, c.rbc, c.hemoglobin, c.platelets
FROM lab_test o
INNER JOIN clinic_patients p ON o.patient_id = p.patient_id
INNER JOIN cbc c ON o.order_id = c.order_id
WHERE c.hemoglobin < 13.0
ORDER BY c.hemoglobin;

-- Q13: JOIN - Full Patient Diagnostic Summary
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    t.test_name,
    o.order_date,
    CASE
        WHEN t.test_name = 'CBC' THEN CONCAT('Hgb: ', c.hemoglobin, ' g/dL')
        WHEN t.test_name = 'URINALYSIS' THEN CONCAT('Protein: ', u.protein)
        WHEN t.test_name = 'FECALYSIS' THEN CONCAT('Parasite: ', f.parasite_id)
        ELSE 'N/A'
    END AS key_result
FROM clinic_patients p
JOIN lab_test o ON p.patient_id = o.patient_id
JOIN lab_test_catalog t ON o.test_id = t.test_id
LEFT JOIN cbc c ON o.order_id = c.order_id
LEFT JOIN urinalysis u ON o.order_id = u.order_id
LEFT JOIN fecalysis f ON o.order_id = f.order_id
ORDER BY p.patient_id, o.order_date;

-- =====================================================
-- SECTION 3: AGGREGATE QUERIES
-- =====================================================

-- Q14: Total revenue by test type
SELECT
    t.test_name,
    COUNT(o.order_id) AS times_ordered,
    SUM(t.price) AS total_revenue
FROM lab_test_catalog t
JOIN lab_test o ON t.test_id = o.test_id
GROUP BY t.test_id, t.test_name
ORDER BY total_revenue DESC;

-- Q15: Average CBC lab values by sex
SELECT
    p.sex,
    COUNT(DISTINCT p.patient_id) AS patient_count,
    AVG(c.hemoglobin) AS avg_hemoglobin,
    AVG(c.platelets) AS avg_platelets,
    ROUND(AVG(c.wbc), 2) AS avg_wbc
FROM clinic_patients p
JOIN lab_test o ON p.patient_id = o.patient_id
JOIN cbc c ON o.order_id = c.order_id
GROUP BY p.sex;

-- =====================================================
-- SECTION 4: SUBQUERIES
-- =====================================================

-- Q16: Patients who had CBC but NOT Urinalysis
SELECT patient_id, CONCAT(first_name, ' ', last_name) AS patient_name
FROM clinic_patients
WHERE patient_id IN (
    SELECT DISTINCT patient_id
    FROM lab_test
    WHERE test_id = (SELECT test_id FROM lab_test_catalog WHERE test_name = 'CBC')
)
AND patient_id NOT IN (
    SELECT DISTINCT patient_id
    FROM lab_test
    WHERE test_id = (SELECT test_id FROM lab_test_catalog WHERE test_name = 'URINALYSIS')
)
ORDER BY patient_id;

-- Q17: Most expensive test ordered per patient
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    (SELECT MAX(t.price)
     FROM lab_test o2
     JOIN lab_test_catalog t ON o2.test_id = t.test_id
     WHERE o2.patient_id = p.patient_id) AS max_test_price
FROM clinic_patients p
WHERE EXISTS (
    SELECT 1 FROM lab_test o3 WHERE o3.patient_id = p.patient_id
)
ORDER BY max_test_price DESC;

-- =====================================================
-- SECTION 5: UPDATE QUERIES
-- =====================================================

-- Q18: Update patient contact/address
UPDATE clinic_patients
SET contact = '09179998888',
    address = 'Updated: Makati City, Metro Manila'
WHERE patient_id = 'PAT-001';

-- Q19: Mark stale pending orders as completed
UPDATE lab_test
SET status = 'COMPLETED'
WHERE status = 'PENDING'
  AND order_date <= CURDATE() - INTERVAL 7 DAY;

-- =====================================================
-- SECTION 6: DELETE QUERIES
-- =====================================================

-- Q20: Remove cancelled test orders (ON DELETE CASCADE)
DELETE FROM lab_test
WHERE status = 'CANCELLED';

-- Q21: Remove PAT-004 fecalysis order
DELETE FROM lab_test
WHERE patient_id = 'PAT-004'
  AND test_id = (
      SELECT test_id
      FROM lab_test_catalog
      WHERE test_name = 'FECALYSIS'
      ORDER BY test_id
      LIMIT 1
  );
