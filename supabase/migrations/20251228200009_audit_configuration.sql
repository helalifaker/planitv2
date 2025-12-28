-- =================================================================
-- Migration: Audit & Configuration
-- PLAN-IT Database Schema for Supabase
-- =================================================================

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
    user_id UUID REFERENCES auth.users(id),
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

-- =================================================================
-- EXCHANGE RATES: SAR/EUR conversion with rate types
-- Supports: Budget rates, Spot rates, AEFE official rates
-- =================================================================
CREATE TABLE exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Currency Pair
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,

    -- Rate Type
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

    -- Default Handling
    is_default BOOLEAN DEFAULT FALSE,           -- Use as default when no specific rate found
    fallback_rate_id UUID REFERENCES exchange_rates(id),  -- Fallback if this rate not available

    -- Variance Tracking
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
    created_by UUID REFERENCES auth.users(id),

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
    updated_by UUID REFERENCES auth.users(id),

    -- Constraints
    CONSTRAINT unique_setting UNIQUE (scope, school_id, setting_key)
);

CREATE INDEX idx_settings_lookup ON system_settings (scope, school_id, setting_key);
