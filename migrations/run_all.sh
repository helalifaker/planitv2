#!/bin/bash
# =================================================================
# PLAN-IT Database Migration Runner
# Executes all migrations in order
# =================================================================

set -e  # Exit on error

# Configuration - Override with environment variables
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-planit}"
DB_USER="${DB_USER:-postgres}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}PLAN-IT Database Migration Runner${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""
echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo ""

# Migration files in order
MIGRATIONS=(
    "001_extensions.sql"
    "002_foundation_tables.sql"
    "003_user_management.sql"
    "004_scenario_management.sql"
    "005_grade_structure.sql"
    "006_reference_data.sql"
    "007_core_business_tables.sql"
    "008_financial_module.sql"
    "009_audit_configuration.sql"
    "010_performance_indexes.sql"
    "011_row_level_security.sql"
    "012_seed_data.sql"
)

# Run each migration
for migration in "${MIGRATIONS[@]}"; do
    echo -e "${YELLOW}Running: ${migration}${NC}"

    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "${SCRIPT_DIR}/${migration}" 2>&1; then
        echo -e "${GREEN}✓ Completed: ${migration}${NC}"
    else
        echo -e "${RED}✗ Failed: ${migration}${NC}"
        exit 1
    fi
    echo ""
done

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}All migrations completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Configure RLS bypass for service role:"
echo "   ALTER ROLE planit_service BYPASSRLS;"
echo ""
echo "2. Create your first school and admin user"
echo ""
