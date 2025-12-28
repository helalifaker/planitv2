-- =================================================================
-- Migration: Row Level Security
-- PLAN-IT Database Schema for Supabase
-- Multi-tenant isolation policies using Supabase Auth
-- =================================================================

-- =================================================================
-- HELPER FUNCTION: Get user's school_id from profile
-- =================================================================
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT school_id
        FROM public.profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- =================================================================
-- HELPER FUNCTION: Check if user has access to a school
-- =================================================================
CREATE OR REPLACE FUNCTION public.user_has_school_access(check_school_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin (no school_id) has access to all
    IF (SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL THEN
        RETURN TRUE;
    END IF;

    -- Primary school assignment
    IF (SELECT school_id FROM public.profiles WHERE id = auth.uid()) = check_school_id THEN
        RETURN TRUE;
    END IF;

    -- Additional school access
    RETURN EXISTS (
        SELECT 1
        FROM public.user_school_access
        WHERE user_id = auth.uid()
          AND school_id = check_school_id
          AND is_active = TRUE
          AND (expires_at IS NULL OR expires_at > NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- =================================================================
-- ENABLE RLS ON ALL TABLES
-- =================================================================

ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_school_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollment_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE workforce_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dhg_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dhg_subject_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE benchmark_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_flow_tranches ENABLE ROW LEVEL SECURITY;
ALTER TABLE pl_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_flow_projections ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- =================================================================
-- SCHOOLS POLICIES
-- =================================================================
CREATE POLICY "Users can view schools they have access to"
    ON schools FOR SELECT
    USING (
        public.user_has_school_access(id)
        OR is_active = TRUE  -- Allow viewing active schools for dropdown
    );

CREATE POLICY "Super admins can manage schools"
    ON schools FOR ALL
    USING (
        (SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL
    );

-- =================================================================
-- PROFILES POLICIES
-- =================================================================
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can view profiles in their school"
    ON profiles FOR SELECT
    USING (
        school_id IS NULL  -- Super admins visible to all
        OR public.user_has_school_access(school_id)
    );

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "Super admins can manage all profiles"
    ON profiles FOR ALL
    USING (
        (SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL
    );

-- =================================================================
-- USER SCHOOL ACCESS POLICIES
-- =================================================================
CREATE POLICY "Users can view their own access"
    ON user_school_access FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Super admins can manage school access"
    ON user_school_access FOR ALL
    USING (
        (SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL
    );

-- =================================================================
-- SCHOOL DATA ISOLATION POLICIES
-- =================================================================

-- Budget Scenarios
CREATE POLICY "school_isolation_scenarios"
    ON budget_scenarios FOR ALL
    USING (public.user_has_school_access(school_id));

-- Enrollment Inputs
CREATE POLICY "school_isolation_enrollment"
    ON enrollment_inputs FOR ALL
    USING (public.user_has_school_access(school_id));

-- Workforce Inputs
CREATE POLICY "school_isolation_workforce"
    ON workforce_inputs FOR ALL
    USING (public.user_has_school_access(school_id));

-- DHG Inputs
CREATE POLICY "school_isolation_dhg"
    ON dhg_inputs FOR ALL
    USING (public.user_has_school_access(school_id));

-- DHG Subject Hours (through parent)
CREATE POLICY "school_isolation_dhg_hours"
    ON dhg_subject_hours FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM dhg_inputs
            WHERE dhg_inputs.id = dhg_subject_hours.dhg_input_id
              AND public.user_has_school_access(dhg_inputs.school_id)
        )
    );

-- Benchmark Comparisons
CREATE POLICY "school_isolation_benchmarks"
    ON benchmark_comparisons FOR ALL
    USING (public.user_has_school_access(school_id));

-- Financial Periods
CREATE POLICY "school_isolation_fin_periods"
    ON financial_periods FOR ALL
    USING (public.user_has_school_access(school_id));

-- Cash Flow Tranches
CREATE POLICY "school_isolation_tranches"
    ON cash_flow_tranches FOR ALL
    USING (public.user_has_school_access(school_id));

-- P&L Values
CREATE POLICY "school_isolation_pl_values"
    ON pl_values FOR ALL
    USING (public.user_has_school_access(school_id));

-- Cash Flow Projections
CREATE POLICY "school_isolation_cash_proj"
    ON cash_flow_projections FOR ALL
    USING (public.user_has_school_access(school_id));

-- Audit Logs
CREATE POLICY "school_isolation_audit"
    ON audit_logs FOR SELECT
    USING (
        school_id IS NULL  -- Global logs visible to super admins
        OR public.user_has_school_access(school_id)
    );

CREATE POLICY "audit_insert_allowed"
    ON audit_logs FOR INSERT
    WITH CHECK (TRUE);  -- Allow inserting audit logs

-- =================================================================
-- REFERENCE DATA POLICIES (Read-only for all authenticated users)
-- =================================================================

ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE education_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE grade_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE grade_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE aefe_benchmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE pl_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Reference data readable by all authenticated users
CREATE POLICY "reference_data_readable" ON academic_years FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON education_cycles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON grade_levels FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON grade_options FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON contract_types FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON aefe_benchmarks FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON user_roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON pl_line_items FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "reference_data_readable" ON exchange_rates FOR SELECT USING (auth.uid() IS NOT NULL);

-- System settings: global readable, school-specific by access
CREATE POLICY "system_settings_readable"
    ON system_settings FOR SELECT
    USING (
        scope = 'GLOBAL'
        OR (scope = 'SCHOOL' AND public.user_has_school_access(school_id))
    );

-- Super admins can manage reference data
CREATE POLICY "super_admin_manage_reference" ON academic_years FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON education_cycles FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON grade_levels FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON grade_options FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON contract_types FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON aefe_benchmarks FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON user_roles FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON pl_line_items FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_reference" ON exchange_rates FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
CREATE POLICY "super_admin_manage_settings" ON system_settings FOR ALL
    USING ((SELECT school_id FROM public.profiles WHERE id = auth.uid()) IS NULL);
