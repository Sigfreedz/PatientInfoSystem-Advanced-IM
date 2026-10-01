-- =====================================================
-- PATIENT INFO SYSTEM - REQUIRED SQL QUERIES
-- Database: patient_db | Intermediate IM Final Project
-- =====================================================

-- =====================================================
-- SECTION 1: BASIC SELECT QUERIES (10 Required)
-- =====================================================

-- Q1: List all patients (Basic SELECT)
SELECT patient_id, first_name, last_name, age, sex, contact
FROM patients
ORDER BY last_name, first_name;

-- Q2: Find patients by age range (Advanced WHERE)
SELECT patient_id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       age,
       address
FROM patients
WHERE age BETWEEN 20 AND 30
ORDER BY age, last_name;

-- Q3: Search patients by location (LIKE operator)
SELECT patient_id, first_name, last_name, address, contact
FROM patients
WHERE address LIKE '%Metro Manila%'
   OR address LIKE '%Cebu%'
   OR address LIKE '%Davao%';

-- Q4: List all available tests with prices (ORDER BY)
SELECT test_id, test_name, price, description
FROM test_catalog
ORDER BY price DESC;

-- Q5: List premium tests (price filter)
SELECT test_id, test_name, price
FROM test_catalog
WHERE price >= 250
ORDER BY price DESC;

-- Q6: Show distinct order statuses (DISTINCT)
SELECT DISTINCT status
FROM test_orders
ORDER BY status;

-- Q7: List orders from year 2024 (Date function)
SELECT order_id, patient_id, test_id, order_date, status
FROM test_orders
WHERE YEAR(order_date) = 2024
ORDER BY order_date DESC;

-- Q8: Display CBC results with low hemoglobin
SELECT cbc_id, order_id, hemoglobin, hematocrit, platelets
FROM cbc_results
WHERE hemoglobin < 13.0
ORDER BY hemoglobin;

-- Q9: Urinalysis results with abnormal protein
SELECT ua_id, order_id, ph, protein, other_findings
FROM urinalysis_results
WHERE protein <> 'Negative'
ORDER BY protein;

-- Q10: Fecalysis results with parasite detection
SELECT fa_id, order_id, appearance, parasite_id, other_findings
FROM fecalysis_results
WHERE parasite_id <> 'None'
ORDER BY parasite_id;


-- =====================================================
-- SECTION 2: JOIN QUERIES (3 Required)
-- =====================================================

-- Q11: JOIN - Patient + Order + Test Type (3-table JOIN)
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    t.test_name,
    t.price,
    o.order_date,
    o.status
FROM patients p
INNER JOIN test_orders o ON p.patient_id = o.patient_id
INNER JOIN test_catalog t ON o.test_id = t.test_id
ORDER BY o.order_date DESC;

-- Q12: JOIN - Order + CBC Results + Patient Info
SELECT
    o.order_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    o.order_date,
    c.wbc, c.rbc, c.hemoglobin, c.platelets
FROM test_orders o
INNER JOIN patients p ON o.patient_id = p.patient_id
INNER JOIN cbc_results c ON o.order_id = c.order_id
WHERE c.hemoglobin < 13.0
ORDER BY c.hemoglobin;

-- Q13: JOIN - Full Patient Diagnostic Summary (4-table JOIN)
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
FROM patients p
JOIN test_orders o ON p.patient_id = o.patient_id
JOIN test_catalog t ON o.test_id = t.test_id
LEFT JOIN cbc_results c ON o.order_id = c.order_id
LEFT JOIN urinalysis_results u ON o.order_id = u.order_id
LEFT JOIN fecalysis_results f ON o.order_id = f.order_id
ORDER BY p.patient_id, o.order_date;


-- =====================================================
-- SECTION 3: AGGREGATE QUERIES (2 Required: SUM, AVG, COUNT)
-- =====================================================

-- Q14: AGGREGATE - Total revenue by test type (SUM + GROUP BY)
SELECT
    t.test_name,
    COUNT(o.order_id) AS times_ordered,
    SUM(t.price) AS total_revenue
FROM test_catalog t
JOIN test_orders o ON t.test_id = o.test_id
GROUP BY t.test_id, t.test_name
ORDER BY total_revenue DESC;

-- Q15: AGGREGATE - Average lab values by patient demographic (AVG + COUNT)
SELECT
    p.sex,
    COUNT(DISTINCT p.patient_id) AS patient_count,
    AVG(c.hemoglobin) AS avg_hemoglobin,
    AVG(c.platelets) AS avg_platelets,
    ROUND(AVG(c.wbc), 2) AS avg_wbc
FROM patients p
JOIN test_orders o ON p.patient_id = o.patient_id
JOIN cbc_results c ON o.order_id = c.order_id
GROUP BY p.sex;


-- =====================================================
-- SECTION 4: SUBQUERIES (2 Required)
-- =====================================================

-- Q16: SUBQUERY - Patients who had CBC but NOT Urinalysis
SELECT patient_id,
       CONCAT(first_name, ' ', last_name) AS patient_name
