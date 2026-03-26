"""Parking lot endpoints scaffold."""

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from fastcrud import PaginatedListResponse, compute_offset, paginated_response
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import NotFoundException

router = APIRouter(tags=["lots"])


@router.get("/lots", status_code=200)
async def list_lots(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
    page: int = 1,
    items_per_page: int = 10,
) -> dict[str, str]:
    # Scaffold: full implementation in feature epics
    return {"message": "lots endpoint scaffold"}
