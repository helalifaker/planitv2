# PLAN-IT Database Schema v2.6
## KSA & AEFE Logic Patch (v5.2) - Complete Schema with User Roles & Financials

---

## Table of Contents

1. [Extensions](#1-extensions)
2. [Core Foundation Tables](#2-core-foundation-tables)
3. [User Management](#3-user-management)
4. [Scenario Management](#4-scenario-management)
5. [Grade Levels with ltree Hierarchy](#5-grade-levels-with-ltree-hierarchy)
6. [AEFE Benchmarks](#6-aefe-benchmarks)
7. [Enrollment Module](#7-enrollment-module)
8. [Workforce Module](#8-workforce-module)
9. [DHG Engine](#9-dhg-engine)
10. [Financial Module](#10-financial-module)
11. [Audit & Metadata](#11-audit--metadata)
12. [Indexes & Performance](#12-indexes--performance)
13. [Row Level Security](#13-row-level-security)
14. [Seed Data](#14-seed-data)
15. [Migration Order](#15-migration-order)

---

## 1. Extensions

```sql
-- =================================================================
-- EXTENSIONS
-- =================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "ltree";          -- Hierarchical data
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Text search optimization
```

---

## 2. Core Foundation Tables

### 2.1 Schools (Multi-tenant Root)

```sql
-- =================================================================
-- SCHOOLS: The multi-tenant root entity
-- =================================================================
CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(20) UNIQUE NOT NULL,           -- e.g., "EFIR" for EFIR Riyadh
    name VARCHAR(200) NOT NULL,                 -- "École Française Internationale de Riyad"
    name_ar VARCHAR(200),                       -- Arabic name

    -- AEFE Classification
    aefe_status VARCHAR(30) NOT NULL
        CHECK (aefe_status IN ('CONVENTIONNÉ', 'PARTENAIRE', 'HOMOLOGUÉ')),
    aefe_code VARCHAR(20),                      -- AEFE official code

    -- Location
    country_code CHAR(2) DEFAULT 'SA',          -- ISO 3166-1 alpha-2
    city VARCHAR(100),

    -- Hierarchy path for ltree queries
    path LTREE GENERATED ALWAYS AS (text2ltree(code)) STORED,

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_schools_path ON schools USING GIST (path);
CREATE INDEX idx_schools_code ON schools (code);
```

### 2.2 Academic Years

```sql
-- =================================================================
-- ACADEMIC YEARS: Fiscal/Academic period management
-- =================================================================
CREATE TABLE academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(9) UNIQUE NOT NULL,            -- e.g., "2025-2026"
    label VARCHAR(50) NOT NULL,                 -- "Année Scolaire 2025-2026"

    -- Date Ranges
    academic_start DATE NOT NULL,               -- Sept 1
    academic_end DATE NOT NULL,                 -- June 30
    fiscal_start DATE NOT NULL,                 -- Jan 1 (for KSA reporting)
    fiscal_end DATE NOT NULL,                   -- Dec 31

    -- Status
    is_current BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,            -- Prevent edits after close

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_academic_range CHECK (academic_end > academic_start),
    CONSTRAINT valid_fiscal_range CHECK (fiscal_end > fiscal_start)
);

-- Only one current year allowed
CREATE UNIQUE INDEX idx_academic_years_current
    ON academic_years (is_current) WHERE is_current = TRUE;
```

---

## 3. User Management

### 3.1 User Roles (Permission Templates)

```sql
-- =================================================================
-- USER ROLES: Permission templates for access control
-- =================================================================
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(50) UNIQUE NOT NULL,           -- e.g., "SUPER_ADMIN", "FINANCE_MANAGER"
    name VARCHAR(100) NOT NULL,                 -- "Super Administrator"
    description TEXT,

    -- Permissions (JSONB for flexibility)
    permissions JSONB NOT NULL DEFAULT '{}',
    /*
    Example permissions structure:
    {
        "modules": {
            "enrollment": {"read": true, "write": true, "delete": false},
            "workforce": {"read": true, "write": true, "delete": false},
            "dhg": {"read": true, "write": false, "delete": false},
            "financials": {"read": true, "write": false, "delete": false}
        },
        "scenarios": {
            "create": true,
            "approve": false,
            "lock": false
        },
        "admin": {
            "manage_users": false,
            "manage_schools": false,
            "view_audit_logs": true
        }
    }
    */

    -- Hierarchy
    level INT NOT NULL DEFAULT 0,               -- 0 = highest (admin), higher = less privilege
    is_system_role BOOLEAN DEFAULT FALSE,       -- Cannot be deleted

    -- Display
    color_hex CHAR(7),

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_roles_code ON user_roles (code);
CREATE INDEX idx_user_roles_level ON user_roles (level);
```

### 3.2 Users

```sql
-- =================================================================
-- USERS: System users with school assignment
-- =================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity (from Auth Provider - e.g., Supabase Auth)
    auth_provider_id VARCHAR(255) UNIQUE,       -- External auth ID
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,

    -- Profile
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name || ' ' || last_name, email)
    ) STORED,
    avatar_url TEXT,
    phone VARCHAR(20),

    -- Locale
    preferred_language VARCHAR(5) DEFAULT 'fr', -- 'fr', 'en', 'ar'
    timezone VARCHAR(50) DEFAULT 'Asia/Riyadh',

    -- Role Assignment
    role_id UUID NOT NULL REFERENCES user_roles(id),

    -- School Assignment (NULL = super admin with all-school access)
    school_id UUID REFERENCES schools(id),

    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE'
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED')),
    last_login_at TIMESTAMPTZ,
    login_count INT DEFAULT 0,

    -- Security
    password_changed_at TIMESTAMPTZ,
    must_change_password BOOLEAN DEFAULT FALSE,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    deactivated_at TIMESTAMPTZ,
    deactivated_by UUID REFERENCES users(id)
);

-- Indexes
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_school ON users (school_id);
CREATE INDEX idx_users_role ON users (role_id);
CREATE INDEX idx_users_status ON users (status) WHERE status = 'ACTIVE';
```

### 3.3 User School Access (Multi-School Users)

```sql
-- =================================================================
-- USER SCHOOL ACCESS: For users with access to multiple schools
-- =================================================================
CREATE TABLE user_school_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,

    -- Override role for this specific school (optional)
    role_override_id UUID REFERENCES user_roles(id),

    -- Access level
    access_type VARCHAR(20) DEFAULT 'FULL'
        CHECK (access_type IN ('FULL', 'READ_ONLY', 'SPECIFIC_MODULES')),
    allowed_modules TEXT[],                     -- If access_type = 'SPECIFIC_MODULES'

    -- Validity
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES users(id),
    expires_at TIMESTAMPTZ,                     -- NULL = never expires

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_user_school UNIQUE (user_id, school_id)
);

CREATE INDEX idx_user_school_access_user ON user_school_access (user_id);
CREATE INDEX idx_user_school_access_school ON user_school_access (school_id);
```

---

## 4. Scenario Management

### 4.1 Budget Scenarios

```sql
-- =================================================================
-- BUDGET SCENARIOS: Version control for planning
-- =================================================================
CREATE TABLE budget_scenarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),

    -- Identity
    code VARCHAR(50) NOT NULL,                  -- "BASE_2025", "SCENARIO_A"
    name VARCHAR(200) NOT NULL,
    description TEXT,

    -- Hierarchy (for scenario branching)
    parent_scenario_id UUID REFERENCES budget_scenarios(id),
    path LTREE,                                 -- e.g., "base.scenario_a.variant_1"

    -- Status
    scenario_type VARCHAR(20) NOT NULL
        CHECK (scenario_type IN ('BASELINE', 'WORKING', 'APPROVED', 'ARCHIVED')),
    is_baseline BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,

    -- Approval
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES users(id),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),

    -- Constraints
    CONSTRAINT unique_scenario_code UNIQUE (school_id, academic_year_id, code)
);

-- Only one baseline per school/year
CREATE UNIQUE INDEX idx_scenario_baseline
    ON budget_scenarios (school_id, academic_year_id)
    WHERE is_baseline = TRUE;

CREATE INDEX idx_scenario_path ON budget_scenarios USING GIST (path);
CREATE INDEX idx_scenario_lookup ON budget_scenarios (school_id, academic_year_id);
```

---

## 5. Grade Levels with ltree Hierarchy

### 5.1 Cycles (Education Phases)

```sql
-- =================================================================
-- CYCLES: French Education System Phases
-- =================================================================
CREATE TABLE education_cycles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(20) UNIQUE NOT NULL,           -- e.g., "CYCLE_1", "CYCLE_2"
    name VARCHAR(100) NOT NULL,                 -- "Cycle 1 - Apprentissages premiers"
    name_short VARCHAR(50) NOT NULL,            -- "Maternelle"

    -- Hierarchy
    path LTREE NOT NULL,                        -- e.g., "cycle.maternelle"

    -- Age Range
    age_start INT NOT NULL,
    age_end INT NOT NULL,

    -- Display
    display_order INT NOT NULL,
    color_hex CHAR(7),                          -- For UI theming

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_age_range CHECK (age_end >= age_start)
);

CREATE INDEX idx_cycles_path ON education_cycles USING GIST (path);
```

### 5.2 Grade Levels (The Core Table)

```sql
-- =================================================================
-- GRADE LEVELS: Complete French Education System with ltree
-- =================================================================
CREATE TABLE grade_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(20) UNIQUE NOT NULL,           -- e.g., "6EME", "CP", "TPS"
    name VARCHAR(100) NOT NULL,                 -- "Sixième"
    name_short VARCHAR(20) NOT NULL,            -- "6ème"
    name_en VARCHAR(100),                       -- "Grade 6"

    -- Hierarchy (ltree)
    path LTREE NOT NULL,                        -- e.g., "root.college.sixieme"
    cycle_id UUID NOT NULL REFERENCES education_cycles(id),

    -- Classification
    level_type VARCHAR(20) NOT NULL
        CHECK (level_type IN ('MATERNELLE', 'ELEMENTAIRE', 'COLLEGE', 'LYCEE')),

    -- DHG Parameters (AEFE Official)
    legal_hours_per_week DECIMAL(5,2) NOT NULL, -- Official hours per division
    service_divisor DECIMAL(4,2) NOT NULL,      -- 18 for Certifiés, 15 for Agrégés, 24 for PE
    default_max_students INT DEFAULT 28,        -- AEFE standard class size

    -- H/E Benchmark (from Tables Enseignants.csv)
    he_ratio_target DECIMAL(4,2),               -- Target H/E ratio
    he_ratio_alert_threshold DECIMAL(4,2),      -- Alert if exceeded

    -- Age & Sequencing
    typical_age INT NOT NULL,
    display_order INT NOT NULL,

    -- Flags
    uses_dhg_model BOOLEAN DEFAULT TRUE,        -- FALSE for Maternelle/Élémentaire (1:1 teacher)
    is_exam_year BOOLEAN DEFAULT FALSE,         -- 3ème (Brevet), Terminale (Bac)

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for ltree operations
CREATE INDEX idx_grade_levels_path ON grade_levels USING GIST (path);
CREATE INDEX idx_grade_levels_path_btree ON grade_levels USING BTREE (path);
CREATE INDEX idx_grade_levels_cycle ON grade_levels (cycle_id);
CREATE INDEX idx_grade_levels_type ON grade_levels (level_type);
CREATE INDEX idx_grade_levels_order ON grade_levels (display_order);
```

### 5.3 Grade Level Options (Languages, Specializations)

```sql
-- =================================================================
-- GRADE OPTIONS: Languages, Specializations, Sections
-- =================================================================
CREATE TABLE grade_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(30) UNIQUE NOT NULL,           -- e.g., "LV2_ESP", "SECTION_INT_EN"
    name VARCHAR(100) NOT NULL,                 -- "LV2 Espagnol"

    -- Classification
    option_type VARCHAR(30) NOT NULL
        CHECK (option_type IN (
            'LV1', 'LV2', 'LV3',                 -- Languages
            'SECTION_INTERNATIONALE',            -- International sections
            'OPTION_FACULTATIVE',                -- Optional subjects
            'SPECIALITE_LYCEE',                  -- Lycée specializations
            'ENSEIGNEMENT_COMPLEMENTAIRE'        -- Additional teaching
        )),

    -- Hours
    hours_per_week DECIMAL(4,2) NOT NULL,

    -- Applicable grades (ltree query)
    applicable_from_path LTREE,                 -- e.g., "root.college" = all collège
    applicable_grade_ids UUID[],                -- Or specific grades

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_grade_options_path ON grade_options USING GIST (applicable_from_path);
```

---

## 6. AEFE Benchmarks

### 6.1 AEFE Benchmark Curves

```sql
-- =================================================================
-- AEFE BENCHMARKS: Official H/E ratios and efficiency targets
-- Source: Tables Enseignants.csv from AEFE Paris
-- =================================================================
CREATE TABLE aefe_benchmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Benchmark Type
    benchmark_type VARCHAR(30) NOT NULL
        CHECK (benchmark_type IN (
            'HE_RATIO',              -- Hours per Student ratio
            'STAFF_COST_RATIO',      -- Staff costs as % of revenue
            'DIVISION_SIZE',         -- Students per division
            'FTE_PER_DIVISION',      -- Teachers per class
            'ADMIN_RATIO'            -- Admin staff ratio
        )),

    -- Scope
    level_type VARCHAR(20) NOT NULL
        CHECK (level_type IN ('MATERNELLE', 'ELEMENTAIRE', 'COLLEGE', 'LYCEE', 'ALL')),

    -- Student range (for size-based benchmarks)
    min_students INT,
    max_students INT,

    -- Values
    target_value DECIMAL(8,4) NOT NULL,         -- Target to aim for
    good_threshold DECIMAL(8,4),                -- "Good" performance threshold
    alert_threshold DECIMAL(8,4),               -- Trigger warning if exceeded
    critical_threshold DECIMAL(8,4),            -- Trigger critical alert

    -- Context
    aefe_zone VARCHAR(30)
        CHECK (aefe_zone IN ('ZONE_A', 'ZONE_B', 'ZONE_C', 'GLOBAL')),
    effective_year INT NOT NULL,                -- Academic year this applies to

    -- Source tracking
    source_document VARCHAR(200),               -- "Tables Enseignants 2024-2025"
    source_page VARCHAR(50),
    notes TEXT,

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_student_range CHECK (
        min_students IS NULL OR max_students IS NULL OR max_students >= min_students
    ),
    CONSTRAINT valid_thresholds CHECK (
        alert_threshold IS NULL OR alert_threshold >= target_value
    )
);

CREATE INDEX idx_aefe_benchmarks_type ON aefe_benchmarks (benchmark_type, level_type);
CREATE INDEX idx_aefe_benchmarks_year ON aefe_benchmarks (effective_year);
CREATE INDEX idx_aefe_benchmarks_zone ON aefe_benchmarks (aefe_zone);
```

### 6.2 Benchmark Comparisons (Calculated Results)

```sql
-- =================================================================
-- BENCHMARK COMPARISONS: Track school performance vs benchmarks
-- =================================================================
CREATE TABLE benchmark_comparisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),
    benchmark_id UUID NOT NULL REFERENCES aefe_benchmarks(id),

    -- Scope (optional - can be school-wide or per level)
    level_type VARCHAR(20),
    grade_level_id UUID REFERENCES grade_levels(id),

    -- Calculated Values
    actual_value DECIMAL(10,4) NOT NULL,
    target_value DECIMAL(10,4) NOT NULL,
    variance DECIMAL(10,4) GENERATED ALWAYS AS (
        actual_value - target_value
    ) STORED,
    variance_pct DECIMAL(8,4) GENERATED ALWAYS AS (
        CASE WHEN target_value != 0
             THEN ((actual_value - target_value) / target_value) * 100
             ELSE 0
        END
    ) STORED,

    -- Status
    status VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN actual_value <= target_value THEN 'ON_TARGET'
            WHEN actual_value <= target_value * 1.1 THEN 'NEAR_TARGET'
            WHEN actual_value <= target_value * 1.2 THEN 'WARNING'
            ELSE 'CRITICAL'
        END
    ) STORED,

    -- Calculation metadata
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    calculation_details JSONB,                  -- Store breakdown of how value was derived

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_benchmark_comparison UNIQUE (
        school_id, academic_year_id, scenario_id, benchmark_id, level_type, grade_level_id
    )
);

CREATE INDEX idx_benchmark_comp_lookup ON benchmark_comparisons (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_benchmark_comp_status ON benchmark_comparisons (status);
```

---

## 7. Enrollment Module

### 7.1 Enrollment Inputs

```sql
-- =================================================================
-- ENROLLMENT INPUTS: Student projections with VAT logic
-- =================================================================
CREATE TABLE enrollment_inputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant & Period
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id),

    -- Enrollment Waterfall
    opening_count INT NOT NULL DEFAULT 0,       -- Students at year start
    new_recruits INT NOT NULL DEFAULT 0,        -- Expected new enrollments
    departures INT NOT NULL DEFAULT 0,          -- Expected departures
    closing_count INT GENERATED ALWAYS AS (
        opening_count + new_recruits - departures
    ) STORED,

    -- VAT Classification (KSA Specific)
    nationality_group VARCHAR(20) NOT NULL
        CHECK (nationality_group IN ('SAUDI', 'NON_SAUDI', 'DIPLOMAT')),
    vat_rate DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE
            WHEN nationality_group = 'SAUDI' THEN 0.0000
            WHEN nationality_group = 'DIPLOMAT' THEN 0.0000
            ELSE 0.1500  -- 15% VAT for non-Saudi
        END
    ) STORED,

    -- AEFE Scholarship
    scholarship_status VARCHAR(50) DEFAULT 'NONE'
        CHECK (scholarship_status IN ('NONE', 'AEFE_100', 'AEFE_PARTIAL', 'INTERNAL_AID')),
    scholarship_percentage DECIMAL(5,2) DEFAULT 0,

    -- Tuition
    base_tuition_sar DECIMAL(12,2),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,

    -- Constraints
    CONSTRAINT valid_enrollment_counts CHECK (
        opening_count >= 0 AND
        new_recruits >= 0 AND
        departures >= 0 AND
        departures <= opening_count + new_recruits
    ),
    CONSTRAINT unique_enrollment_entry UNIQUE (
        school_id, academic_year_id, scenario_id, grade_level_id, nationality_group
    )
);

CREATE INDEX idx_enrollment_lookup ON enrollment_inputs (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_enrollment_grade ON enrollment_inputs (grade_level_id);
```

---

## 8. Workforce Module

### 8.1 Contract Types (Reference)

```sql
-- =================================================================
-- CONTRACT TYPES: Cost structure definitions
-- =================================================================
CREATE TABLE contract_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_fr VARCHAR(100) NOT NULL,

    -- Payment Structure
    payment_currency CHAR(3) NOT NULL
        CHECK (payment_currency IN ('SAR', 'EUR')),
    employer VARCHAR(20) NOT NULL
        CHECK (employer IN ('SCHOOL', 'AEFE_PARIS', 'BOTH')),

    -- KSA Cost Flags
    requires_iqama BOOLEAN DEFAULT FALSE,
    requires_medical_insurance BOOLEAN DEFAULT FALSE,
    requires_annual_ticket BOOLEAN DEFAULT FALSE,
    eligible_for_ajeer BOOLEAN DEFAULT FALSE,

    -- GOSI Rates
    gosi_employer_rate DECIMAL(5,4),            -- 0.12 for Saudi, 0.02 for non-Saudi
    gosi_employee_rate DECIMAL(5,4),            -- 0.10 for Saudi, 0.00 for non-Saudi

    -- Cost Estimate (for planning)
    avg_annual_cost_sar DECIMAL(12,2),
    avg_annual_cost_eur DECIMAL(12,2),

    -- Display
    display_order INT,
    color_hex CHAR(7),

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 8.2 Workforce Inputs

```sql
-- =================================================================
-- WORKFORCE INPUTS: Staff planning with labor arbitrage
-- =================================================================
CREATE TABLE workforce_inputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant & Period
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),

    -- Staff Identity
    position_code VARCHAR(50) NOT NULL,         -- e.g., "MATH_CERTIFIE_01"
    position_title VARCHAR(200),
    subject_area VARCHAR(50),                   -- "MATH", "FRENCH", "ADMIN"

    -- Grade Level Assignment (optional, for primary)
    grade_level_id UUID REFERENCES grade_levels(id),

    -- Contract Type
    contract_type_id UUID NOT NULL REFERENCES contract_types(id),

    -- KSA-Specific Flags
    has_ajeer_permit BOOLEAN DEFAULT FALSE,
    reimburse_dependent_levy BOOLEAN DEFAULT FALSE,
    is_saudi_national BOOLEAN DEFAULT FALSE,

    -- Housing
    housing_type VARCHAR(30)
        CHECK (housing_type IN ('CASH_ALLOWANCE', 'COMPOUND_ALLOCATION', 'NONE')),
    housing_value_sar DECIMAL(10,2) DEFAULT 0,

    -- FTE & Hours
    fte_value DECIMAL(4,2) DEFAULT 1.00,        -- 1.0 = full time, 0.5 = half
    weekly_hours DECIMAL(5,2),

    -- Compensation (Input)
    base_salary_monthly DECIMAL(12,2),
    currency CHAR(3) DEFAULT 'SAR',

    -- Calculated Costs (Generated)
    annual_base_salary DECIMAL(12,2) GENERATED ALWAYS AS (
        base_salary_monthly * 12
    ) STORED,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE INDEX idx_workforce_lookup ON workforce_inputs (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_workforce_contract ON workforce_inputs (contract_type_id);
CREATE INDEX idx_workforce_grade ON workforce_inputs (grade_level_id);
```

---

## 9. DHG Engine

### 9.1 DHG Inputs (Secondary School Hours)

```sql
-- =================================================================
-- DHG INPUTS: Dotation Horaire Globale for Collège/Lycée
-- =================================================================
CREATE TABLE dhg_inputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant & Period
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id),

    -- From Enrollment Module
    projected_students INT NOT NULL,
    max_students_per_division INT DEFAULT 28,

    -- Calculated: Divisions
    calculated_divisions INT GENERATED ALWAYS AS (
        CEIL(projected_students::DECIMAL / NULLIF(max_students_per_division, 0))
    ) STORED,

    -- Hours Configuration
    legal_hours_per_division DECIMAL(5,2) NOT NULL,
    group_hours_buffer DECIMAL(5,2) DEFAULT 0,
    option_hours DECIMAL(5,2) DEFAULT 0,
    weighting_coefficient DECIMAL(4,2) DEFAULT 1.0,

    -- Calculated: Total DHG
    total_dhg_hours DECIMAL(10,2) GENERATED ALWAYS AS (
        (CEIL(projected_students::DECIMAL / NULLIF(max_students_per_division, 0))
         * legal_hours_per_division
         + group_hours_buffer
         + option_hours)
        * weighting_coefficient
    ) STORED,

    -- H/E Ratio (Calculated)
    he_ratio DECIMAL(6,4) GENERATED ALWAYS AS (
        CASE
            WHEN projected_students > 0 THEN
                ((CEIL(projected_students::DECIMAL / NULLIF(max_students_per_division, 0))
                  * legal_hours_per_division
                  + group_hours_buffer
                  + option_hours)
                 * weighting_coefficient) / projected_students
            ELSE 0
        END
    ) STORED,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,

    -- Constraints
    CONSTRAINT valid_dhg_students CHECK (projected_students >= 0),
    CONSTRAINT valid_dhg_max CHECK (max_students_per_division > 0),
    CONSTRAINT unique_dhg_entry UNIQUE (
        school_id, academic_year_id, scenario_id, grade_level_id
    )
);

-- Optimized index for Polars engine queries
CREATE INDEX idx_dhg_lookup ON dhg_inputs (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_dhg_grade ON dhg_inputs (grade_level_id);
```

### 9.2 DHG Subject Breakdown (Detailed Hours by Subject)

```sql
-- =================================================================
-- DHG SUBJECT BREAKDOWN: Hours by subject/discipline
-- =================================================================
CREATE TABLE dhg_subject_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dhg_input_id UUID NOT NULL REFERENCES dhg_inputs(id) ON DELETE CASCADE,

    -- Subject
    subject_code VARCHAR(30) NOT NULL,          -- "MATH", "FRANCAIS", "HISTOIRE_GEO"
    subject_name VARCHAR(100) NOT NULL,

    -- Hours
    base_hours DECIMAL(5,2) NOT NULL,
    split_group_hours DECIMAL(5,2) DEFAULT 0,   -- Labs, language groups
    total_hours DECIMAL(5,2) GENERATED ALWAYS AS (
        base_hours + split_group_hours
    ) STORED,

    -- FTE Calculation
    service_divisor DECIMAL(4,2) NOT NULL,      -- 18 for Certifiés, 15 for Agrégés
    calculated_fte DECIMAL(6,3) GENERATED ALWAYS AS (
        (base_hours + split_group_hours) / NULLIF(service_divisor, 0)
    ) STORED,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dhg_subject_parent ON dhg_subject_hours (dhg_input_id);
```

---

## 10. Financial Module

### 10.1 Financial Periods

```sql
-- =================================================================
-- FINANCIAL PERIODS: Monthly/Quarterly breakdown for P&L and Cash
-- =================================================================
CREATE TABLE financial_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),

    -- Period Definition
    period_type VARCHAR(20) NOT NULL
        CHECK (period_type IN ('MONTH', 'QUARTER', 'SEMESTER', 'ANNUAL')),
    period_code VARCHAR(20) NOT NULL,           -- "2025-01", "2025-Q1", "2025-S1"
    period_name VARCHAR(100),                   -- "January 2025", "Q1 2025"

    -- Dates
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- Status
    is_closed BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES users(id),

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_period_dates CHECK (end_date >= start_date),
    CONSTRAINT unique_period UNIQUE (school_id, academic_year_id, scenario_id, period_code)
);

CREATE INDEX idx_financial_periods_lookup ON financial_periods (
    school_id, academic_year_id, scenario_id
);
```

### 10.2 Cash Flow Tranches

```sql
-- =================================================================
-- CASH FLOW TRANCHES: Tuition collection schedule (Aug/Jan/Apr)
-- KSA schools typically collect in 3 tranches
-- =================================================================
CREATE TABLE cash_flow_tranches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),

    -- Tranche Definition
    tranche_number INT NOT NULL,                -- 1, 2, 3
    tranche_name VARCHAR(100) NOT NULL,         -- "First Semester", "Second Semester", "Third Tranche"
    collection_month INT NOT NULL              -- 8 = August, 1 = January, 4 = April
        CHECK (collection_month BETWEEN 1 AND 12),

    -- Percentage Split
    percentage_of_annual DECIMAL(5,2) NOT NULL  -- e.g., 40.00, 30.00, 30.00
        CHECK (percentage_of_annual > 0 AND percentage_of_annual <= 100),

    -- Expected Collection Dates
    expected_collection_date DATE,
    grace_period_days INT DEFAULT 30,

    -- Actual vs Expected (for tracking)
    expected_amount_sar DECIMAL(14,2),
    collected_amount_sar DECIMAL(14,2) DEFAULT 0,
    collection_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN expected_amount_sar > 0
             THEN (collected_amount_sar / expected_amount_sar) * 100
             ELSE 0
        END
    ) STORED,

    -- Status
    status VARCHAR(20) DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'OVERDUE')),

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_tranche UNIQUE (school_id, academic_year_id, scenario_id, tranche_number)
);

CREATE INDEX idx_cash_tranches_lookup ON cash_flow_tranches (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_cash_tranches_month ON cash_flow_tranches (collection_month);
```

### 10.3 P&L Line Items (Chart of Accounts)

```sql
-- =================================================================
-- P&L LINE ITEMS: Chart of accounts structure
-- =================================================================
CREATE TABLE pl_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(20) UNIQUE NOT NULL,           -- "REV-001", "EXP-SAL-001"
    name VARCHAR(200) NOT NULL,
    name_fr VARCHAR(200),                       -- French name for AEFE reporting

    -- Hierarchy (ltree for grouping)
    path LTREE NOT NULL,                        -- "revenue.tuition.primary"
    parent_id UUID REFERENCES pl_line_items(id),

    -- Classification
    line_type VARCHAR(20) NOT NULL
        CHECK (line_type IN ('REVENUE', 'EXPENSE', 'SUBTOTAL', 'TOTAL')),
    category VARCHAR(50) NOT NULL,              -- "TUITION", "SALARIES", "OPERATIONS"
    subcategory VARCHAR(50),

    -- Calculation
    is_calculated BOOLEAN DEFAULT FALSE,        -- TRUE if sum of children
    calculation_formula TEXT,                   -- For complex calculations

    -- Display
    display_order INT NOT NULL,
    indent_level INT DEFAULT 0,
    is_bold BOOLEAN DEFAULT FALSE,
    is_header BOOLEAN DEFAULT FALSE,

    -- Mapping
    sage_account_code VARCHAR(20),              -- Map to Sage accounting
    aefe_report_line VARCHAR(50),               -- Map to AEFE Paris reporting

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pl_line_items_path ON pl_line_items USING GIST (path);
CREATE INDEX idx_pl_line_items_type ON pl_line_items (line_type, category);
CREATE INDEX idx_pl_line_items_order ON pl_line_items (display_order);
```

### 10.4 P&L Values (Actual/Budget Data)

```sql
-- =================================================================
-- P&L VALUES: Actual values for each line item per period
-- =================================================================
CREATE TABLE pl_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),
    financial_period_id UUID NOT NULL REFERENCES financial_periods(id),
    line_item_id UUID NOT NULL REFERENCES pl_line_items(id),

    -- Values (dual currency)
    amount_sar DECIMAL(14,2) NOT NULL DEFAULT 0,
    amount_eur DECIMAL(14,2),
    exchange_rate_used DECIMAL(12,6),

    -- Breakdown (optional)
    breakdown JSONB,                            -- For detailed component breakdown

    -- Source
    source_type VARCHAR(30) DEFAULT 'MANUAL'
        CHECK (source_type IN ('MANUAL', 'CALCULATED', 'IMPORTED', 'POLARS_ENGINE')),
    source_reference VARCHAR(200),              -- Reference to source (import file, calc run, etc.)

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),

    -- Constraints
    CONSTRAINT unique_pl_value UNIQUE (
        school_id, academic_year_id, scenario_id, financial_period_id, line_item_id
    )
);

CREATE INDEX idx_pl_values_lookup ON pl_values (
    school_id, academic_year_id, scenario_id, financial_period_id
);
CREATE INDEX idx_pl_values_line ON pl_values (line_item_id);
```

### 10.5 Cash Flow Projections

```sql
-- =================================================================
-- CASH FLOW PROJECTIONS: Monthly cash in/out tracking
-- =================================================================
CREATE TABLE cash_flow_projections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Context
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    scenario_id UUID NOT NULL REFERENCES budget_scenarios(id),
    financial_period_id UUID NOT NULL REFERENCES financial_periods(id),

    -- Opening Balance
    opening_balance_sar DECIMAL(14,2) NOT NULL DEFAULT 0,

    -- Inflows
    tuition_inflow_sar DECIMAL(14,2) DEFAULT 0,
    aefe_grants_sar DECIMAL(14,2) DEFAULT 0,
    other_income_sar DECIMAL(14,2) DEFAULT 0,
    total_inflow_sar DECIMAL(14,2) GENERATED ALWAYS AS (
        tuition_inflow_sar + aefe_grants_sar + other_income_sar
    ) STORED,

    -- Outflows
    salary_outflow_sar DECIMAL(14,2) DEFAULT 0,
    operations_outflow_sar DECIMAL(14,2) DEFAULT 0,
    capital_outflow_sar DECIMAL(14,2) DEFAULT 0,
    tax_outflow_sar DECIMAL(14,2) DEFAULT 0,    -- VAT liability payments
    total_outflow_sar DECIMAL(14,2) GENERATED ALWAYS AS (
        salary_outflow_sar + operations_outflow_sar + capital_outflow_sar + tax_outflow_sar
    ) STORED,

    -- Net & Closing
    net_cash_flow_sar DECIMAL(14,2) GENERATED ALWAYS AS (
        (tuition_inflow_sar + aefe_grants_sar + other_income_sar) -
        (salary_outflow_sar + operations_outflow_sar + capital_outflow_sar + tax_outflow_sar)
    ) STORED,
    closing_balance_sar DECIMAL(14,2) GENERATED ALWAYS AS (
        opening_balance_sar +
        (tuition_inflow_sar + aefe_grants_sar + other_income_sar) -
        (salary_outflow_sar + operations_outflow_sar + capital_outflow_sar + tax_outflow_sar)
    ) STORED,

    -- Alerts
    minimum_balance_threshold_sar DECIMAL(14,2) DEFAULT 500000,
    is_below_threshold BOOLEAN GENERATED ALWAYS AS (
        (opening_balance_sar +
         (tuition_inflow_sar + aefe_grants_sar + other_income_sar) -
         (salary_outflow_sar + operations_outflow_sar + capital_outflow_sar + tax_outflow_sar))
        < COALESCE(minimum_balance_threshold_sar, 0)
    ) STORED,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_cash_projection UNIQUE (
        school_id, academic_year_id, scenario_id, financial_period_id
    )
);

CREATE INDEX idx_cash_projections_lookup ON cash_flow_projections (
    school_id, academic_year_id, scenario_id
);
CREATE INDEX idx_cash_projections_alerts ON cash_flow_projections (is_below_threshold)
    WHERE is_below_threshold = TRUE;
```

---

## 11. Audit & Metadata

### 11.1 Audit Logs

```sql
-- =================================================================
-- AUDIT LOGS: Track all changes
-- =================================================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Target
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,

    -- Change Details
    action VARCHAR(20) NOT NULL
        CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],

    -- Context
    school_id UUID,
    scenario_id UUID,

    -- Actor
    user_id UUID,
    user_email VARCHAR(255),
    ip_address INET,
    user_agent TEXT,

    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_table ON audit_logs (table_name, record_id);
CREATE INDEX idx_audit_time ON audit_logs (created_at DESC);
CREATE INDEX idx_audit_user ON audit_logs (user_id);
CREATE INDEX idx_audit_school ON audit_logs (school_id);
```

### 11.2 Exchange Rates

```sql
-- =================================================================
-- EXCHANGE RATES: SAR/EUR conversion with rate types
-- Supports: Budget rates, Spot rates, AEFE official rates
-- =================================================================
CREATE TABLE exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Currency Pair
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,

    -- Rate Type (NEW)
    rate_type VARCHAR(30) NOT NULL DEFAULT 'SPOT'
        CHECK (rate_type IN (
            'SPOT',              -- Current market rate
            'BUDGET',            -- Rate used for budget planning
            'AEFE_OFFICIAL',     -- Official AEFE rate for Paris reporting
            'MONTH_END',         -- Month-end closing rate
            'AVERAGE'            -- Average rate for period
        )),

    -- Rate Value
    rate DECIMAL(12,6) NOT NULL,

    -- Validity Period
    effective_date DATE NOT NULL,
    expiry_date DATE,

    -- For which period (for BUDGET/AVERAGE rates)
    applicable_year INT,                        -- Academic year this rate applies to
    applicable_month INT                        -- Month (1-12) if monthly rate
        CHECK (applicable_month IS NULL OR applicable_month BETWEEN 1 AND 12),

    -- Source & Provenance
    source VARCHAR(50) NOT NULL
        CHECK (source IN ('MANUAL', 'AEFE_OFFICIAL', 'SAMA', 'ECB', 'BLOOMBERG', 'IMPORT')),
    source_reference VARCHAR(200),              -- e.g., "SAMA Rate Bulletin 2025-01-15"

    -- Default Handling (NEW)
    is_default BOOLEAN DEFAULT FALSE,           -- Use as default when no specific rate found
    fallback_rate_id UUID REFERENCES exchange_rates(id),  -- Fallback if this rate not available

    -- Variance Tracking (NEW)
    budget_rate_id UUID REFERENCES exchange_rates(id),    -- Link to budget rate for variance
    variance_from_budget DECIMAL(8,4) GENERATED ALWAYS AS (
        CASE
            WHEN budget_rate_id IS NOT NULL THEN NULL  -- Calculated at query time
            ELSE NULL
        END
    ) STORED,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),

    -- Constraints
    CONSTRAINT valid_rate CHECK (rate > 0),
    CONSTRAINT unique_rate_date_type UNIQUE (
        from_currency, to_currency, rate_type, effective_date
    )
);

-- Performance Indexes
CREATE INDEX idx_exchange_lookup ON exchange_rates (
    from_currency, to_currency, rate_type, effective_date DESC
);
CREATE INDEX idx_exchange_default ON exchange_rates (is_default)
    WHERE is_default = TRUE;
CREATE INDEX idx_exchange_year ON exchange_rates (applicable_year);

-- Function to get applicable rate
COMMENT ON TABLE exchange_rates IS
'Exchange rate lookup priority:
1. Exact match on date + rate_type
2. Most recent rate before date + rate_type
3. Default rate for currency pair
4. Fallback rate if specified';
```

### 11.3 System Settings

```sql
-- =================================================================
-- SYSTEM SETTINGS: Application configuration
-- =================================================================
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Scope
    scope VARCHAR(20) NOT NULL DEFAULT 'GLOBAL'
        CHECK (scope IN ('GLOBAL', 'SCHOOL')),
    school_id UUID REFERENCES schools(id),      -- NULL for global settings

    -- Setting
    setting_key VARCHAR(100) NOT NULL,
    setting_value JSONB NOT NULL,
    setting_type VARCHAR(20) NOT NULL
        CHECK (setting_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON', 'DATE')),

    -- Description
    description TEXT,
    is_sensitive BOOLEAN DEFAULT FALSE,         -- Mask in logs/exports

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),

    -- Constraints
    CONSTRAINT unique_setting UNIQUE (scope, school_id, setting_key)
);

