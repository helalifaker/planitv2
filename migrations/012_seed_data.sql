-- =================================================================
-- Migration 012: Seed Data
-- PLAN-IT Database Schema v2.6
-- Initial reference data for the system
-- =================================================================

-- =================================================================
-- EDUCATION CYCLES
-- =================================================================
INSERT INTO education_cycles (code, name, name_short, path, age_start, age_end, display_order, color_hex) VALUES
('CYCLE_1', 'Cycle 1 - Apprentissages premiers', 'Maternelle', 'root.maternelle', 3, 6, 1, '#4CAF50'),
('CYCLE_2', 'Cycle 2 - Apprentissages fondamentaux', 'Élémentaire CP-CE2', 'root.elementaire.cycle2', 6, 9, 2, '#2196F3'),
('CYCLE_3', 'Cycle 3 - Consolidation', 'CM + 6ème', 'root.elementaire.cycle3', 9, 12, 3, '#FF9800'),
('CYCLE_4', 'Cycle 4 - Approfondissements', 'Collège 5ème-3ème', 'root.college', 12, 15, 4, '#9C27B0'),
('LYCEE', 'Cycle Terminal', 'Lycée', 'root.lycee', 15, 18, 5, '#F44336');

-- =================================================================
-- GRADE LEVELS
-- =================================================================
INSERT INTO grade_levels (
    code, name, name_short, name_en, path, cycle_id, level_type,
    legal_hours_per_week, service_divisor, default_max_students,
    he_ratio_target, he_ratio_alert_threshold, typical_age, display_order,
    uses_dhg_model, is_exam_year
) VALUES
-- MATERNELLE (Cycle 1) - 1:1 Teacher model
('TPS', 'Toute Petite Section', 'TPS', 'Pre-K (Age 2)', 'root.maternelle.tps',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_1'), 'MATERNELLE',
    24.00, 24.00, 25, NULL, NULL, 2, 1, FALSE, FALSE),
('PS', 'Petite Section', 'PS', 'Pre-K (Age 3)', 'root.maternelle.ps',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_1'), 'MATERNELLE',
    24.00, 24.00, 28, NULL, NULL, 3, 2, FALSE, FALSE),
('MS', 'Moyenne Section', 'MS', 'Pre-K (Age 4)', 'root.maternelle.ms',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_1'), 'MATERNELLE',
    24.00, 24.00, 28, NULL, NULL, 4, 3, FALSE, FALSE),
('GS', 'Grande Section', 'GS', 'Kindergarten', 'root.maternelle.gs',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_1'), 'MATERNELLE',
    24.00, 24.00, 28, NULL, NULL, 5, 4, FALSE, FALSE),

-- ÉLÉMENTAIRE (Cycles 2-3) - 1:1 Teacher model
('CP', 'Cours Préparatoire', 'CP', 'Grade 1', 'root.elementaire.cp',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_2'), 'ELEMENTAIRE',
    24.00, 24.00, 28, NULL, NULL, 6, 5, FALSE, FALSE),
('CE1', 'Cours Élémentaire 1', 'CE1', 'Grade 2', 'root.elementaire.ce1',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_2'), 'ELEMENTAIRE',
    24.00, 24.00, 28, NULL, NULL, 7, 6, FALSE, FALSE),
('CE2', 'Cours Élémentaire 2', 'CE2', 'Grade 3', 'root.elementaire.ce2',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_2'), 'ELEMENTAIRE',
    24.00, 24.00, 28, NULL, NULL, 8, 7, FALSE, FALSE),
('CM1', 'Cours Moyen 1', 'CM1', 'Grade 4', 'root.elementaire.cm1',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_3'), 'ELEMENTAIRE',
    24.00, 24.00, 28, NULL, NULL, 9, 8, FALSE, FALSE),
('CM2', 'Cours Moyen 2', 'CM2', 'Grade 5', 'root.elementaire.cm2',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_3'), 'ELEMENTAIRE',
    24.00, 24.00, 28, NULL, NULL, 10, 9, FALSE, FALSE),

-- COLLÈGE (Cycles 3-4) - DHG model
('6EME', 'Sixième', '6ème', 'Grade 6', 'root.college.sixieme',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_3'), 'COLLEGE',
    26.00, 18.00, 28, 1.30, 1.45, 11, 10, TRUE, FALSE),
('5EME', 'Cinquième', '5ème', 'Grade 7', 'root.college.cinquieme',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_4'), 'COLLEGE',
    26.00, 18.00, 28, 1.32, 1.45, 12, 11, TRUE, FALSE),
('4EME', 'Quatrième', '4ème', 'Grade 8', 'root.college.quatrieme',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_4'), 'COLLEGE',
    28.50, 18.00, 28, 1.35, 1.50, 13, 12, TRUE, FALSE),
