"""Financials API Routes (Block D)."""

from uuid import UUID

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/pl")
async def get_profit_loss(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
    fiscal_year: int = Query(..., description="Fiscal year (e.g., 2024)"),
) -> dict:
    """Get Profit & Loss statement."""
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "fiscal_year": fiscal_year,
        "revenue": {},
        "expenses": {},
        "surplus": 0,
        "staff_cost_ratio": 0,
    }


@router.get("/cashflow")
async def get_cashflow(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
    fiscal_year: int = Query(..., description="Fiscal year (e.g., 2024)"),
) -> dict:
    """Get monthly cash flow projection.

    KSA-specific: Tuition tranches in Aug/Jan/Apr, monthly salary outflows.
    """
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "fiscal_year": fiscal_year,
        "monthly_cashflow": [],
        "minimum_balance": 500000,
        "currency": "SAR",
    }
