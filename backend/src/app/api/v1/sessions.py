"""Parking session endpoints scaffold."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.db.database import async_get_db

router = APIRouter(tags=["sessions"])


@router.get("/sessions", status_code=200)
async def list_sessions(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    # Scaffold: full implementation in feature epics
    return {"message": "sessions endpoint scaffold"}
