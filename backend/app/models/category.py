"""Categorias de ingresos y gastos (RF-003).

Las que tienen user_id NULL son las predefinidas del sistema y las ve todo el mundo;
las que tienen user_id son las que creo ese usuario.
"""

from sqlalchemy import Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import TipoMovimiento


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    nombre: Mapped[str] = mapped_column(String(80))
    tipo: Mapped[TipoMovimiento] = mapped_column(Enum(TipoMovimiento, name="tipo_movimiento"))
    icono: Mapped[str] = mapped_column(String(40), default="category")
    color: Mapped[str] = mapped_column(String(7), default="#607D8B")

    user = relationship("User", back_populates="categories")

    @property
    def es_predefinida(self) -> bool:
        return self.user_id is None
