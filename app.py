import hmac
import os
import re
import secrets
from datetime import datetime
from decimal import Decimal, InvalidOperation
from functools import wraps

import pymysql
from flask import Flask, abort, flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', 'development-only-change-this-secret')
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='Lax',
    SESSION_COOKIE_SECURE=os.environ.get('SESSION_COOKIE_SECURE', '').lower() == 'true',
)

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', '3306')),
    'user': os.environ.get('DB_USER', 'patient_app'),
    'password': os.environ.get('DB_PASSWORD', ''),
    'database': os.environ.get('DB_NAME', 'patient_db'),
    'cursorclass': pymysql.cursors.DictCursor,
    'autocommit': False,
    'charset': 'utf8mb4',
}
ADMIN_DB_CONFIG = {
    **DB_CONFIG,
    'user': os.environ.get('DB_ADMIN_USER', DB_CONFIG['user']),
    'password': os.environ.get('DB_ADMIN_PASSWORD', DB_CONFIG['password']),
}
ENCRYPTION_KEY = os.environ.get('PATIENT_ENCRYPTION_KEY')
ALLOWED_ROLES = ('role_admin', 'role_front_desk', 'role_lab_tech', 'role_doctor', 'role_patient')
ROLE_NAMES = {
    'role_admin': 'Admin',
    'role_front_desk': 'Front desk',
    'role_lab_tech': 'Lab technician',
    'role_doctor': 'Doctor',
    'role_patient': 'Patient',
}
IDENTIFIER_RE = re.compile(r'^[A-Za-z0-9_.-]{1,80}$')
APP_USERNAME_RE = re.compile(r'^[^\s\x00-\x1f\x7f]{1,80}$')


def get_db_connection(admin=False):
    return pymysql.connect(**(ADMIN_DB_CONFIG if admin else DB_CONFIG))


def close_connection(connection):
    if connection is not None:
        connection.close()


def csrf_token():
    token = session.get('_csrf_token')
    if not token:
        token = secrets.token_urlsafe(32)
        session['_csrf_token'] = token
    return token


@app.context_processor
def inject_template_context():
    return {'current_user': getattr(g, 'current_user', None), 'csrf_token': csrf_token, 'role_names': ROLE_NAMES}


@app.before_request
def load_current_user_and_protect_forms():
    g.current_user = None
    user_id = session.get('user_id')
    if user_id is not None:
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT user_id, username, password_hash, role_name, patient_id, mysql_username FROM app_users WHERE user_id=%s AND is_active=1",
                    (user_id,),
                )
                g.current_user = cursor.fetchone()
        finally:
            close_connection(connection)
        if g.current_user is None:
            session.clear()
    if request.method == 'POST':
        supplied = request.form.get('csrf_token') or request.headers.get('X-CSRFToken')
        expected = session.get('_csrf_token')
        if not supplied or not expected or not hmac.compare_digest(supplied, expected):
            abort(400, description='Invalid or missing CSRF token.')


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if g.current_user is None:
            return redirect(url_for('login', next=request.full_path))
        return view(*args, **kwargs)
    return wrapped


def roles_required(*allowed_roles):
    def decorator(view):
        @wraps(view)
        @login_required
        def wrapped(*args, **kwargs):
            if g.current_user['role_name'] not in allowed_roles:
                return render_template('unauthorized.html'), 403
            return view(*args, **kwargs)
        return wrapped
    return decorator


def require_encryption_key():
    if not ENCRYPTION_KEY:
        raise RuntimeError('PATIENT_ENCRYPTION_KEY is not configured.')
    return ENCRYPTION_KEY


def encrypted_update(cursor, table, id_column, row_id, plaintext_column, encrypted_column, token_column, value):
    key = require_encryption_key()
    cursor.execute("SET block_encryption_mode='aes-256-cbc'")
    cursor.execute('SET @app_row_iv=RANDOM_BYTES(16)')
    cursor.execute(
        f"UPDATE `{table}` SET `{plaintext_column}`=%s, `{encrypted_column}`=AES_ENCRYPT(%s,%s,@app_row_iv), encryption_iv=@app_row_iv, `{token_column}`=SHA2(%s,256) WHERE `{id_column}`=%s",
        (value, value, key, value, row_id),
    )


def encrypted_insert(cursor, table, columns, values, encrypted_column, token_column, value):
    key = require_encryption_key()
    cursor.execute("SET block_encryption_mode='aes-256-cbc'")
    cursor.execute('SET @app_row_iv=RANDOM_BYTES(16)')
    names = ', '.join(f'`{column}`' for column in columns)
    placeholders = ', '.join(['%s'] * len(values))
    cursor.execute(
        f"INSERT INTO `{table}` ({names}, `{encrypted_column}`, encryption_iv, `{token_column}`) VALUES ({placeholders}, AES_ENCRYPT(%s,%s,@app_row_iv), @app_row_iv, SHA2(%s,256))",
        tuple(values) + (value, key, value),
    )


