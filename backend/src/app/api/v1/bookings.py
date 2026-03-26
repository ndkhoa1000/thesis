"""Booking endpoints scaffold."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.db.database import async_get_db

router = APIRouter(tags=["bookings"])


@router.get("/bookings", status_code=200)
async def list_bookings(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    # Scaffold: full implementation in feature epics
    return {"message": "bookings endpoint scaffold"}
