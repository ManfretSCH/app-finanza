"""Corregir los acentos de los datos predefinidos

Los nombres de las categorias y los tipos de cuenta que trae el sistema se
guardaron sin acentos y se muestran tal cual en la app. Esta migracion los
corrige en las bases que ya estan en uso.

Solo toca las filas del sistema (user_id IS NULL). Las categorias que haya
creado cada usuario quedan como las escribio.

Revision ID: 63df1396f798
Revises: 2f312f981bab
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "63df1396f798"
down_revision: str | Sequence[str] | None = "2f312f981bab"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CATEGORIAS = [
    ("Alimentacion", "Alimentación"),
    ("Educacion", "Educación"),
]

TIPOS_DE_CUENTA = [
    ("Tarjeta de credito", "Tarjeta de crédito"),
]


def _renombrar(tabla: str, pares: list[tuple[str, str]], invertir: bool = False) -> None:
    for viejo, nuevo in pares:
        origen, destino = (nuevo, viejo) if invertir else (viejo, nuevo)
        op.execute(
            sa.text(
                f"UPDATE {tabla} SET nombre = :destino "
                "WHERE user_id IS NULL AND nombre = :origen"
            ).bindparams(origen=origen, destino=destino)
        )


def upgrade() -> None:
    _renombrar("categories", CATEGORIAS)
    _renombrar("account_types", TIPOS_DE_CUENTA)


def downgrade() -> None:
    _renombrar("categories", CATEGORIAS, invertir=True)
    _renombrar("account_types", TIPOS_DE_CUENTA, invertir=True)