def parse_amount(value):
    try:
        amount = Decimal(value).quantize(Decimal('0.01'))
    except (InvalidOperation, TypeError):
        raise ValueError('Amount must be a valid number.')
    if amount <= 0:
        raise ValueError('Amount must be greater than zero.')
    return amount


def safe_identifier(value):
    if not value or not IDENTIFIER_RE.fullmatch(value):
        raise ValueError('Invalid database account identifier.')
    return value


def safe_app_username(value):
    if not value or not APP_USERNAME_RE.fullmatch(value):
        raise ValueError('Username must be 1-80 characters without spaces or control characters.')
    return value


def default_mysql_username(app_username):
    identifier = re.sub(r'[^A-Za-z0-9_.-]', '_', app_username)
    return safe_identifier(identifier[:80])


def next_patient_id(cursor):
    cursor.execute("SELECT patient_id FROM clinic_patients WHERE patient_id REGEXP '^PAT-[0-9]+$' FOR UPDATE")
    used_ids = set()
    for row in cursor.fetchall():
        match = re.fullmatch(r'PAT-(\d+)', row['patient_id'])
        if match:
            used_ids.add(int(match.group(1)))
    candidate = 1
    while candidate in used_ids:
        candidate += 1
    return f'PAT-{candidate:03d}'


@app.route('/login', methods=['GET', 'POST'])
def login():
    if g.current_user is not None:
        if g.current_user['role_name'] == 'role_patient':
            return redirect(url_for('patient_portal'))
        return redirect(url_for('menu'))
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT user_id, username, password_hash, role_name, patient_id, mysql_username FROM app_users WHERE username=%s AND is_active=1", (username,))
                user = cursor.fetchone()
        finally:
            close_connection(connection)
        if user and check_password_hash(user['password_hash'], password):
            session.clear()
            session['user_id'] = user['user_id']
            csrf_token()
            if user['role_name'] == 'role_patient':
                return redirect(url_for('patient_portal'))
            next_url = request.args.get('next', '')
            if not next_url.startswith('/') or next_url.startswith('//'):
                next_url = url_for('menu')
            return redirect(next_url)
        flash('Invalid username or password.', 'danger')
    return render_template('login.html')


@app.post('/logout')
@login_required
def logout():
    session.clear()
    flash('You have been signed out.', 'success')
    return redirect(url_for('login'))


@app.route('/')
@login_required
def menu():
    if g.current_user['role_name'] == 'role_patient':
        return render_template('unauthorized.html'), 403
    return render_template('menu.html')


