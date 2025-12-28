"""Workforce API Routes (Block C)."""

from uuid import UUID

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/")
async def list_workforce(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """List workforce/staffing data."""
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "staff": [],
    }


@router.get("/fte-summary")
async def get_fte_summary(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """Get FTE summary by subject and contract type."""
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "fte_by_subject": [],
        "fte_by_contract": [],
    }
