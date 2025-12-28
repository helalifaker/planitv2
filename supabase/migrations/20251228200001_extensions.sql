-- =================================================================
-- Migration: Extensions
-- PLAN-IT Database Schema for Supabase
-- =================================================================

-- Enable required PostgreSQL extensions
-- Note: uuid-ossp is already enabled in Supabase
CREATE EXTENSION IF NOT EXISTS "ltree";          -- Hierarchical data
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Text search optimization
