from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
import pymysql
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'

DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'patient_db',
    'cursorclass': pymysql.cursors.DictCursor
}

def get_db_connection():
    return pymysql.connect(**DB_CONFIG)

@app.route('/')
def menu():
    return render_template('menu.html')

@app.route('/patient-info')
def patient_info():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.*, 
                       GROUP_CONCAT(DISTINCT t.test_name) as tests_taken,
                       MAX(o.order_date) as last_visit
                FROM patients p
                LEFT JOIN test_orders o ON p.patient_id = o.patient_id
                LEFT JOIN test_catalog t ON o.test_id = t.test_id
                GROUP BY p.patient_id
                ORDER BY p.last_name
            """
            cursor.execute(sql)
            patients = cursor.fetchall()
        return render_template('patient_info.html', patients=patients)
    finally:
        conn.close()

@app.route('/patients')
def patients():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM patients ORDER BY last_name")
            patients = cursor.fetchall()
        return render_template('patients.html', patients=patients)
    finally:
        conn.close()

@app.route('/patients/edit/<patient_id>', methods=['GET', 'POST'])
def edit_patient(patient_id):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            first_name = request.form['first_name']
            last_name = request.form['last_name']
            age = request.form['age']
            sex = request.form['sex']
            address = request.form['address']
            contact = request.form['contact']

            with conn.cursor() as cursor:
                sql = """
                    UPDATE patients
                    SET first_name=%s, last_name=%s, age=%s, sex=%s, address=%s, contact=%s
                    WHERE patient_id=%s
                """
                cursor.execute(sql, (first_name, last_name, age, sex, address, contact, patient_id))
                conn.commit()
            flash('Patient updated successfully!', 'success')
            return redirect(url_for('patients'))

        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM patients WHERE patient_id = %s", (patient_id,))
            patient = cursor.fetchone()
        if not patient:
            flash('Patient not found.', 'warning')
            return redirect(url_for('patients'))
        return render_template('edit_patient.html', patient=patient)
    finally:
        conn.close()

@app.route('/patients/delete/<patient_id>', methods=['POST'])
def delete_patient(patient_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM patients WHERE patient_id = %s", (patient_id,))
            conn.commit()
        flash('Patient deleted successfully!', 'success')
    finally:
        conn.close()
    return redirect(url_for('patients'))

@app.route('/billing/<patient_id>')
def billing(patient_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM patients WHERE patient_id = %s", (patient_id,))
            patient = cursor.fetchone()

            sql = """
                SELECT o.order_id, o.order_date, t.test_name, t.price
                FROM test_orders o
                JOIN test_catalog t ON o.test_id = t.test_id
                WHERE o.patient_id = %s
                ORDER BY o.order_date
            """
            cursor.execute(sql, (patient_id,))
            orders = cursor.fetchall()

            total = sum(order['price'] for order in orders)

        return render_template('billing.html', patient=patient, orders=orders, total=total, current_date=datetime.now())
    finally:
        conn.close()

@app.route('/cbc-records')
def cbc_records():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, c.*
                FROM cbc_results c
                JOIN test_orders o ON c.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                ORDER BY o.order_date
            """
            cursor.execute(sql)
            cbc_records = cursor.fetchall()
        return render_template('cbc_records.html', records=cbc_records)
    finally:
        conn.close()

