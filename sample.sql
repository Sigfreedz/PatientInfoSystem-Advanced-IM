CREATE TABLE patients (
    patient_id VARCHAR(10) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    age INT NOT NULL CHECK (age >= 0),
    sex CHAR(1) NOT NULL CHECK (sex IN ('M', 'F')),
    address VARCHAR(150),
    contact VARCHAR(20) UNIQUE,
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE test_catalog (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(50) NOT NULL UNIQUE,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    description VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE test_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id VARCHAR(10) NOT NULL,
    test_id INT NOT NULL,
    order_date DATE NOT NULL,
    status ENUM('PENDING','COMPLETED','CANCELLED') DEFAULT 'COMPLETED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_test FOREIGN KEY (test_id) REFERENCES test_catalog(test_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cbc_results (
    cbc_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    wbc DECIMAL(5,2), rbc DECIMAL(5,2), hemoglobin DECIMAL(5,2),
    hematocrit DECIMAL(5,2), platelets INT, mcv INT, mch INT,
    neutrophils DECIMAL(5,2), lymphocytes DECIMAL(5,2),
    monocytes DECIMAL(5,2), eosinophils DECIMAL(5,2), basophils DECIMAL(5,2),
    CONSTRAINT fk_cbc_order FOREIGN KEY (order_id) REFERENCES test_orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE urinalysis_results (
    ua_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    appearance VARCHAR(50), color VARCHAR(50), ph DECIMAL(3,1),
    specific_gravity DECIMAL(4,3), glucose VARCHAR(20), protein VARCHAR(20),
    ketones VARCHAR(20), nitrites VARCHAR(20), other_findings VARCHAR(100),
    CONSTRAINT fk_ua_order FOREIGN KEY (order_id) REFERENCES test_orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE fecalysis_results (
    fa_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    appearance VARCHAR(50), consistency VARCHAR(50), occult_blood VARCHAR(20),
    parasite_id VARCHAR(50), wbc VARCHAR(20), rbc VARCHAR(20),
    bacteria VARCHAR(20), other_findings VARCHAR(100),
    CONSTRAINT fk_fa_order FOREIGN KEY (order_id) REFERENCES test_orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;