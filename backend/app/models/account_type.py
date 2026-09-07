"""Tipos de cuenta (ahorro, corriente, tarjeta, efectivo y los que cree el usuario).

Sigue el mismo patron que las categorias: los que tienen user_id NULL son los
predefinidos del sistema y los ve todo el mundo; los que tienen user_id son
los que creo ese usuario.
"""

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class AccountType(Base):
    __tablename__ = "account_types"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    nombre: Mapped[str] = mapped_column(String(80))
    icono: Mapped[str] = mapped_column(String(40), default="account_balance_wallet")

    user = relationship("User", back_populates="account_types")
    accounts = relationship("Account", back_populates="tipo")

    @property
    def es_predefinido(self) -> bool:
        return self.user_id is None