CREATE INDEX idx_settings_lookup ON system_settings (scope, school_id, setting_key);
```

---

## 12. Indexes & Performance

### 12.1 Composite Indexes for Polars Engine

```sql
-- =================================================================
-- PERFORMANCE INDEXES
-- =================================================================

-- Fast scenario-based lookups
CREATE INDEX idx_perf_enrollment ON enrollment_inputs (
    school_id, academic_year_id, scenario_id, grade_level_id
) INCLUDE (closing_count, vat_rate);

CREATE INDEX idx_perf_workforce ON workforce_inputs (
    school_id, academic_year_id, scenario_id
) INCLUDE (fte_value, annual_base_salary);

CREATE INDEX idx_perf_dhg ON dhg_inputs (
    school_id, academic_year_id, scenario_id
) INCLUDE (total_dhg_hours, he_ratio, calculated_divisions);

-- ltree hierarchy queries
CREATE INDEX idx_grade_descendants ON grade_levels USING GIST (path);
CREATE INDEX idx_grade_ancestors ON grade_levels USING BTREE (path);
```

---

## 13. Row Level Security

```sql
-- =================================================================
-- ROW LEVEL SECURITY: Multi-tenant isolation
-- Updated for Schema v2.6
-- =================================================================

-- Enable RLS on all tenant tables
ALTER TABLE enrollment_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE workforce_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dhg_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dhg_subject_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE benchmark_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_flow_tranches ENABLE ROW LEVEL SECURITY;
ALTER TABLE pl_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_flow_projections ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_school_access ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their school's data
CREATE POLICY school_isolation_enrollment ON enrollment_inputs
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_workforce ON workforce_inputs
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_dhg ON dhg_inputs
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_dhg_hours ON dhg_subject_hours
    USING (dhg_input_id IN (
        SELECT id FROM dhg_inputs
        WHERE school_id = current_setting('app.current_school_id', true)::UUID
    ));

