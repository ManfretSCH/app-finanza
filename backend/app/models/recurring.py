"""Movimientos fijos: se cargan una vez y se repiten todos los meses.

Es una plantilla, no un movimiento. Cada mes se genera a partir de ella una
transaccion de verdad, para que el saldo y los informes no tengan que saber
nada de esto y funcionen igual que siempre.
"""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import TipoMovimiento


class RecurringMovement(Base):
    __tablename__ = "recurring_movements"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))

    # Sirve igual para un gasto fijo (alquiler) que para un ingreso fijo (sueldo).
    tipo: Mapped[TipoMovimiento] = mapped_column(Enum(TipoMovimiento, name="tipo_movimiento"))
    monto: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    descripcion: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Dia del mes en que corresponde. Si el mes no llega a ese dia (31 en
    # febrero), se usa el ultimo dia del mes.
    dia_del_mes: Mapped[int] = mapped_column(Integer)

    fecha_inicio: Mapped[date] = mapped_column(Date)
    # Sin fecha de fin sigue indefinidamente.
    fecha_fin: Mapped[date | None] = mapped_column(Date, nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="recurring_movements")
    account = relationship("Account")
    category = relationship("Category")
    # Al borrar la plantilla NO se borran los movimientos ya generados: son
    # historia real, el usuario ya gasto esa plata.
    generados = relationship("Transaction", back_populates="recurrente")
