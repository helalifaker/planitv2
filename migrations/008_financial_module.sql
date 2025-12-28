-- =================================================================
-- Migration 008: Financial Module
-- PLAN-IT Database Schema v2.6
-- =================================================================

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