('3EME', 'Troisième', '3ème', 'Grade 9', 'root.college.troisieme',
    (SELECT id FROM education_cycles WHERE code = 'CYCLE_4'), 'COLLEGE',
    28.50, 18.00, 28, 1.38, 1.50, 14, 13, TRUE, TRUE),  -- Brevet exam

-- LYCÉE - DHG model
('2NDE', 'Seconde', '2nde', 'Grade 10', 'root.lycee.seconde',
    (SELECT id FROM education_cycles WHERE code = 'LYCEE'), 'LYCEE',
    28.50, 18.00, 35, 1.40, 1.55, 15, 14, TRUE, FALSE),
('1ERE', 'Première', '1ère', 'Grade 11', 'root.lycee.premiere',
    (SELECT id FROM education_cycles WHERE code = 'LYCEE'), 'LYCEE',
    28.00, 18.00, 35, 1.42, 1.55, 16, 15, TRUE, FALSE),
('TERM', 'Terminale', 'Tle', 'Grade 12', 'root.lycee.terminale',
    (SELECT id FROM education_cycles WHERE code = 'LYCEE'), 'LYCEE',
    27.00, 18.00, 35, 1.45, 1.60, 17, 16, TRUE, TRUE);  -- Bac exam

-- =================================================================
-- CONTRACT TYPES
-- =================================================================
INSERT INTO contract_types (
    code, name, name_fr, payment_currency, employer,
    requires_iqama, requires_medical_insurance, requires_annual_ticket, eligible_for_ajeer,
    gosi_employer_rate, gosi_employee_rate, avg_annual_cost_sar, avg_annual_cost_eur,
    display_order, color_hex
) VALUES
('DETACHE_AEFE', 'Seconded from France', 'Détaché AEFE', 'EUR', 'AEFE_PARIS',
    FALSE, FALSE, FALSE, FALSE, NULL, NULL, 0, 0, 1, '#1976D2'),
('RESIDENT_AEFE', 'AEFE Resident', 'Résident AEFE', 'EUR', 'BOTH',
    TRUE, TRUE, TRUE, FALSE, 0.02, 0.00, 450000, 95000, 2, '#7B1FA2'),
('LOCAL_SPONSORED', 'Local - Company Sponsored', 'Local Sponsorisé', 'SAR', 'SCHOOL',
    TRUE, TRUE, TRUE, FALSE, 0.02, 0.00, 280000, NULL, 3, '#388E3C'),
('LOCAL_FAMILY_VISA', 'Local - Family Visa', 'Local Visa Famille', 'SAR', 'SCHOOL',
    FALSE, TRUE, FALSE, TRUE, 0.02, 0.00, 180000, NULL, 4, '#FBC02D');

-- =================================================================
-- USER ROLES
-- =================================================================
INSERT INTO user_roles (code, name, description, permissions, level, is_system_role, color_hex) VALUES
('SUPER_ADMIN', 'Super Administrator', 'Full system access across all schools', '{
    "modules": {"enrollment": {"read": true, "write": true, "delete": true}, "workforce": {"read": true, "write": true, "delete": true}, "dhg": {"read": true, "write": true, "delete": true}, "financials": {"read": true, "write": true, "delete": true}},
    "scenarios": {"create": true, "approve": true, "lock": true},
    "admin": {"manage_users": true, "manage_schools": true, "view_audit_logs": true}
}'::JSONB, 0, TRUE, '#D32F2F'),

('FINANCE_MANAGER', 'Finance Manager', 'Manage budgets and financial planning', '{
    "modules": {"enrollment": {"read": true, "write": true, "delete": false}, "workforce": {"read": true, "write": true, "delete": false}, "dhg": {"read": true, "write": true, "delete": false}, "financials": {"read": true, "write": true, "delete": false}},
    "scenarios": {"create": true, "approve": false, "lock": false},
    "admin": {"manage_users": false, "manage_schools": false, "view_audit_logs": true}
}'::JSONB, 1, TRUE, '#1976D2'),

('BOARD_MEMBER', 'Board Member', 'Read-only access to dashboards and reports', '{
    "modules": {"enrollment": {"read": true, "write": false, "delete": false}, "workforce": {"read": true, "write": false, "delete": false}, "dhg": {"read": true, "write": false, "delete": false}, "financials": {"read": true, "write": false, "delete": false}},
    "scenarios": {"create": false, "approve": true, "lock": false},
    "admin": {"manage_users": false, "manage_schools": false, "view_audit_logs": false}
}'::JSONB, 2, TRUE, '#7B1FA2'),

('PRINCIPAL', 'School Principal', 'Manage enrollment and view DHG', '{
    "modules": {"enrollment": {"read": true, "write": true, "delete": false}, "workforce": {"read": true, "write": false, "delete": false}, "dhg": {"read": true, "write": false, "delete": false}, "financials": {"read": false, "write": false, "delete": false}},
    "scenarios": {"create": false, "approve": false, "lock": false},
    "admin": {"manage_users": false, "manage_schools": false, "view_audit_logs": false}
}'::JSONB, 3, TRUE, '#388E3C'),