FROM patients
WHERE patient_id IN (
    SELECT DISTINCT patient_id
    FROM test_orders
    WHERE test_id = (SELECT test_id FROM test_catalog WHERE test_name = 'CBC')
)
AND patient_id NOT IN (
    SELECT DISTINCT patient_id
    FROM test_orders
    WHERE test_id = (SELECT test_id FROM test_catalog WHERE test_name = 'URINALYSIS')
)
ORDER BY patient_id;

-- Q17: SUBQUERY - Find most expensive test ordered per patient
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    (
        SELECT MAX(t.price)
        FROM test_orders o2
        JOIN test_catalog t ON o2.test_id = t.test_id
        WHERE o2.patient_id = p.patient_id
    ) AS max_test_price
FROM patients p
WHERE EXISTS (
    SELECT 1
    FROM test_orders o3
    WHERE o3.patient_id = p.patient_id
)
ORDER BY max_test_price DESC;


-- =====================================================
-- SECTION 5: UPDATE QUERIES (2 Required)
-- =====================================================

-- Q18: UPDATE - Change patient contact number
UPDATE patients
SET contact = '09179998888',
    address = 'Updated: Makati City, Metro Manila'
WHERE patient_id = 'PAT-001';

-- Q19: UPDATE - Mark pending orders as completed
-- This update only changes status; order_date and created_at remain unchanged
-- Completion time is not captured in this schema; add a completed_at column if needed
UPDATE test_orders
SET status = 'COMPLETED'
WHERE status = 'PENDING'
  AND order_date <= CURDATE() - INTERVAL 7 DAY;


-- =====================================================
-- SECTION 6: DELETE QUERIES (2 Required)
-- =====================================================

-- Q20: DELETE - Remove cancelled test orders (with CASCADE)
-- Note: Due to ON DELETE CASCADE, related results will auto-delete
DELETE FROM test_orders
WHERE status = 'CANCELLED';

-- Q21: DELETE - Remove a specific test order for a patient
-- Example cleanup: remove PAT-004's fecalysis order
DELETE FROM test_orders
WHERE patient_id = 'PAT-004'
  AND test_id = (
      SELECT test_id
      FROM test_catalog
      WHERE test_name = 'FECALYSIS'
      ORDER BY test_id
      LIMIT 1
  );


-- =====================================================
-- SECTION 7: QUERY OPTIMIZATION
-- =====================================================
-- Apply appropriate optimization techniques such as:
-- indexing, EXPLAIN/EXPLAIN ANALYZE, query rewriting,
-- efficient joins, and partitioning.

-- O1: Create indexes on frequently filtered and joined columns.
CREATE INDEX idx_patients_age
    ON patients(age);

CREATE INDEX idx_patients_last_name_first_name
    ON patients(last_name, first_name);

CREATE INDEX idx_test_orders_patient_id
    ON test_orders(patient_id);

CREATE INDEX idx_test_orders_test_id
    ON test_orders(test_id);

CREATE INDEX idx_test_orders_status_order_date
    ON test_orders(status, order_date);

CREATE INDEX idx_cbc_results_order_id
    ON cbc_results(order_id);

CREATE INDEX idx_cbc_results_hemoglobin
    ON cbc_results(hemoglobin);

CREATE INDEX idx_urinalysis_results_order_id
    ON urinalysis_results(order_id);

CREATE INDEX idx_urinalysis_results_protein
    ON urinalysis_results(protein);

CREATE INDEX idx_fecalysis_results_order_id
    ON fecalysis_results(order_id);

CREATE INDEX idx_fecalysis_results_parasite_id
    ON fecalysis_results(parasite_id);

CREATE INDEX idx_test_catalog_price
    ON test_catalog(price);

-- O2: EXPLAIN query plan for a frequently used JOIN query.
EXPLAIN
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    t.test_name,
    o.order_date,
    o.status
FROM patients p
JOIN test_orders o ON p.patient_id = o.patient_id
JOIN test_catalog t ON o.test_id = t.test_id
WHERE p.age BETWEEN 20 AND 30
  AND o.status = 'COMPLETED'
ORDER BY o.order_date DESC;

-- O3: Query rewrite for better efficiency.
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    MAX(t.price) AS max_test_price
FROM patients p
JOIN test_orders o ON p.patient_id = o.patient_id
JOIN test_catalog t ON o.test_id = t.test_id
GROUP BY p.patient_id, p.first_name, p.last_name
ORDER BY max_test_price DESC;

-- O4: Partitioning strategy for very large tables.
-- Example for a large-scale production system:
-- ALTER TABLE test_orders
-- PARTITION BY RANGE (YEAR(order_date)) (
--     PARTITION p2023 VALUES LESS THAN (2024),
--     PARTITION p2024 VALUES LESS THAN (2025),
--     PARTITION p2025 VALUES LESS THAN (2026),
--     PARTITION p_future VALUES LESS THAN MAXVALUE
-- );

-- End of optimization section.