@app.route('/patient-info')
@roles_required('role_admin', 'role_front_desk')
def patient_info():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""SELECT p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address,
                       p.registered_at, GROUP_CONCAT(DISTINCT t.test_name) AS tests_taken, MAX(o.order_date) AS last_visit
                       FROM clinic_patients p LEFT JOIN lab_test o ON p.patient_id=o.patient_id
                       LEFT JOIN lab_test_catalog t ON o.test_id=t.test_id
                       GROUP BY p.patient_id, p.first_name, p.last_name, p.age, p.sex, p.address, p.registered_at
                       ORDER BY p.last_name, p.first_name""")
            patient_rows = cursor.fetchall()
        return render_template('patient_info.html', patients=patient_rows)
    finally:
        close_connection(connection)


@app.route('/patients')
@roles_required('role_admin', 'role_front_desk')
def patients():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT patient_id, first_name, last_name, age, sex, address, registered_at FROM clinic_patients ORDER BY last_name, first_name')
            patient_rows = cursor.fetchall()
        return render_template('patients.html', patients=patient_rows)
    finally:
        close_connection(connection)


@app.route('/patients/add', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk')
def add_patient():
    fields = ('patient_id', 'first_name', 'last_name', 'age', 'sex', 'address', 'contact')
    connection = get_db_connection()
    patient_id = None
    try:
        with connection.cursor() as cursor:
            patient_id = next_patient_id(cursor)
            if request.method == 'POST':
                values = (patient_id,) + tuple(request.form.get(field, '').strip() for field in fields[1:])
                encrypted_insert(cursor, 'clinic_patients', fields, values, 'contact_encrypted', 'contact_token_hash', values[-1])
                connection.commit()
                flash(f'Patient {patient_id} added successfully.', 'success')
                return redirect(url_for('patient_info'))
        return render_template('add_patient.html', next_patient_id=patient_id)
    except (pymysql.MySQLError, ValueError, RuntimeError) as error:
        connection.rollback()
        flash(f'Unable to add patient: {error}', 'danger')
        return render_template('add_patient.html', next_patient_id=patient_id)
    finally:
        close_connection(connection)


@app.route('/patients/edit/<patient_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk')
def edit_patient(patient_id):
    connection = get_db_connection()
    try:
        if request.method == 'POST':
            with connection.cursor() as cursor:
                cursor.execute('UPDATE clinic_patients SET first_name=%s,last_name=%s,age=%s,sex=%s,address=%s WHERE patient_id=%s', tuple(request.form.get(field, '').strip() for field in ('first_name', 'last_name', 'age', 'sex', 'address')) + (patient_id,))
                encrypted_update(cursor, 'clinic_patients', 'patient_id', patient_id, 'contact', 'contact_encrypted', 'contact_token_hash', request.form.get('contact', '').strip())
            connection.commit()
            flash('Patient updated successfully.', 'success')
            return redirect(url_for('patients'))
        with connection.cursor() as cursor:
            cursor.execute('SELECT patient_id, first_name, last_name, age, sex, address, CONVERT(AES_DECRYPT(contact_encrypted,%s,encryption_iv) USING utf8mb4) AS contact FROM clinic_patients WHERE patient_id=%s', (require_encryption_key(), patient_id))
            patient = cursor.fetchone()
        if not patient:
            abort(404)
        return render_template('edit_patient.html', patient=patient)
    finally:
        close_connection(connection)


@app.post('/patients/delete/<patient_id>')
@roles_required('role_admin')
def delete_patient(patient_id):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM clinic_patients WHERE patient_id=%s', (patient_id,))
        connection.commit()
        flash('Patient deleted successfully.', 'success')
    finally:
        close_connection(connection)
    return redirect(url_for('patients'))


@app.route('/billing/<patient_id>')
@roles_required('role_admin', 'role_front_desk')
def billing(patient_id):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT patient_id, first_name, last_name FROM clinic_patients WHERE patient_id=%s', (patient_id,))
            patient = cursor.fetchone()
            if not patient:
                abort(404)
            cursor.execute("""SELECT o.order_id, o.order_date, t.test_name, t.price,
                       COALESCE(SUM(CASE WHEN p.status<>'REFUNDED' THEN p.amount_paid ELSE 0 END),0) AS paid
                       FROM lab_test o JOIN lab_test_catalog t ON o.test_id=t.test_id LEFT JOIN payments p ON p.order_id=o.order_id
                       WHERE o.patient_id=%s GROUP BY o.order_id,o.order_date,t.test_name,t.price ORDER BY o.order_date""", (patient_id,))
            orders = cursor.fetchall()
        for order in orders:
            order['balance'] = Decimal(order['price']) - Decimal(order['paid'])
        total = sum((Decimal(order['price']) for order in orders), Decimal('0'))
        paid = sum((Decimal(order['paid']) for order in orders), Decimal('0'))
        return render_template('billing.html', patient=patient, orders=orders, total=total, paid=paid, balance=total - paid, current_date=datetime.now())
    finally:
        close_connection(connection)


@app.get('/patient-portal')
@roles_required('role_patient')
def patient_portal():
    patient_id = g.current_user.get('patient_id')
    if not patient_id:
        return render_template('unauthorized.html'), 403
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """SELECT patient_id, first_name, last_name, age, sex, address,
                          CONVERT(AES_DECRYPT(contact_encrypted, %s, encryption_iv) USING utf8mb4) AS contact
                   FROM clinic_patients WHERE patient_id=%s""",
                (require_encryption_key(), patient_id),
            )
            patient = cursor.fetchone()
            if not patient:
                return render_template('unauthorized.html'), 403
            cursor.execute(
                """SELECT o.order_id, o.order_date, o.status, t.test_name, t.price,
                          COALESCE(SUM(CASE WHEN pay.status<>'REFUNDED' THEN pay.amount_paid ELSE 0 END), 0) AS paid,
                          CASE
                            WHEN t.test_name='CBC' THEN CONCAT('Hemoglobin: ', COALESCE(c.hemoglobin, 'Pending'), ', Platelets: ', COALESCE(c.platelets, 'Pending'))
                            WHEN t.test_name='URINALYSIS' THEN CONCAT('Protein: ', COALESCE(u.protein, 'Pending'), ', pH: ', COALESCE(u.ph, 'Pending'))
                            WHEN t.test_name='FECALYSIS' THEN CONCAT('Parasite: ', COALESCE(f.parasite_id, 'Pending'))
                            ELSE 'Pending'
                          END AS result_summary
                   FROM lab_test o
                   JOIN lab_test_catalog t ON o.test_id=t.test_id
                   LEFT JOIN payments pay ON pay.order_id=o.order_id
                   LEFT JOIN cbc c ON c.order_id=o.order_id
                   LEFT JOIN urinalysis u ON u.order_id=o.order_id
                   LEFT JOIN fecalysis f ON f.order_id=o.order_id
                   WHERE o.patient_id=%s
                   GROUP BY o.order_id, o.order_date, o.status, t.test_name, t.price,
                            c.hemoglobin, c.platelets, u.protein, u.ph, f.parasite_id
                   ORDER BY o.order_date DESC, o.order_id DESC""",
                (patient_id,),
            )
            orders = cursor.fetchall()
            cursor.execute(
                """SELECT pay.payment_id, pay.order_id, pay.payment_date, pay.amount_paid,
                          pay.payment_method, pay.status,
                          CONVERT(AES_DECRYPT(pay.receipt_number_encrypted, %s, pay.encryption_iv) USING utf8mb4) AS receipt_number
                   FROM payments pay
                   JOIN lab_test o ON pay.order_id=o.order_id
                   WHERE o.patient_id=%s
                   ORDER BY pay.payment_date DESC, pay.payment_id DESC""",
                (require_encryption_key(), patient_id),
            )
            payments = cursor.fetchall()
        for order in orders:
            order['balance'] = Decimal(order['price']) - Decimal(order['paid'])
        return render_template('patient_portal.html', patient=patient, orders=orders, payments=payments)
    finally:
        close_connection(connection)


@app.route('/payments/<int:order_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk')
def payments(order_id):
    connection = get_db_connection()
    try:
        if request.method == 'POST':
            amount = parse_amount(request.form.get('amount_paid'))
            payment_method = request.form.get('payment_method', 'CASH')
            status = request.form.get('status', 'PAID')
            receipt_number = request.form.get('receipt_number', '').strip() or None
            if payment_method not in {'CASH', 'CARD', 'GCASH', 'INSURANCE'} or status not in {'PAID', 'PARTIAL', 'REFUNDED'}:
                raise ValueError('Invalid payment option.')
            with connection.cursor() as cursor:
                cursor.execute('SELECT t.price FROM lab_test o JOIN lab_test_catalog t ON o.test_id=t.test_id WHERE o.order_id=%s FOR UPDATE', (order_id,))
                order = cursor.fetchone()
                if not order:
                    abort(404)
                cursor.execute("SELECT COALESCE(SUM(CASE WHEN status<>'REFUNDED' THEN amount_paid ELSE 0 END),0) AS paid FROM payments WHERE order_id=%s", (order_id,))
                paid = Decimal(cursor.fetchone()['paid'])
                if status != 'REFUNDED' and paid + amount > Decimal(order['price']):
                    raise ValueError('Payment exceeds the outstanding balance.')
                encrypted_insert(cursor, 'payments', ('order_id', 'amount_paid', 'payment_method', 'receipt_number', 'status'), (order_id, amount, payment_method, receipt_number, status), 'receipt_number_encrypted', 'receipt_token_hash', receipt_number or '')
            connection.commit()
            flash('Payment recorded successfully.', 'success')
            return redirect(url_for('payments', order_id=order_id))
        with connection.cursor() as cursor:
            cursor.execute('SELECT o.order_id,o.patient_id,t.test_name,t.price FROM lab_test o JOIN lab_test_catalog t ON o.test_id=t.test_id WHERE o.order_id=%s', (order_id,))
            order = cursor.fetchone()
            if not order:
                abort(404)
            cursor.execute('SELECT payment_id,amount_paid,payment_method,payment_date,status,CONVERT(AES_DECRYPT(receipt_number_encrypted,%s,encryption_iv) USING utf8mb4) AS receipt_number FROM payments WHERE order_id=%s ORDER BY payment_date DESC', (require_encryption_key(), order_id))
            payment_rows = cursor.fetchall()
        return render_template('payments.html', order=order, payments=payment_rows)
    except (ValueError, InvalidOperation, RuntimeError, pymysql.MySQLError) as error:
        connection.rollback()
        flash(f'Unable to record payment: {error}', 'danger')
        return redirect(url_for('payments', order_id=order_id))
    finally:
        close_connection(connection)


@app.get('/payments')
@roles_required('role_admin', 'role_front_desk')
def payment_records():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """SELECT pay.payment_id, pay.order_id, pay.amount_paid, pay.payment_method,
                          pay.payment_date, pay.status, o.patient_id,
                          CONCAT(cp.first_name, ' ', cp.last_name) AS patient_name,
                          tc.test_name,
                          CONVERT(AES_DECRYPT(pay.receipt_number_encrypted, %s, pay.encryption_iv) USING utf8mb4) AS receipt_number
                   FROM payments pay
                   JOIN lab_test o ON pay.order_id=o.order_id
                   JOIN clinic_patients cp ON o.patient_id=cp.patient_id
                   JOIN lab_test_catalog tc ON o.test_id=tc.test_id
                   ORDER BY pay.payment_date DESC, pay.payment_id DESC""",
                (require_encryption_key(),),
            )
            payment_rows = cursor.fetchall()
        return render_template('payment_records.html', payments=payment_rows)
    finally:
        close_connection(connection)


@app.route('/payments/edit/<int:payment_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk')
def edit_payment(payment_id):
    connection = get_db_connection()
    try:
        if request.method == 'POST':
            amount = parse_amount(request.form.get('amount_paid'))
            payment_method = request.form.get('payment_method', 'CASH')
            status = request.form.get('status', 'PAID')
            receipt_number = request.form.get('receipt_number', '').strip() or None
            if payment_method not in {'CASH', 'CARD', 'GCASH', 'INSURANCE'} or status not in {'PAID', 'PARTIAL', 'REFUNDED'}:
                raise ValueError('Invalid payment option.')
            with connection.cursor() as cursor:
                cursor.execute(
                    'SELECT pay.order_id, tc.price AS total_amount FROM payments pay JOIN lab_test o ON pay.order_id=o.order_id JOIN lab_test_catalog tc ON o.test_id=tc.test_id WHERE pay.payment_id=%s FOR UPDATE',
                    (payment_id,),
                )
                payment = cursor.fetchone()
                if not payment:
                    abort(404)
                cursor.execute(
                    "SELECT COALESCE(SUM(CASE WHEN status<>'REFUNDED' THEN amount_paid ELSE 0 END),0) AS paid FROM payments WHERE order_id=%s AND payment_id<>%s",
                    (payment['order_id'], payment_id),
                )
                paid = Decimal(cursor.fetchone()['paid'])
                if status != 'REFUNDED' and paid + amount > Decimal(payment['total_amount']):
                    raise ValueError('Payment exceeds the outstanding balance.')
                cursor.execute(
                    'UPDATE payments SET amount_paid=%s, payment_method=%s, status=%s WHERE payment_id=%s',
                    (amount, payment_method, status, payment_id),
                )
                encrypted_update(cursor, 'payments', 'payment_id', payment_id, 'receipt_number', 'receipt_number_encrypted', 'receipt_token_hash', receipt_number)
            connection.commit()
            flash('Payment updated successfully.', 'success')
            return redirect(url_for('payment_records'))
        with connection.cursor() as cursor:
            cursor.execute(
                """SELECT pay.payment_id, pay.order_id, pay.amount_paid, pay.payment_method, pay.status,
                          CONVERT(AES_DECRYPT(pay.receipt_number_encrypted, %s, pay.encryption_iv) USING utf8mb4) AS receipt_number,
                          cp.patient_id, CONCAT(cp.first_name, ' ', cp.last_name) AS patient_name, tc.test_name
                   FROM payments pay
                   JOIN lab_test o ON pay.order_id=o.order_id
                   JOIN clinic_patients cp ON o.patient_id=cp.patient_id
                   JOIN lab_test_catalog tc ON o.test_id=tc.test_id
                   WHERE pay.payment_id=%s""",
                (require_encryption_key(), payment_id),
            )
            payment = cursor.fetchone()
        if not payment:
            abort(404)
        return render_template('edit_payment.html', payment=payment)
    except (ValueError, InvalidOperation, RuntimeError, pymysql.MySQLError) as error:
        connection.rollback()
        flash(f'Unable to update payment: {error}', 'danger')
        return redirect(url_for('payment_records'))
    finally:
        close_connection(connection)


@app.post('/payments/delete/<int:payment_id>')
@roles_required('role_admin')
def delete_payment(payment_id):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM payments WHERE payment_id=%s', (payment_id,))
        connection.commit()
        flash('Payment deleted successfully.', 'success')
    finally:
        close_connection(connection)
    return redirect(url_for('payment_records'))


@app.get('/admin/encrypted-records')
@roles_required('role_admin')
def encrypted_records():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """SELECT patient_id, first_name, last_name,
                          CONVERT(AES_DECRYPT(contact_encrypted, %s, encryption_iv) USING utf8mb4) AS contact
                   FROM clinic_patients ORDER BY last_name, first_name""",
                (require_encryption_key(),),
            )
            patients_with_contact = cursor.fetchall()
            cursor.execute(
                """SELECT payment_id, order_id, amount_paid, payment_method, payment_date, status,
                          CONVERT(AES_DECRYPT(receipt_number_encrypted, %s, encryption_iv) USING utf8mb4) AS receipt_number
                   FROM payments ORDER BY payment_date DESC, payment_id DESC""",
                (require_encryption_key(),),
            )
            payments_with_receipts = cursor.fetchall()
        return render_template('encrypted_records.html', patients=patients_with_contact, payments=payments_with_receipts)
    finally:
        close_connection(connection)


def result_query(table, order_id):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(f"SELECT p.patient_id,p.first_name,p.last_name,p.age,o.order_date,r.* FROM `{table}` r JOIN lab_test o ON r.order_id=o.order_id JOIN clinic_patients p ON o.patient_id=p.patient_id WHERE r.order_id=%s", (order_id,))
            return cursor.fetchone()
    finally:
        close_connection(connection)


def result_records(table):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(f"SELECT p.patient_id,CONCAT(p.first_name,' ',p.last_name) AS name,o.order_date,r.* FROM `{table}` r JOIN lab_test o ON r.order_id=o.order_id JOIN clinic_patients p ON o.patient_id=p.patient_id ORDER BY o.order_date")
            return cursor.fetchall()
    finally:
        close_connection(connection)


def edit_result(table, redirect_endpoint, template, order_id, fields):
    connection = get_db_connection()
    try:
        if request.method == 'POST':
            values = [request.form.get(field, '').strip() or None for field in fields]
            assignments = ', '.join(f'`{field}`=%s' for field in fields)
            with connection.cursor() as cursor:
                cursor.execute(f'UPDATE `{table}` SET {assignments} WHERE order_id=%s', values + [order_id])
            connection.commit()
            flash('Laboratory result updated successfully.', 'success')
            return redirect(url_for(redirect_endpoint))
        result = result_query(table, order_id)
        if not result:
            abort(404)
        return render_template(template, result=result)
    finally:
        close_connection(connection)


@app.get('/cbc-records')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def cbc_records():
    return render_template('cbc_records.html', records=result_records('cbc'))


@app.get('/cbc-result/<int:order_id>')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def cbc_result(order_id):
    return render_template('cbc_result.html', result=result_query('cbc', order_id))


@app.route('/cbc-edit/<int:order_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_lab_tech')
def edit_cbc(order_id):
    return edit_result('cbc', 'cbc_records', 'edit_cbc.html', order_id, ['wbc','rbc','hemoglobin','hematocrit','platelets','mcv','mch','neutrophils','lymphocytes','monocytes','eosinophils','basophils'])


@app.get('/urinalysis-records')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def urinalysis_records():
    return render_template('urinalysis_records.html', records=result_records('urinalysis'))


@app.get('/ua-result/<int:order_id>')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def ua_result(order_id):
    return render_template('ua_result.html', result=result_query('urinalysis', order_id))


@app.route('/ua-edit/<int:order_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_lab_tech')
def edit_urinalysis(order_id):
    return edit_result('urinalysis', 'urinalysis_records', 'edit_urinalysis.html', order_id, ['appearance','color','ph','specific_gravity','glucose','protein','ketones','nitrites','other_findings'])


@app.get('/fecalysis-records')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def fecalysis_records():
    return render_template('fecalysis_records.html', records=result_records('fecalysis'))


@app.get('/fa-result/<int:order_id>')
@roles_required('role_admin', 'role_lab_tech', 'role_doctor')
def fa_result(order_id):
    return render_template('fa_result.html', result=result_query('fecalysis', order_id))


@app.route('/fa-edit/<int:order_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_lab_tech')
def edit_fecalysis(order_id):
    return edit_result('fecalysis', 'fecalysis_records', 'edit_fecalysis.html', order_id, ['appearance','consistency','occult_blood','parasite_id','wbc','rbc','bacteria','other_findings'])


@app.route('/add-order', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk', 'role_doctor')
def add_order():
    connection = get_db_connection()
    patient_rows = []
    tests = []
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT patient_id,CONCAT(first_name,' ',last_name) AS full_name FROM clinic_patients ORDER BY last_name,first_name")
            patient_rows = cursor.fetchall()
            cursor.execute("SELECT test_id,test_name FROM lab_test_catalog WHERE test_name IN ('CBC','URINALYSIS','FECALYSIS') ORDER BY test_name")
            tests = cursor.fetchall()
        if request.method == 'POST':
            with connection.cursor() as cursor:
                cursor.execute("INSERT INTO lab_test (patient_id,test_id,order_date,status) VALUES (%s,%s,%s,'PENDING')", (request.form.get('patient_id'), request.form.get('test_id'), request.form.get('order_date')))
                order_id = cursor.lastrowid
                cursor.execute('SELECT test_name FROM lab_test_catalog WHERE test_id=%s', (request.form.get('test_id'),))
                test = cursor.fetchone()
            if not test:
                connection.rollback()
                abort(400)
            result_table = {'CBC': 'cbc', 'URINALYSIS': 'urinalysis', 'FECALYSIS': 'fecalysis'}.get(test['test_name'].upper())
            if not result_table:
                connection.rollback()
                abort(400)
            with connection.cursor() as cursor:
                cursor.execute(f'INSERT INTO `{result_table}` (order_id) VALUES (%s)', (order_id,))
            connection.commit()
            if g.current_user['role_name'] == 'role_doctor':
                flash(f'Test order #{order_id} created successfully.', 'success')
                return redirect(url_for('menu'))
            return redirect(url_for('add_result', order_id=order_id, test_type=test['test_name']))
        return render_template('add_order.html', patients=patient_rows, tests=tests)
    except (pymysql.MySQLError, ValueError) as error:
        connection.rollback()
        flash(f'Unable to create test order: {error}', 'danger')
        return render_template('add_order.html', patients=patient_rows, tests=tests)
    finally:
        close_connection(connection)


@app.route('/add-result/<int:order_id>/<test_type>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_lab_tech')
def add_result(order_id, test_type):
    table_fields = {
        'CBC': ('cbc', ['wbc','rbc','hemoglobin','hematocrit','platelets','mcv','mch','neutrophils','lymphocytes','monocytes','eosinophils','basophils']),
        'URINALYSIS': ('urinalysis', ['appearance','color','ph','specific_gravity','glucose','protein','ketones','nitrites','other_findings']),
        'FECALYSIS': ('fecalysis', ['appearance','consistency','occult_blood','parasite_id','wbc','rbc','bacteria','other_findings']),
    }
    normalized = test_type.upper()
    if normalized not in table_fields:
        abort(400)
    table, fields = table_fields[normalized]
    if request.method == 'POST':
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute('SELECT order_id FROM lab_test WHERE order_id=%s', (order_id,))
                if not cursor.fetchone():
                    abort(404)
                columns = ', '.join(f'`{field}`' for field in fields)
                values = [request.form.get(field, '').strip() or None for field in fields]
                cursor.execute(f'SELECT order_id FROM `{table}` WHERE order_id=%s', (order_id,))
                if cursor.fetchone():
                    assignments = ', '.join(f'`{field}`=%s' for field in fields)
                    cursor.execute(f'UPDATE `{table}` SET {assignments} WHERE order_id=%s', values + [order_id])
                else:
                    placeholders = ', '.join(['%s'] * len(fields))
                    cursor.execute(f'INSERT INTO `{table}` (order_id,{columns}) VALUES (%s,{placeholders})', [order_id] + values)
                cursor.execute("UPDATE lab_test SET status='COMPLETED' WHERE order_id=%s", (order_id,))
            connection.commit()
            flash('Lab results added successfully.', 'success')
            return redirect(url_for('patient_info'))
        finally:
            close_connection(connection)
    return render_template('add_result.html', order_id=order_id, test_type=normalized)


@app.get('/tests')
@roles_required('role_admin', 'role_front_desk')
def manage_tests():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT test_id,test_name,price,description FROM lab_test_catalog ORDER BY test_name')
            tests = cursor.fetchall()
        return render_template('tests.html', tests=tests)
    finally:
        close_connection(connection)


@app.route('/tests/edit/<int:test_id>', methods=['GET', 'POST'])
@roles_required('role_admin')
def edit_test(test_id):
    connection = get_db_connection()
    try:
        if request.method == 'POST':
            with connection.cursor() as cursor:
                cursor.execute('UPDATE lab_test_catalog SET test_name=%s,price=%s,description=%s WHERE test_id=%s', (request.form.get('test_name'), request.form.get('price'), request.form.get('description'), test_id))
            connection.commit()
            flash('Test catalog updated successfully.', 'success')
            return redirect(url_for('manage_tests'))
        with connection.cursor() as cursor:
            cursor.execute('SELECT test_id,test_name,price,description FROM lab_test_catalog WHERE test_id=%s', (test_id,))
            test = cursor.fetchone()
        if not test:
            abort(404)
        return render_template('edit_test.html', test=test)
    finally:
        close_connection(connection)


@app.get('/orders')
@roles_required('role_admin', 'role_front_desk', 'role_lab_tech', 'role_doctor')
def manage_orders():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT o.order_id,o.order_date,o.status,p.patient_id,CONCAT(p.first_name,' ',p.last_name) AS patient_name,t.test_id,t.test_name FROM lab_test o JOIN clinic_patients p ON o.patient_id=p.patient_id JOIN lab_test_catalog t ON o.test_id=t.test_id ORDER BY o.order_date DESC")
            orders = cursor.fetchall()
        return render_template('orders.html', orders=orders)
    finally:
        close_connection(connection)


@app.route('/orders/edit/<int:order_id>', methods=['GET', 'POST'])
@roles_required('role_admin', 'role_front_desk','role_doctor')
def edit_order(order_id):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT patient_id,CONCAT(first_name,' ',last_name) AS full_name FROM clinic_patients ORDER BY last_name,first_name")
            patient_rows = cursor.fetchall()
            cursor.execute('SELECT test_id,test_name FROM lab_test_catalog ORDER BY test_name')
            tests = cursor.fetchall()
        if request.method == 'POST':
            with connection.cursor() as cursor:
                cursor.execute('UPDATE lab_test SET patient_id=%s,test_id=%s,order_date=%s,status=%s WHERE order_id=%s', (request.form.get('patient_id'), request.form.get('test_id'), request.form.get('order_date'), request.form.get('status'), order_id))
            connection.commit()
            flash('Test order updated successfully.', 'success')
            return redirect(url_for('manage_orders'))
        with connection.cursor() as cursor:
            cursor.execute('SELECT order_id,patient_id,test_id,order_date,status FROM lab_test WHERE order_id=%s', (order_id,))
            order = cursor.fetchone()
        if not order:
            abort(404)
        return render_template('edit_order.html', order=order, patients=patient_rows, tests=tests)
    finally:
        close_connection(connection)


@app.route('/admin/users', methods=['GET', 'POST'])
@roles_required('role_admin')
def admin_users():
    if request.method == 'POST':
        try:
            username = safe_app_username(request.form.get('username', '').strip())
            mysql_username_input = request.form.get('mysql_username', '').strip()
            mysql_username = safe_identifier(mysql_username_input) if mysql_username_input else default_mysql_username(username)
        except ValueError as error:
            flash(str(error), 'danger')
            return redirect(url_for('admin_users'))
        password = request.form.get('password', '')
        role_name = request.form.get('role_name', '')
        patient_id = request.form.get('patient_id', '').strip() or None
        if role_name not in ALLOWED_ROLES or len(password) < 12 or (role_name == 'role_patient' and not patient_id):
            abort(400, description='A valid role, password of at least 12 characters, and patient ID for patient accounts are required.')
        connection = get_db_connection()
        admin_connection = get_db_connection(admin=True)
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    """INSERT INTO app_users (username, password_hash, role_name, patient_id, mysql_username)
                       VALUES (%s, %s, %s, %s, %s)""",
                    (username, generate_password_hash(password), role_name, patient_id, mysql_username),
                )
            connection.commit()
            with admin_connection.cursor() as cursor:
                cursor.execute(f"CREATE USER IF NOT EXISTS `{mysql_username}`@'localhost' IDENTIFIED BY %s", (password,))
                cursor.execute(f"GRANT `{role_name}` TO `{mysql_username}`@'localhost'")
                cursor.execute(f"SET DEFAULT ROLE ALL TO `{mysql_username}`@'localhost'")
            admin_connection.commit()
            flash('Application and MySQL user created successfully.', 'success')
        except (pymysql.MySQLError, ValueError) as error:
            connection.rollback()
            admin_connection.rollback()
            flash(f'User creation failed: {error}', 'danger')
        finally:
            close_connection(connection)
            close_connection(admin_connection)
        return redirect(url_for('admin_users'))
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT user_id,username,role_name,patient_id,mysql_username,is_active FROM app_users ORDER BY username')
            users = cursor.fetchall()
        return render_template('admin_users.html', users=users, roles=ALLOWED_ROLES)
    finally:
        close_connection(connection)


@app.post('/admin/users/<int:user_id>/status')
@roles_required('role_admin')
def update_user_status(user_id):
    is_active = request.form.get('is_active') == '1'
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('UPDATE app_users SET is_active=%s WHERE user_id=%s', (is_active, user_id))
            if cursor.rowcount != 1:
                abort(404)
        connection.commit()
        flash('Application account activated.' if is_active else 'Application account deactivated.', 'success')
    finally:
        close_connection(connection)
    return redirect(url_for('admin_users'))


@app.route('/admin/roles', methods=['GET', 'POST'])
@app.route('/roles', methods=['GET', 'POST'])
@roles_required('role_admin')
def admin_roles():
    if request.method == 'POST':
        username = safe_identifier(request.form.get('username', ''))
        role_name = request.form.get('role_name', '')
        action = request.form.get('action', '')
        if role_name not in ALLOWED_ROLES or action not in {'grant', 'revoke'}:
            abort(400)
        connection = get_db_connection(admin=True)
        try:
            statement = 'GRANT' if action == 'grant' else 'REVOKE'
            with connection.cursor() as cursor:
                target_keyword = 'TO' if action == 'grant' else 'FROM'
                cursor.execute(f"{statement} `{role_name}` {target_keyword} `{username}`@'localhost'")
                if action == 'grant':
                    cursor.execute(f"SET DEFAULT ROLE ALL TO `{username}`@'localhost'")
                    cursor.execute('UPDATE app_users SET role_name=%s WHERE mysql_username=%s', (role_name, username))
                else:
                    cursor.execute(f"SET DEFAULT ROLE NONE TO `{username}`@'localhost'")
                    cursor.execute('UPDATE app_users SET is_active=0 WHERE mysql_username=%s AND role_name=%s', (username, role_name))
            connection.commit()
            message = f'{action.title()}ed {ROLE_NAMES[role_name]} for {username}.'
            if action == 'revoke':
                message += ' The matching application account was deactivated.'
            flash(message, 'success')
        except pymysql.MySQLError as error:
            connection.rollback()
            flash(f'Role change failed: {error}', 'danger')
        finally:
            close_connection(connection)
        return redirect(url_for('admin_roles'))
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT user_id,username,role_name,patient_id,mysql_username,is_active FROM app_users ORDER BY username')
            users = cursor.fetchall()
        return render_template('admin_roles.html', users=users, roles=ALLOWED_ROLES)
    finally:
        close_connection(connection)


@app.errorhandler(400)
def bad_request(error):
    return render_template('error.html', code=400, message=error.description), 400


@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', code=404, message='The requested record was not found.'), 404


@app.errorhandler(500)
def server_error(error):
    return render_template('error.html', code=500, message='The request could not be completed.'), 500


if __name__ == '__main__':
    app.run(debug=os.environ.get('FLASK_DEBUG', '').lower() == 'true')
