"""Ingresos y gastos registrados por el usuario (RF-002)."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import TipoMovimiento


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    # De que movimiento fijo salio, si salio de alguno.
    recurring_id: Mapped[int | None] = mapped_column(
        ForeignKey("recurring_movements.id", ondelete="SET NULL"), nullable=True, index=True
    )

    tipo: Mapped[TipoMovimiento] = mapped_column(Enum(TipoMovimiento, name="tipo_movimiento"))
    monto: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    descripcion: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Indexada porque casi todas las consultas filtran u ordenan por fecha (RNF-001).
    fecha: Mapped[date] = mapped_column(Date, index=True)
    etiquetas: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="transactions")
    account = relationship("Account", back_populates="transactions")
    category = relationship("Category")
    recurrente = relationship("RecurringMovement", back_populates="generados")
