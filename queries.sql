-- =====================================================
-- PATIENT INFO SYSTEM
-- Database: patient_db
-- =====================================================

-- =====================================================
-- SECTION 1: BASIC SELECT QUERIES
-- =====================================================

-- Q1
SELECT patient_id, first_name, last_name, age, sex, contact
FROM clinic_patients
ORDER BY last_name, first_name;

-- Q2
SELECT patient_id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       age,
       address
FROM clinic_patients
WHERE age BETWEEN 20 AND 30
ORDER BY age, last_name;

-- Q3
SELECT patient_id, first_name, last_name, address, contact
FROM clinic_patients
WHERE address LIKE '%Metro Manila%'
   OR address LIKE '%Cebu%'
   OR address LIKE '%Davao%';

-- Q4
SELECT test_id, test_name, price, description
FROM lab_test_catalog
ORDER BY price DESC;

-- Q5
SELECT test_id, test_name, price
FROM lab_test_catalog
WHERE price >= 250
ORDER BY price DESC;

-- Q6
SELECT DISTINCT status
FROM lab_test
ORDER BY status;

-- Q7
SELECT order_id, patient_id, test_id, order_date, status
FROM lab_test
WHERE YEAR(order_date) = 2024
ORDER BY order_date DESC;

-- Q8
SELECT cbc_id, order_id, hemoglobin, hematocrit, platelets
FROM cbc
WHERE hemoglobin < 13.0
ORDER BY hemoglobin;

-- Q9
SELECT ua_id, order_id, ph, protein, other_findings
FROM urinalysis
WHERE protein <> 'Negative'
ORDER BY protein;

-- Q10
SELECT fa_id, order_id, appearance, parasite_id, other_findings
FROM fecalysis
WHERE parasite_id <> 'None'
ORDER BY parasite_id;


-- =====================================================
-- SECTION 2: JOIN QUERIES
-- =====================================================

-- Q11
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

-- Q12
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

-- Q13
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

-- Q14
SELECT
    t.test_name,
    COUNT(o.order_id) AS times_ordered,
    SUM(t.price) AS total_revenue
FROM lab_test_catalog t
JOIN lab_test o ON t.test_id = o.test_id
GROUP BY t.test_id, t.test_name
ORDER BY total_revenue DESC;

-- Q15
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

-- Q16
SELECT patient_id,
       CONCAT(first_name, ' ', last_name) AS patient_name
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

-- Q17
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    (
        SELECT MAX(t.price)
        FROM lab_test o2
        JOIN lab_test_catalog t ON o2.test_id = t.test_id
        WHERE o2.patient_id = p.patient_id
    ) AS max_test_price
FROM clinic_patients p
WHERE EXISTS (
    SELECT 1
    FROM lab_test o3
    WHERE o3.patient_id = p.patient_id
)
ORDER BY max_test_price DESC;


-- =====================================================
-- SECTION 5: UPDATE QUERIES
-- =====================================================

-- Q18
UPDATE clinic_patients
SET contact = '09179998888',
    address = 'Updated: Makati City, Metro Manila'
WHERE patient_id = 'PAT-001';

-- Q19
UPDATE lab_test
SET status = 'COMPLETED'
WHERE status = 'PENDING'
  AND order_date <= CURDATE() - INTERVAL 7 DAY;


-- =====================================================
-- SECTION 6: DELETE QUERIES
-- =====================================================

-- Q20
DELETE FROM lab_test
WHERE status = 'CANCELLED';

-- Q21
DELETE FROM lab_test
WHERE patient_id = 'PAT-004'
  AND test_id = (
      SELECT test_id
      FROM lab_test_catalog
      WHERE test_name = 'FECALYSIS'
      ORDER BY test_id
      LIMIT 1
  );


-- =====================================================
-- SECTION 7: QUERY OPTIMIZATION
-- =====================================================

-- Indexing 
CREATE INDEX idx_clinic_patients_age
    ON clinic_patients(age);

CREATE INDEX idx_clinic_patients_last_name_first_name
    ON clinic_patients(last_name, first_name);

CREATE INDEX idx_lab_test_patient_id
    ON lab_test(patient_id);

CREATE INDEX idx_lab_test_test_id
    ON lab_test(test_id);

CREATE INDEX idx_lab_test_status_order_date
    ON lab_test(status, order_date);

CREATE INDEX idx_cbc_order_id
    ON cbc(order_id);

CREATE INDEX idx_cbc_hemoglobin
    ON cbc(hemoglobin);

CREATE INDEX idx_urinalysis_order_id
    ON urinalysis(order_id);

CREATE INDEX idx_urinalysis_protein
    ON urinalysis(protein);

CREATE INDEX idx_fecalysis_order_id
    ON fecalysis(order_id);

CREATE INDEX idx_fecalysis_parasite_id
    ON fecalysis(parasite_id);

CREATE INDEX idx_lab_test_catalog_price
    ON lab_test_catalog(price);

-- EXPLAIN 
EXPLAIN
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    t.test_name,
    o.order_date,
    o.status
FROM clinic_patients p
JOIN lab_test o ON p.patient_id = o.patient_id
JOIN lab_test_catalog t ON o.test_id = t.test_id
WHERE p.age BETWEEN 20 AND 30
  AND o.status = 'COMPLETED'
ORDER BY o.order_date DESC;

-- Query rewriting 
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    MAX(t.price) AS max_test_price
FROM clinic_patients p
JOIN lab_test o ON p.patient_id = o.patient_id
JOIN lab_test_catalog t ON o.test_id = t.test_id
GROUP BY p.patient_id, p.first_name, p.last_name
ORDER BY max_test_price DESC;

-- Partition
ALTER TABLE lab_test
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
