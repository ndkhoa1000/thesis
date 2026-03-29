"""Lease domain models: LotLease, LeaseContract."""

from datetime import UTC, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import LeaseContractStatus, LeaseStatus


class LotLease(Base):
    __tablename__ = "lot_lease"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    manager_id: Mapped[int] = mapped_column(ForeignKey("manager.id"), index=True)
    monthly_fee: Mapped[float] = mapped_column(Numeric(12, 2))
    revenue_share_percentage: Mapped[float] = mapped_column(Numeric(5, 2), default=0.00)
    term_months: Mapped[int] = mapped_column(Integer, default=1)
    # Optional / defaulted fields
    start_date: Mapped[datetime | None] = mapped_column(Date, default=None)
    end_date: Mapped[datetime | None] = mapped_column(Date, default=None)
    status: Mapped[str] = mapped_column(String(20), default=LeaseStatus.PENDING.value)
    contract_file: Mapped[str | None] = mapped_column(String(255), default=None)
    approved_by: Mapped[int | None] = mapped_column(ForeignKey("user.id"), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class LeaseContract(Base):
    __tablename__ = "lease_contract"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    lease_id: Mapped[int] = mapped_column(ForeignKey("lot_lease.id"), unique=True, index=True)
    contract_number: Mapped[str] = mapped_column(String(40), unique=True)
    # Optional / defaulted fields
    content: Mapped[str | None] = mapped_column(Text, default=None)
    generated_by: Mapped[int | None] = mapped_column(ForeignKey("user.id"), default=None)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    status: Mapped[str] = mapped_column(String(20), default=LeaseContractStatus.DRAFT.value)
