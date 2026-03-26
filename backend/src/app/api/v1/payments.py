"""Payment and invoice endpoints scaffold."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.db.database import async_get_db

router = APIRouter(tags=["payments"])


@router.get("/payments", status_code=200)
async def list_payments(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    # Scaffold: full implementation in feature epics
    return {"message": "payments endpoint scaffold"}
