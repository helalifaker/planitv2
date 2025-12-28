-- =================================================================
-- Migration 003: User Management
-- PLAN-IT Database Schema v2.6
-- =================================================================

-- =================================================================
-- USER ROLES: Permission templates for access control
-- =================================================================
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    code VARCHAR(50) UNIQUE NOT NULL,           -- e.g., "SUPER_ADMIN", "FINANCE_MANAGER"
    name VARCHAR(100) NOT NULL,                 -- "Super Administrator"
    description TEXT,

    -- Permissions (JSONB for flexibility)
    permissions JSONB NOT NULL DEFAULT '{}',
    /*
    Example permissions structure:
    {
        "modules": {
            "enrollment": {"read": true, "write": true, "delete": false},
            "workforce": {"read": true, "write": true, "delete": false},
            "dhg": {"read": true, "write": false, "delete": false},
            "financials": {"read": true, "write": false, "delete": false}
        },
        "scenarios": {
            "create": true,
            "approve": false,
            "lock": false
        },
        "admin": {
            "manage_users": false,
            "manage_schools": false,
            "view_audit_logs": true
        }
    }
    */

    -- Hierarchy
    level INT NOT NULL DEFAULT 0,               -- 0 = highest (admin), higher = less privilege
    is_system_role BOOLEAN DEFAULT FALSE,       -- Cannot be deleted

    -- Display
    color_hex CHAR(7),

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_roles_code ON user_roles (code);
CREATE INDEX idx_user_roles_level ON user_roles (level);

-- =================================================================
-- USERS: System users with school assignment
-- =================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity (from Auth Provider - e.g., Supabase Auth)
    auth_provider_id VARCHAR(255) UNIQUE,       -- External auth ID
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,

    -- Profile
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name || ' ' || last_name, email)
    ) STORED,
    avatar_url TEXT,
    phone VARCHAR(20),

    -- Locale
    preferred_language VARCHAR(5) DEFAULT 'fr', -- 'fr', 'en', 'ar'
    timezone VARCHAR(50) DEFAULT 'Asia/Riyadh',

    -- Role Assignment
    role_id UUID NOT NULL REFERENCES user_roles(id),

    -- School Assignment (NULL = super admin with all-school access)
    school_id UUID REFERENCES schools(id),

    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE'
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED')),
    last_login_at TIMESTAMPTZ,
    login_count INT DEFAULT 0,

    -- Security
    password_changed_at TIMESTAMPTZ,
    must_change_password BOOLEAN DEFAULT FALSE,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    deactivated_at TIMESTAMPTZ,
    deactivated_by UUID REFERENCES users(id)
);

-- Indexes
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_school ON users (school_id);
CREATE INDEX idx_users_role ON users (role_id);
CREATE INDEX idx_users_status ON users (status) WHERE status = 'ACTIVE';

-- =================================================================
-- USER SCHOOL ACCESS: For users with access to multiple schools
-- =================================================================
CREATE TABLE user_school_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,

    -- Override role for this specific school (optional)
    role_override_id UUID REFERENCES user_roles(id),

    -- Access level
    access_type VARCHAR(20) DEFAULT 'FULL'
        CHECK (access_type IN ('FULL', 'READ_ONLY', 'SPECIFIC_MODULES')),
    allowed_modules TEXT[],                     -- If access_type = 'SPECIFIC_MODULES'

    -- Validity
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES users(id),
    expires_at TIMESTAMPTZ,                     -- NULL = never expires

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_user_school UNIQUE (user_id, school_id)
);

CREATE INDEX idx_user_school_access_user ON user_school_access (user_id);
CREATE INDEX idx_user_school_access_school ON user_school_access (school_id);
