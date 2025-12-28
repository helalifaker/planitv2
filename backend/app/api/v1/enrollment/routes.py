"""Enrollment API Routes (Block A)."""

from uuid import UUID

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/")
async def list_enrollments(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """List enrollment data for a school and scenario."""
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "enrollments": [],
    }


@router.get("/divisions")
async def get_divisions(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """Get calculated divisions based on enrollment.

    Division calculation: ROUNDUP(Student_Count / Max_Cap)
    """
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "divisions": [],
    }