@app.route('/cbc-result/<int:order_id>')
def cbc_result(order_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, p.first_name, p.last_name, p.age, o.order_date, c.*
                FROM cbc_results c
                JOIN test_orders o ON c.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE c.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        return render_template('cbc_result.html', result=result)
    finally:
        conn.close()

@app.route('/cbc-edit/<int:order_id>', methods=['GET', 'POST'])
def edit_cbc(order_id):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            fields = ['wbc', 'rbc', 'hemoglobin', 'hematocrit', 'platelets', 'mcv', 'mch', 'neutrophils', 'lymphocytes', 'monocytes', 'eosinophils', 'basophils']
            values = [request.form.get(f, 0) for f in fields]
            with conn.cursor() as cursor:
                sql = """
                    UPDATE cbc_results
                    SET wbc=%s, rbc=%s, hemoglobin=%s, hematocrit=%s, platelets=%s, mcv=%s, mch=%s,
                        neutrophils=%s, lymphocytes=%s, monocytes=%s, eosinophils=%s, basophils=%s
                    WHERE order_id=%s
                """
                cursor.execute(sql, values + [order_id])
                conn.commit()
            flash('CBC results updated successfully!', 'success')
            return redirect(url_for('cbc_records'))

        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, c.*
                FROM cbc_results c
                JOIN test_orders o ON c.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE c.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        if not result:
            flash('CBC record not found.', 'warning')
            return redirect(url_for('cbc_records'))
        return render_template('edit_cbc.html', result=result)
    finally:
        conn.close()

@app.route('/urinalysis-records')
def urinalysis_records():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, u.*
                FROM urinalysis_results u
                JOIN test_orders o ON u.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                ORDER BY o.order_date
            """
            cursor.execute(sql)
            records = cursor.fetchall()
        return render_template('urinalysis_records.html', records=records)
    finally:
        conn.close()

@app.route('/ua-result/<int:order_id>')
def ua_result(order_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, p.first_name, p.last_name, p.age, o.order_date, u.*
                FROM urinalysis_results u
                JOIN test_orders o ON u.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE u.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        return render_template('ua_result.html', result=result)
    finally:
        conn.close()

@app.route('/ua-edit/<int:order_id>', methods=['GET', 'POST'])
def edit_urinalysis(order_id):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            fields = ['appearance', 'color', 'ph', 'specific_gravity', 'glucose', 'protein', 'ketones', 'nitrites', 'other_findings']
            values = [request.form.get(f, '') for f in fields]
            with conn.cursor() as cursor:
                sql = """
                    UPDATE urinalysis_results
                    SET appearance=%s, color=%s, ph=%s, specific_gravity=%s, glucose=%s, protein=%s,
                        ketones=%s, nitrites=%s, other_findings=%s
                    WHERE order_id=%s
                """
                cursor.execute(sql, values + [order_id])
                conn.commit()
            flash('Urinalysis results updated successfully!', 'success')
            return redirect(url_for('urinalysis_records'))

        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, u.*
                FROM urinalysis_results u
                JOIN test_orders o ON u.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE u.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        if not result:
            flash('Urinalysis record not found.', 'warning')
            return redirect(url_for('urinalysis_records'))
        return render_template('edit_urinalysis.html', result=result)
    finally:
        conn.close()

@app.route('/fecalysis-records')
def fecalysis_records():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, f.*
                FROM fecalysis_results f
                JOIN test_orders o ON f.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                ORDER BY o.order_date
            """
            cursor.execute(sql)
            records = cursor.fetchall()
        return render_template('fecalysis_records.html', records=records)
    finally:
        conn.close()

@app.route('/fa-result/<int:order_id>')
def fa_result(order_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, p.first_name, p.last_name, p.age, o.order_date, f.*
                FROM fecalysis_results f
                JOIN test_orders o ON f.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE f.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        return render_template('fa_result.html', result=result)
    finally:
        conn.close()

@app.route('/fa-edit/<int:order_id>', methods=['GET', 'POST'])
def edit_fecalysis(order_id):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            fields = ['appearance', 'consistency', 'occult_blood', 'parasite_id', 'wbc', 'rbc', 'bacteria', 'other_findings']
            values = [request.form.get(f, '') for f in fields]
            with conn.cursor() as cursor:
                sql = """
                    UPDATE fecalysis_results
                    SET appearance=%s, consistency=%s, occult_blood=%s, parasite_id=%s, wbc=%s, rbc=%s,
                        bacteria=%s, other_findings=%s
                    WHERE order_id=%s
                """
                cursor.execute(sql, values + [order_id])
                conn.commit()
            flash('Fecalysis results updated successfully!', 'success')
            return redirect(url_for('fecalysis_records'))

        with conn.cursor() as cursor:
            sql = """
                SELECT p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as name,
                       o.order_date, f.*
                FROM fecalysis_results f
                JOIN test_orders o ON f.order_id = o.order_id
                JOIN patients p ON o.patient_id = p.patient_id
                WHERE f.order_id = %s
            """
            cursor.execute(sql, (order_id,))
            result = cursor.fetchone()
        if not result:
            flash('Fecalysis record not found.', 'warning')
            return redirect(url_for('fecalysis_records'))
        return render_template('edit_fecalysis.html', result=result)
    finally:
        conn.close()

@app.route('/patients/add', methods=['GET', 'POST'])
def add_patient():
    if request.method == 'POST':
        patient_id = request.form['patient_id']
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        age = request.form['age']
        sex = request.form['sex']
        address = request.form['address']
        contact = request.form['contact']

        conn = get_db_connection()
        try:
            with conn.cursor() as cursor:
                sql = """INSERT INTO patients (patient_id, first_name, last_name, age, sex, address, contact)
                         VALUES (%s, %s, %s, %s, %s, %s, %s)"""
                cursor.execute(sql, (patient_id, first_name, last_name, age, sex, address, contact))
                conn.commit()
            flash('Patient added successfully!', 'success')
            return redirect(url_for('patient_info'))
        except Exception as e:
            flash(f'Error: {str(e)}', 'danger')
        finally:
            conn.close()
    return render_template('add_patient.html')

@app.route('/add-order', methods=['GET', 'POST'])
def add_order():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT patient_id, CONCAT(first_name, ' ', last_name) as full_name FROM patients ORDER BY last_name")
            patients = cursor.fetchall()
            cursor.execute("SELECT test_id, test_name FROM test_catalog WHERE test_name IN ('CBC', 'URINALYSIS', 'FECALYSIS')")
            tests = cursor.fetchall()

        if request.method == 'POST':
            patient_id = request.form['patient_id']
            test_id = request.form['test_id']
            order_date = request.form['order_date']

            with conn.cursor() as cursor:
                cursor.execute("INSERT INTO test_orders (patient_id, test_id, order_date, status) VALUES (%s, %s, %s, 'COMPLETED')",
                               (patient_id, test_id, order_date))
                order_id = cursor.lastrowid
                conn.commit()

            test_name = next(t['test_name'] for t in tests if t['test_id'] == int(test_id))
            return redirect(url_for('add_result', order_id=order_id, test_type=test_name))

        return render_template('add_order.html', patients=patients, tests=tests)
    finally:
        conn.close()

@app.route('/add-result/<int:order_id>/<test_type>', methods=['GET', 'POST'])
def add_result(order_id, test_type):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            with conn.cursor() as cursor:
                if test_type == 'CBC':
                    fields = ['wbc', 'rbc', 'hemoglobin', 'hematocrit', 'platelets', 'mcv', 'mch', 'neutrophils', 'lymphocytes', 'monocytes', 'eosinophils', 'basophils']
                    values = [request.form.get(f, 0) for f in fields]
                    sql = f"INSERT INTO cbc_results (order_id, {', '.join(fields)}) VALUES (%s, {', '.join(['%s']*len(fields))})"
                elif test_type == 'URINALYSIS':
                    fields = ['appearance', 'color', 'ph', 'specific_gravity', 'glucose', 'protein', 'ketones', 'nitrites', 'other_findings']
                    values = [request.form.get(f, '') for f in fields]
                    sql = f"INSERT INTO urinalysis_results (order_id, {', '.join(fields)}) VALUES (%s, {', '.join(['%s']*len(fields))})"
                elif test_type == 'FECALYSIS':
                    fields = ['appearance', 'consistency', 'occult_blood', 'parasite_id', 'wbc', 'rbc', 'bacteria', 'other_findings']
                    values = [request.form.get(f, '') for f in fields]
                    sql = f"INSERT INTO fecalysis_results (order_id, {', '.join(fields)}) VALUES (%s, {', '.join(['%s']*len(fields))})"

                cursor.execute(sql, [order_id] + values)
                conn.commit()
            flash('Lab results added successfully!', 'success')
            return redirect(url_for('patient_info'))

        return render_template('add_result.html', order_id=order_id, test_type=test_type)
    finally:
        conn.close()

@app.route('/tests')
def manage_tests():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM test_catalog ORDER BY test_name")
            tests = cursor.fetchall()
        return render_template('tests.html', tests=tests)
    finally:
        conn.close()

@app.route('/tests/edit/<int:test_id>', methods=['GET', 'POST'])
def edit_test(test_id):
    conn = get_db_connection()
    try:
        if request.method == 'POST':
            test_name = request.form['test_name']
            price = request.form['price']
            description = request.form['description']
            with conn.cursor() as cursor:
                sql = """
                    UPDATE test_catalog
                    SET test_name=%s, price=%s, description=%s
                    WHERE test_id=%s
                """
                cursor.execute(sql, (test_name, price, description, test_id))
                conn.commit()
            flash('Test catalog updated successfully!', 'success')
            return redirect(url_for('manage_tests'))

        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM test_catalog WHERE test_id = %s", (test_id,))
            test = cursor.fetchone()
        if not test:
            flash('Test not found.', 'warning')
            return redirect(url_for('manage_tests'))
        return render_template('edit_test.html', test=test)
    finally:
        conn.close()

@app.route('/orders')
def manage_orders():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT o.order_id, o.order_date, o.status,
                       p.patient_id, CONCAT(p.first_name, ' ', p.last_name) as patient_name,
                       t.test_id, t.test_name
                FROM test_orders o
                JOIN patients p ON o.patient_id = p.patient_id
                JOIN test_catalog t ON o.test_id = t.test_id
                ORDER BY o.order_date DESC
            """
            cursor.execute(sql)
            orders = cursor.fetchall()
        return render_template('orders.html', orders=orders)
    finally:
        conn.close()

@app.route('/orders/edit/<int:order_id>', methods=['GET', 'POST'])
def edit_order(order_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT patient_id, CONCAT(first_name, ' ', last_name) as full_name FROM patients ORDER BY last_name")
            patients = cursor.fetchall()
            cursor.execute("SELECT test_id, test_name FROM test_catalog ORDER BY test_name")
            tests = cursor.fetchall()

        if request.method == 'POST':
            patient_id = request.form['patient_id']
            test_id = request.form['test_id']
            order_date = request.form['order_date']
            status = request.form['status']
            with conn.cursor() as cursor:
                sql = """
                    UPDATE test_orders
                    SET patient_id=%s, test_id=%s, order_date=%s, status=%s
                    WHERE order_id=%s
                """
                cursor.execute(sql, (patient_id, test_id, order_date, status, order_id))
                conn.commit()
            flash('Test order updated successfully!', 'success')
            return redirect(url_for('manage_orders'))

        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM test_orders WHERE order_id = %s", (order_id,))
            order = cursor.fetchone()
        if not order:
            flash('Test order not found.', 'warning')
            return redirect(url_for('manage_orders'))
        return render_template('edit_order.html', order=order, patients=patients, tests=tests)
    finally:
        conn.close()

if __name__ == '__main__':
    app.run(debug=True)