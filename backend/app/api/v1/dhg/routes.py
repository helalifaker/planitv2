"""DHG (Dotation Horaire Globale) API Routes."""

from uuid import UUID

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/")
async def get_dhg(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """Get DHG calculation results.

    Returns:
        - Total theoretical DHG
        - DHG by grade level
        - Group/option hours
        - H/E ratio with benchmark comparison
    """
    return {
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
        "total_dhg": 0,
        "dhg_by_grade": [],
        "he_ratio": 0,
        "he_benchmark": 1.45,
        "efficiency_status": "unknown",
    }


@router.post("/calculate")
async def calculate_dhg(
    school_id: UUID = Query(..., description="School UUID"),
    scenario_id: UUID = Query(..., description="Scenario UUID"),
) -> dict:
    """Trigger DHG recalculation based on current enrollment data.

    Calculation flow:
    1. Load enrollment data -> Calculate divisions per grade
    2. Load grade_levels -> Get legal_hours_per_week
    3. Calculate total DHG: divisions x legal_hours + group_hours + option_hours
    4. Calculate H/E ratio: total_dhg / total_students
    5. Compare vs AEFE benchmarks
    """
    return {
        "status": "calculated",
        "school_id": str(school_id),
        "scenario_id": str(scenario_id),
    }
