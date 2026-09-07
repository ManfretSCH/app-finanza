"""Cuentas bancarias, de ahorro, tarjetas o efectivo (RF-001)."""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import TipoCuenta


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    nombre: Mapped[str] = mapped_column(String(120))
    tipo: Mapped[TipoCuenta] = mapped_column(Enum(TipoCuenta, name="tipo_cuenta"))
    # Numeric y no float: con dinero los errores de redondeo no son aceptables.
    saldo_inicial: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=Decimal("0.00"))
    moneda: Mapped[str] = mapped_column(String(3), default="PYG")
    activa: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="accounts")
    transactions = relationship(
        "Transaction", back_populates="account", cascade="all, delete-orphan"
    )
