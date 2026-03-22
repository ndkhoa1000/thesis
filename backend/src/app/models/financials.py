"""Financial domain models: Payment, Invoice."""

from datetime import UTC, datetime

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import PayableType, PaymentMethod, PaymentStatus


class Payment(Base):
    __tablename__ = "payment"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    payable_id: Mapped[int] = mapped_column(Integer, index=True)
    driver_id: Mapped[int] = mapped_column(ForeignKey("driver.id"), index=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    final_amount: Mapped[float] = mapped_column(Numeric(12, 2))
    # Optional / defaulted fields
    payable_type: Mapped[str] = mapped_column(String(20), default=PayableType.SESSION.value)
    discount: Mapped[float] = mapped_column(Numeric(12, 2), default=0.00)
    payment_method: Mapped[str] = mapped_column(String(20), default=PaymentMethod.CASH.value)
    payment_status: Mapped[str] = mapped_column(String(20), default=PaymentStatus.PENDING.value)
    processed_by: Mapped[int | None] = mapped_column(ForeignKey("user.id"), default=None)
    note: Mapped[str | None] = mapped_column(String(255), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class Invoice(Base):
    __tablename__ = "invoice"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    payment_id: Mapped[int] = mapped_column(ForeignKey("payment.id"), unique=True, index=True)
    invoice_number: Mapped[str] = mapped_column(String(20), unique=True)
    issued_by: Mapped[int] = mapped_column(ForeignKey("user.id"), index=True)
    # Optional / defaulted fields
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    print_count: Mapped[int] = mapped_column(Integer, default=0)
