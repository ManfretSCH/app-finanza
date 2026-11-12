"""Metas de ahorro del usuario (RF-005).

El usuario fija cuanto quiere juntar y para cuando, y va registrando lo que
lleva ahorrado. La meta pasa sola a completada cuando lo ahorrado alcanza el
objetivo.
"""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import EstadoMeta


class SavingsGoal(Base):
    __tablename__ = "savings_goals"
    __table_args__ = (
        CheckConstraint("monto_objetivo > 0", name="ck_savings_goal_target_positive"),
        CheckConstraint("monto_actual >= 0", name="ck_savings_goal_saved_nonnegative"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    nombre: Mapped[str] = mapped_column(String(120))
    descripcion: Mapped[str | None] = mapped_column(String(255), nullable=True)
    monto_objetivo: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    monto_actual: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=Decimal(0))
    fecha_objetivo: Mapped[date] = mapped_column(Date)
    estado: Mapped[EstadoMeta] = mapped_column(
        Enum(EstadoMeta, name="estado_meta"), default=EstadoMeta.ACTIVA
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="savings_goals")
