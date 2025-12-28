-- =================================================================
-- Migration 005: Grade Structure
-- PLAN-IT Database Schema v2.6
-- =================================================================

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
