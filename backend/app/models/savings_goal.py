"""Metas de ahorro del usuario (RF-005)."""
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import Date, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.enums import EstadoMeta

class SavingsGoal(Base):
    __tablename__ = "savings_goals"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    nombre: Mapped[str] = mapped_column(String(120))
    descripcion: Mapped[str | None] = mapped_column(String(255), nullable=True)
    monto_objetivo: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    monto_actual: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0)
    fecha_objetivo: Mapped[date] = mapped_column(Date)
    estado: Mapped[EstadoMeta] = mapped_column(Enum(EstadoMeta, name="estado_meta"), default=EstadoMeta.ACTIVA)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="savings_goals")
