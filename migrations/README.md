# PLAN-IT Database Migrations

Database Schema v2.6 - KSA & AEFE Logic

## Migration Order

Execute migrations in numerical order:

| # | File | Description |
|---|------|-------------|
| 001 | `001_extensions.sql` | PostgreSQL extensions (uuid-ossp, ltree, pg_trgm) |
| 002 | `002_foundation_tables.sql` | Schools, Academic Years, Education Cycles |
| 003 | `003_user_management.sql` | User Roles, Users, User School Access |
| 004 | `004_scenario_management.sql` | Budget Scenarios with ltree hierarchy |
| 005 | `005_grade_structure.sql` | Grade Levels and Grade Options |
| 006 | `006_reference_data.sql` | Contract Types, AEFE Benchmarks |
| 007 | `007_core_business_tables.sql` | Enrollment, Workforce, DHG, Benchmarks |
| 008 | `008_financial_module.sql` | Financial Periods, Cash Flow, P&L |
| 009 | `009_audit_configuration.sql` | Audit Logs, Exchange Rates, Settings |
| 010 | `010_performance_indexes.sql` | Composite indexes for Polars engine |
| 011 | `011_row_level_security.sql` | RLS policies for multi-tenancy |
| 012 | `012_seed_data.sql` | Initial reference data |

## Running Migrations

### Using psql directly:

```bash
# Connect to database and run all migrations
psql -h localhost -U postgres -d planit -f migrations/001_extensions.sql
psql -h localhost -U postgres -d planit -f migrations/002_foundation_tables.sql
# ... continue for all files
```

### Using the runner script:

```bash
./migrations/run_all.sh
```

### Using Alembic (if configured):

```bash
alembic upgrade head
```

## Prerequisites

- PostgreSQL 17+ (18 recommended for latest features)
- Extensions must be installed by a superuser:
  - `uuid-ossp`
  - `ltree`
  - `pg_trgm`

## Post-Migration Setup

After running migrations, configure RLS bypass for the service role:

```sql
-- Run as superuser
ALTER ROLE planit_service BYPASSRLS;
```

## Rollback

Each migration should have a corresponding rollback script in `rollbacks/` directory (to be created).

## Notes

- All tables use UUID primary keys
- Multi-tenancy is enforced via Row Level Security
- GENERATED columns are used for calculated fields (no triggers needed)
- ltree extension is used for hierarchical data (grades, P&L structure)
