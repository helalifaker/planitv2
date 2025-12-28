-- =================================================================
-- Migration 011: Row Level Security
-- PLAN-IT Database Schema v2.6
-- Multi-tenant isolation policies
-- =================================================================

-- =================================================================
-- ENABLE RLS ON ALL TENANT TABLES
-- =================================================================

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

-- =================================================================
-- SCHOOL ISOLATION POLICIES
-- Users can only see their school's data
-- =================================================================

CREATE POLICY school_isolation_enrollment ON enrollment_inputs
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_workforce ON workforce_inputs
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_dhg ON dhg_inputs
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_dhg_hours ON dhg_subject_hours
    FOR ALL
    USING (dhg_input_id IN (
        SELECT id FROM dhg_inputs
        WHERE school_id = current_setting('app.current_school_id', true)::UUID
    ));

CREATE POLICY school_isolation_scenarios ON budget_scenarios
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_audit ON audit_logs
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_benchmarks ON benchmark_comparisons
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_fin_periods ON financial_periods
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_tranches ON cash_flow_tranches
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_pl_values ON pl_values
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

CREATE POLICY school_isolation_cash_proj ON cash_flow_projections
    FOR ALL
    USING (school_id = current_setting('app.current_school_id', true)::UUID);

-- =================================================================
-- USER POLICIES
-- See own data OR data for assigned school
-- =================================================================

CREATE POLICY user_isolation ON users
    FOR ALL
    USING (
        id = current_setting('app.current_user_id', true)::UUID
        OR school_id = current_setting('app.current_school_id', true)::UUID
        OR school_id IS NULL  -- Super admins
    );

CREATE POLICY user_school_access_isolation ON user_school_access
    FOR ALL
    USING (
        user_id = current_setting('app.current_user_id', true)::UUID
        OR school_id = current_setting('app.current_school_id', true)::UUID
    );

-- =================================================================
-- HELPER FUNCTION: Set session context
-- Call this at the start of each request in FastAPI
-- =================================================================

CREATE OR REPLACE FUNCTION set_session_context(
    p_user_id UUID,
    p_school_id UUID
) RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', p_user_id::TEXT, true);
    PERFORM set_config('app.current_school_id', p_school_id::TEXT, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- BYPASS POLICY FOR SERVICE ROLE
-- For Polars engine and background jobs
-- =================================================================

-- Create a service role if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'planit_service') THEN
        CREATE ROLE planit_service;
    END IF;
END
$$;

-- Grant bypass to service role
ALTER TABLE enrollment_inputs FORCE ROW LEVEL SECURITY;
ALTER TABLE workforce_inputs FORCE ROW LEVEL SECURITY;
ALTER TABLE dhg_inputs FORCE ROW LEVEL SECURITY;

-- Note: The actual bypass is typically done via:
-- ALTER ROLE planit_service BYPASSRLS;
-- This should be run by a superuser during deployment