CREATE POLICY school_isolation_scenarios ON budget_scenarios
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_audit ON audit_logs
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_benchmarks ON benchmark_comparisons
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_fin_periods ON financial_periods
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_tranches ON cash_flow_tranches
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_pl_values ON pl_values
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_cash_proj ON cash_flow_projections
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

-- Users policy: See own data OR data for assigned school
CREATE POLICY user_isolation ON users
    USING (
        id = current_setting('app.current_user_id', true)::UUID
        OR school_id = current_setting('app.current_school_id', true)::UUID
        OR school_id IS NULL  -- Super admins
    );

CREATE POLICY user_school_access_isolation ON user_school_access
    USING (
        user_id = current_setting('app.current_user_id', true)::UUID
        OR school_id = current_setting('app.current_school_id', true)::UUID
    );
```

---

## 14. Seed Data

### 14.1 Education Cycles

```sql
-- =================================================================
-- SEED: Education Cycles
-- =================================================================
INSERT INTO education_cycles (code, name, name_short, path, age_start, age_end, display_order, color_hex) VALUES
('CYCLE_1', 'Cycle 1 - Apprentissages premiers', 'Maternelle', 'root.maternelle', 3, 6, 1, '#4CAF50'),
('CYCLE_2', 'Cycle 2 - Apprentissages fondamentaux', 'Élémentaire CP-CE2', 'root.elementaire.cycle2', 6, 9, 2, '#2196F3'),
('CYCLE_3', 'Cycle 3 - Consolidation', 'CM + 6ème', 'root.elementaire.cycle3', 9, 12, 3, '#FF9800'),
('CYCLE_4', 'Cycle 4 - Approfondissements', 'Collège 5ème-3ème', 'root.college', 12, 15, 4, '#9C27B0'),
('LYCEE', 'Cycle Terminal', 'Lycée', 'root.lycee', 15, 18, 5, '#F44336');
```

### 14.2 Grade Levels

```sql
-- =================================================================
-- SEED: Grade Levels with AEFE Official Hours
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
```

### 14.3 Contract Types

```sql
-- =================================================================
-- SEED: Contract Types with KSA Cost Structure
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
```

### 14.4 User Roles

```sql
-- =================================================================
-- SEED: Default User Roles
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
```

### 14.5 AEFE Benchmarks

```sql
-- =================================================================
-- SEED: AEFE H/E Ratio Benchmarks
-- Source: Tables Enseignants AEFE 2024-2025
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
```

---

## 15. Migration Order

```sql
-- =================================================================
-- MIGRATION ORDER (Execute in sequence)
-- Updated for Schema v2.6
-- =================================================================

