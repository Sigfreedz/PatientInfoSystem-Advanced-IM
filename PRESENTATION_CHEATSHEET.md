# Patient Info System – Rubric Presentation Cheat Sheet

## 1) One-pass run order (setup to demo)
1. `database/renamed_schema.sql`
2. `database/new_seed.sql`
3. `database/rolve_views.sql`
4. `database/encryption.sql`
5. `database/app_auth.sql`
6. `database/role_priveleges.sql`
7. `database/transaction_demo.sql`
8. `database/optimization_demo.sql`
9. Launch Flask app (`app.py`) with `.env` values

---

## 2) Rubric mapping table

| Requirement | Database-level proof | App-level proof | Live demo step |
|---|---|---|---|
| Transaction management (ACID, COMMIT, ROLLBACK, consistency, errors) | `database/transaction_demo.sql` (COMMIT + forced ROLLBACK, `FOR UPDATE`) | `app.py` payment and edit flows use commit/rollback patterns (`/payments`, `/payments/edit`) | Run transaction demo scripts; then trigger overpayment in app and show rejection/no partial write |
| Sensitive data + encryption/decryption | `database/encryption.sql` (AES-256-CBC, per-row IV, token hash, decrypt queries) | Admin-only decrypted records page (`/admin/encrypted-records`) and encrypted payment/patient writes | Show ciphertext/IV/token query then admin decrypted view |
| Users, roles, GRANT/REVOKE, least privilege | `database/role_priveleges.sql` role matrix + deny checks | Route guards in `app.py` via `roles_required`, role management UI `/admin/roles` | Login as two roles and show allowed/denied actions, plus grant/revoke impact |
| Optimization (indexing, EXPLAIN, query efficiency) | `database/optimization_demo.sql` baseline EXPLAIN + index creation + post-index EXPLAIN | Queries tied to pages: `/patient-info`, `/billing/<patient_id>`, `/payments` | Run baseline/post-index plan sections and cite improved access paths |
| Functional/coherent integration and technical correctness | `sample.sql` clean bundle and live-name smoke checks | Flask queries already on live schema names (`clinic_patients`, `lab_test`, etc.) | Use one flow from patient registration → order → result/payment → reporting |

---

## 3) What to say per rubric area

### A. Transaction management
- We enforce atomicity by grouping related operations in one transaction.
- We use `FOR UPDATE` to prevent race conditions while validating cumulative payments.
- We demonstrate both success (`COMMIT`) and failure (`ROLLBACK`) paths.

### B. Encryption
- Sensitive fields are encrypted at rest with AES-256-CBC.
- Per-row random IV ensures same plaintext produces different ciphertext.
- SHA-256 token hash allows indexed lookup without decrypting every row.

### C. Least privilege
- We define role-scoped privileges by job responsibility.
- Front desk, lab tech, doctor, patient, admin each get minimal required access.
- We prove deny behavior (`ERROR 1142`) for out-of-scope actions.

### D. Optimization
- We selected heavy app queries and measured plans before optimization.
- We added targeted indexes and re-ran `EXPLAIN`/`EXPLAIN ANALYZE`.
- We connect each optimized query to real app pages.

---

## 4) Production-hardening notes to mention
- Move encryption key out of SQL literals and keep in environment-managed secrets.
- After validation period, remove plaintext sensitive columns (`contact`, `receipt_number`) and keep only encrypted/tokenized fields.
- Keep admin DB credentials restricted to role-management operations only.

---

## 5) 5–10 minute demo checklist
- [ ] Show schema coherence (live table names + role model)
- [ ] Run transaction COMMIT + ROLLBACK demo
- [ ] Show encrypted-at-rest data and controlled decryption
- [ ] Prove role allow/deny behavior with 2–3 accounts
- [ ] Show EXPLAIN before/after optimization indexes
- [ ] End with rubric-to-evidence mapping table
