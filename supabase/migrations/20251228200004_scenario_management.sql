-- =================================================================
-- Migration: Scenario Management
-- PLAN-IT Database Schema for Supabase
-- =================================================================

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
    approved_by UUID REFERENCES auth.users(id),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),

    -- Constraints
    CONSTRAINT unique_scenario_code UNIQUE (school_id, academic_year_id, code)
);

-- Only one baseline per school/year
CREATE UNIQUE INDEX idx_scenario_baseline
    ON budget_scenarios (school_id, academic_year_id)
    WHERE is_baseline = TRUE;

CREATE INDEX idx_scenario_path ON budget_scenarios USING GIST (path);
CREATE INDEX idx_scenario_lookup ON budget_scenarios (school_id, academic_year_id);