-- Phase 1: Extensions
-- 1. CREATE EXTENSION uuid-ossp
-- 2. CREATE EXTENSION ltree
-- 3. CREATE EXTENSION pg_trgm

-- Phase 2: Foundation Tables (No dependencies)
-- 4. CREATE TABLE schools
-- 5. CREATE TABLE academic_years
-- 6. CREATE TABLE education_cycles

-- Phase 3: User Management (Depends on schools)
-- 7. CREATE TABLE user_roles
-- 8. CREATE TABLE users
-- 9. CREATE TABLE user_school_access

-- Phase 4: Scenario Management (Depends on schools, academic_years, users)
-- 10. CREATE TABLE budget_scenarios

-- Phase 5: Grade Structure (Depends on education_cycles)
-- 11. CREATE TABLE grade_levels
-- 12. CREATE TABLE grade_options

-- Phase 6: Reference Data
-- 13. CREATE TABLE contract_types
-- 14. CREATE TABLE aefe_benchmarks

-- Phase 7: Core Business Tables (Depends on scenarios, grades)
-- 15. CREATE TABLE enrollment_inputs
-- 16. CREATE TABLE workforce_inputs
-- 17. CREATE TABLE dhg_inputs
-- 18. CREATE TABLE dhg_subject_hours
-- 19. CREATE TABLE benchmark_comparisons

