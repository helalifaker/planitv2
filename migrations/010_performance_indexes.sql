-- =================================================================
-- Migration 010: Performance Indexes
-- PLAN-IT Database Schema v2.6
-- Optimized for Polars Engine queries
-- =================================================================

-- =================================================================
-- COMPOSITE INDEXES FOR POLARS ENGINE
-- =================================================================

-- Fast scenario-based lookups with covering columns
CREATE INDEX idx_perf_enrollment ON enrollment_inputs (
    school_id, academic_year_id, scenario_id, grade_level_id
) INCLUDE (closing_count, vat_rate);

CREATE INDEX idx_perf_workforce ON workforce_inputs (
    school_id, academic_year_id, scenario_id
) INCLUDE (fte_value, annual_base_salary);

CREATE INDEX idx_perf_dhg ON dhg_inputs (
    school_id, academic_year_id, scenario_id
) INCLUDE (total_dhg_hours, he_ratio, calculated_divisions);

-- =================================================================
-- LTREE HIERARCHY INDEXES
-- =================================================================

-- Descendants query (get all children)
CREATE INDEX idx_grade_descendants ON grade_levels USING GIST (path);

-- Ancestors query (get parents)
CREATE INDEX idx_grade_ancestors ON grade_levels USING BTREE (path);

-- P&L line items hierarchy
CREATE INDEX idx_pl_items_descendants ON pl_line_items USING GIST (path);
CREATE INDEX idx_pl_items_ancestors ON pl_line_items USING BTREE (path);

-- =================================================================
-- FINANCIAL MODULE INDEXES
-- =================================================================

-- Cash flow projections with alert status
CREATE INDEX idx_cash_proj_alerts_detail ON cash_flow_projections (
    school_id, academic_year_id, scenario_id, is_below_threshold
) INCLUDE (closing_balance_sar, net_cash_flow_sar);

-- P&L values for period aggregation
CREATE INDEX idx_pl_values_aggregation ON pl_values (
    school_id, academic_year_id, scenario_id
) INCLUDE (amount_sar, amount_eur);

-- Financial periods for date range queries
CREATE INDEX idx_fin_periods_dates ON financial_periods (
    school_id, start_date, end_date
);

-- =================================================================
-- BENCHMARK COMPARISON INDEXES
-- =================================================================

-- Quick status lookups
CREATE INDEX idx_benchmark_status_detail ON benchmark_comparisons (
    school_id, academic_year_id, status
) INCLUDE (actual_value, target_value, variance_pct);

-- =================================================================
-- USER & ACCESS INDEXES
-- =================================================================

-- Active users per school
CREATE INDEX idx_users_active_school ON users (school_id)
    WHERE status = 'ACTIVE';

-- User school access with expiry
CREATE INDEX idx_user_access_active ON user_school_access (user_id, school_id)
    WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW());

-- =================================================================
-- AUDIT LOG INDEXES
-- =================================================================

-- Recent changes by table
CREATE INDEX idx_audit_recent ON audit_logs (table_name, created_at DESC);

-- Changes by school in time range
CREATE INDEX idx_audit_school_time ON audit_logs (school_id, created_at DESC);
