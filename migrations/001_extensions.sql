-- =================================================================
-- Migration 001: Extensions
-- PLAN-IT Database Schema v2.6
-- =================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "ltree";          -- Hierarchical data
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Text search optimization