-- Phase 8: Financial Module (Depends on scenarios, users)
-- 20. CREATE TABLE financial_periods
-- 21. CREATE TABLE cash_flow_tranches
-- 22. CREATE TABLE pl_line_items
-- 23. CREATE TABLE pl_values
-- 24. CREATE TABLE cash_flow_projections

-- Phase 9: Audit & Configuration
-- 25. CREATE TABLE audit_logs
-- 26. CREATE TABLE exchange_rates
-- 27. CREATE TABLE system_settings

-- Phase 10: Performance Indexes
-- 28. CREATE all composite indexes for Polars engine
-- 29. CREATE ltree hierarchy indexes

-- Phase 11: Row Level Security
-- 30. ENABLE RLS on all tenant tables
-- 31. CREATE RLS policies for school isolation

-- Phase 12: Seed Data
-- 32. INSERT education_cycles
-- 33. INSERT grade_levels
-- 34. INSERT contract_types
-- 35. INSERT user_roles
-- 36. INSERT aefe_benchmarks
```

---

## Schema Diagram

```
                                         ┌─────────────────────┐
                                         │      schools        │
                                         │  (Multi-tenant)     │
                                         │  path: LTREE        │
                                         └──────────┬──────────┘
                                                    │
          ┌─────────────────┬───────────────────────┼───────────────────────┬─────────────────┐
          │                 │                       │                       │                 │
