-- =================================================================
-- Migration 006: Reference Data (Contract Types & AEFE Benchmarks)
-- PLAN-IT Database Schema v2.6
-- =================================================================

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
