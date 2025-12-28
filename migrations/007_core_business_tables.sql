-- =================================================================
-- Migration 007: Core Business Tables
-- PLAN-IT Database Schema v2.6
-- =================================================================

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