┌─────────▼─────────┐ ┌─────▼─────┐      ┌──────────▼──────────┐  ┌─────────▼─────────┐ ┌─────▼─────┐
│  academic_years   │ │   users   │      │  budget_scenarios   │  │  contract_types   │ │user_roles │
│                   │ │  ──────── │      │   path: LTREE       │  │                   │ │           │
│                   │ │ role_id ──┼──────┼───────────────────────────────────────────────►│           │
└─────────┬─────────┘ └─────┬─────┘      └──────────┬──────────┘  └─────────┬─────────┘ └───────────┘
          │                 │                       │                       │
          │                 │                       │                       │
          └─────────────────┴───────────────────────┼───────────────────────┘
                                                    │
          ┌─────────────────────────────────────────┼─────────────────────────────────────────┐
          │                           │             │             │                           │
┌─────────▼─────────┐     ┌───────────▼───────────┐ │ ┌───────────▼───────────┐   ┌───────────▼───────────┐
│ enrollment_inputs │     │    dhg_inputs         │ │ │  workforce_inputs     │   │  financial_periods    │
│  GENERATED:       │     │   GENERATED:          │ │ │   GENERATED:          │   │                       │
│  - closing_count  │     │  - calc_divisions     │ │ │  - annual_salary      │   └───────────┬───────────┘
│  - vat_rate       │     │  - total_dhg_hours    │ │ │                       │               │
└─────────┬─────────┘     │  - he_ratio           │ │ └───────────────────────┘   ┌───────────▼───────────┐
          │               └───────────┬───────────┘ │                             │  cash_flow_projections│
          │                           │             │                             │   GENERATED:          │
          │               ┌───────────▼───────────┐ │                             │  - net_cash_flow      │
          │               │  dhg_subject_hours    │ │                             │  - closing_balance    │
          │               │   GENERATED:          │ │                             └───────────────────────┘
          │               │  - total_hours        │ │
          │               │  - calculated_fte     │ │               ┌─────────────────────────────────────┐
          │               └───────────────────────┘ │               │         FINANCIAL MODULE            │
          │                                         │               ├─────────────────────────────────────┤
          │               ┌───────────────────────┐ │               │  - cash_flow_tranches               │
          │               │  benchmark_comparisons│◄┘               │  - pl_line_items (ltree)            │
          │               │   GENERATED:          │                 │  - pl_values                        │
          │               │  - variance           │                 │  - cash_flow_projections            │
          │               │  - status             │                 └─────────────────────────────────────┘
          │               └───────────┬───────────┘
          │                           │
          │               ┌───────────▼───────────┐
          │               │   aefe_benchmarks     │
          │               │  (Reference Data)     │
          │               └───────────────────────┘
          │