('HR_MANAGER', 'HR Manager', 'Manage workforce and staff planning', '{
    "modules": {"enrollment": {"read": true, "write": false, "delete": false}, "workforce": {"read": true, "write": true, "delete": false}, "dhg": {"read": true, "write": true, "delete": false}, "financials": {"read": false, "write": false, "delete": false}},
    "scenarios": {"create": false, "approve": false, "lock": false},
    "admin": {"manage_users": false, "manage_schools": false, "view_audit_logs": false}
}'::JSONB, 2, TRUE, '#F57C00');

-- =================================================================
-- AEFE BENCHMARKS
-- =================================================================
INSERT INTO aefe_benchmarks (
    benchmark_type, level_type, min_students, max_students,
    target_value, good_threshold, alert_threshold, critical_threshold,
    aefe_zone, effective_year, source_document, notes
) VALUES
-- H/E Ratios by Level
('HE_RATIO', 'COLLEGE', NULL, NULL, 1.30, 1.35, 1.45, 1.55, 'GLOBAL', 2025,
    'Tables Enseignants AEFE 2024-2025', 'Target for Collège (6ème-3ème)'),
('HE_RATIO', 'LYCEE', NULL, NULL, 1.40, 1.45, 1.55, 1.65, 'GLOBAL', 2025,
    'Tables Enseignants AEFE 2024-2025', 'Target for Lycée (2nde-Terminale)'),

-- Staff Cost Ratios
('STAFF_COST_RATIO', 'ALL', NULL, NULL, 0.6500, 0.7000, 0.7500, 0.8000, 'GLOBAL', 2025,
    'AEFE Financial Guidelines', 'Staff costs should be < 70% of revenue'),

-- Division Size Benchmarks
('DIVISION_SIZE', 'MATERNELLE', NULL, NULL, 25.00, 26.00, 28.00, 30.00, 'GLOBAL', 2025,
    'AEFE Capacity Standards', 'Max students per division - Maternelle'),
('DIVISION_SIZE', 'ELEMENTAIRE', NULL, NULL, 26.00, 27.00, 28.00, 30.00, 'GLOBAL', 2025,
    'AEFE Capacity Standards', 'Max students per division - Élémentaire'),
('DIVISION_SIZE', 'COLLEGE', NULL, NULL, 28.00, 29.00, 30.00, 32.00, 'GLOBAL', 2025,
    'AEFE Capacity Standards', 'Max students per division - Collège'),
('DIVISION_SIZE', 'LYCEE', NULL, NULL, 32.00, 33.00, 35.00, 38.00, 'GLOBAL', 2025,
    'AEFE Capacity Standards', 'Max students per division - Lycée');

-- =================================================================
-- DEFAULT EXCHANGE RATES
-- =================================================================
INSERT INTO exchange_rates (
    from_currency, to_currency, rate_type, rate,
    effective_date, applicable_year, source, source_reference, is_default
) VALUES
('SAR', 'EUR', 'BUDGET', 0.2400, '2025-01-01', 2025, 'MANUAL', 'Initial budget rate', TRUE),
('EUR', 'SAR', 'BUDGET', 4.1667, '2025-01-01', 2025, 'MANUAL', 'Initial budget rate', TRUE),
('SAR', 'EUR', 'AEFE_OFFICIAL', 0.2380, '2025-01-01', 2025, 'AEFE_OFFICIAL', 'AEFE 2025 official rate', FALSE),
('EUR', 'SAR', 'AEFE_OFFICIAL', 4.2017, '2025-01-01', 2025, 'AEFE_OFFICIAL', 'AEFE 2025 official rate', FALSE);

-- =================================================================
-- DEFAULT SYSTEM SETTINGS
-- =================================================================
INSERT INTO system_settings (scope, setting_key, setting_value, setting_type, description) VALUES
('GLOBAL', 'default_currency', '"SAR"', 'STRING', 'Default currency for new entries'),
('GLOBAL', 'reporting_currency', '"EUR"', 'STRING', 'Currency for AEFE Paris reporting'),
('GLOBAL', 'fiscal_year_start_month', '1', 'NUMBER', 'Month when fiscal year starts (1=January)'),
('GLOBAL', 'academic_year_start_month', '9', 'NUMBER', 'Month when academic year starts (9=September)'),
('GLOBAL', 'vat_rate_non_saudi', '0.15', 'NUMBER', 'VAT rate for non-Saudi students'),
('GLOBAL', 'cash_threshold_warning', '500000', 'NUMBER', 'Cash balance warning threshold (SAR)'),
('GLOBAL', 'cash_threshold_critical', '200000', 'NUMBER', 'Cash balance critical threshold (SAR)'),
('GLOBAL', 'he_ratio_calculation_method', '"AEFE_STANDARD"', 'STRING', 'H/E ratio calculation methodology');
