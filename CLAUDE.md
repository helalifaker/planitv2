# Plan-It | Claude Context

## Project Overview
Plan-It is an FP&A (Financial Planning & Analysis) platform for KSA Community Schools operating under the AEFE (French Education Agency). The platform shifts schools from "Passive Accounting" to "Strategic Piloting" using a driver-based simulation engine.

## Tech Stack (LOCKED)
- **Frontend:** pnpm + Next.js 16 + React 19 + Tailwind 4 + Shadcn/UI + Glide Data Grid
- **Backend:** uv + Python 3.14 + FastAPI + Polars + DuckDB
- **Database:** PostgreSQL 18 with ltree extension
- **Cache:** Redis 8

## Architecture
Data flows in one direction through 4 blocks:
```
Enrollment (A) → Divisions (B) → DHG/Workforce (C) → Financials (D)
```

## Key Commands
```bash
# Frontend (from /frontend)
pnpm dev          # Start dev server with Turbopack
pnpm build        # Production build
pnpm lint         # Run ESLint
pnpm type-check   # TypeScript check

# Backend (from /backend)
uv sync           # Install dependencies
uv run uvicorn app.main:app --reload  # Start dev server
uv run pytest     # Run tests

# Docker
docker compose up -d  # Start all services
```

## Directory Structure
```
/backend/app/
  /api/v1/         # API routes by module
  /core/config/    # Settings and configuration
  /domain/         # Business logic
  /engine/polars/  # Calculation engine

/frontend/src/
  /app/workspace/  # Main workspace pages
  /components/ui/  # Shadcn components
  /lib/            # Utilities, stores, API hooks
```

## Domain Terms
- **DHG:** Dotation Horaire Globale (Total Weekly Hours)
- **H/E Ratio:** Hours per Student (efficiency metric)
- **FTE:** Full Time Equivalent
- **Résident:** Expat staff (paid in EUR, high cost)
- **Local Family Visa:** Local staff (paid in SAR, low cost via Ajeer)

## Important Notes
- All tables use UUID primary keys with `gen_random_uuid()`
- Use TIMESTAMPTZ for all timestamps
- RLS (Row Level Security) is required for multi-tenant isolation
- Currency: SAR (operational) / EUR (AEFE reporting)