┌─────────▼───────────────────────────────────────┐
│              grade_levels                        │
│  path: LTREE (root.college.sixieme)             │
│  - legal_hours_per_week                          │
│  - service_divisor                               │
│  - he_ratio_target                               │
└─────────────────────────────────────────────────┘
          │
┌─────────▼─────────┐
│ education_cycles  │
│  path: LTREE      │
└───────────────────┘

                    ┌─────────────────────────────────────────────────────┐
                    │              AUDIT & CONFIGURATION                   │
                    ├─────────────────────────────────────────────────────┤
                    │  - audit_logs (tracks all changes)                  │
                    │  - exchange_rates (with rate_type: SPOT/BUDGET/etc) │
                    │  - system_settings (GLOBAL/SCHOOL scope)            │
                    └─────────────────────────────────────────────────────┘
```

---

## ltree Query Examples

```sql
-- Get all grades in Collège
SELECT * FROM grade_levels WHERE path <@ 'root.college';

-- Get all grades from 6ème to Terminale (secondary)
SELECT * FROM grade_levels
WHERE path <@ 'root.college' OR path <@ 'root.lycee'
ORDER BY display_order;

-- Get parent cycle of a grade
SELECT c.* FROM education_cycles c
JOIN grade_levels g ON g.cycle_id = c.id
WHERE g.code = '6EME';

-- Get all descendants (grades) of a cycle
SELECT g.* FROM grade_levels g
WHERE g.path ~ 'root.college.*';

-- Aggregate DHG by cycle using ltree
SELECT
    c.name_short AS cycle,
    SUM(d.total_dhg_hours) AS total_hours,
    AVG(d.he_ratio) AS avg_he_ratio
FROM dhg_inputs d
JOIN grade_levels g ON d.grade_level_id = g.id
JOIN education_cycles c ON g.cycle_id = c.id
WHERE d.school_id = 'xxx' AND d.academic_year_id = 'yyy'
GROUP BY c.name_short, c.display_order
ORDER BY c.display_order;
```
