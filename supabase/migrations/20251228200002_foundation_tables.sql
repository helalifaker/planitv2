-- =================================================================
-- Migration: Foundation Tables
-- PLAN-IT Database Schema for Supabase
-- =================================================================

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

-- =================================================================
-- EDUCATION CYCLES: French Education System Phases
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
