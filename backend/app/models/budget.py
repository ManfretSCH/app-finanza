"""Presupuestos mensuales por categoria (RF-004).

Un presupuesto es un limite de gasto para una categoria en un mes puntual. Lo
gastado no se guarda: se calcula a partir de las transacciones, igual que el
saldo de las cuentas, para que nunca quede desfasado del historial.
"""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Budget(Base):
    __tablename__ = "budgets"
    __table_args__ = (
        # No puede haber dos limites para la misma categoria en el mismo mes.
        UniqueConstraint(
            "user_id", "category_id", "anio", "mes", name="uq_budget_user_category_period"
        ),
        CheckConstraint("mes >= 1 AND mes <= 12", name="ck_budget_mes"),
        CheckConstraint("limite > 0", name="ck_budget_limite"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # Si se borra la categoria, su presupuesto deja de tener sentido.
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id", ondelete="CASCADE"), index=True
    )
    anio: Mapped[int] = mapped_column(Integer)
    mes: Mapped[int] = mapped_column(Integer)
    limite: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="budgets")
    category = relationship("Category")
