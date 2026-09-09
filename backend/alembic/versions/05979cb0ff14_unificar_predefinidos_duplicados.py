"""Unificar los datos predefinidos que quedaron duplicados

Al corregirle los acentos a las categorias predefinidas, cualquier servidor que
arrancara antes de aplicar la migracion las volvia a crear: el seed las buscaba
por nombre exacto, no encontraba "Alimentación" y la insertaba, quedando junto a
"Alimentacion". Esta migracion junta esos pares.

De cada grupo se conserva el de menor id, que es el original y el que tiene los
movimientos, y se apunta hacia el todo lo que referenciaba a los otros antes de
borrarlos.

El seed ya no puede volver a provocarlo: ahora compara sin acentos y le corrige
la escritura al que encuentra en vez de crear uno nuevo.

Revision ID: 05979cb0ff14
Revises: 6981e3ebef47
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "05979cb0ff14"
down_revision: str | Sequence[str] | None = "6981e3ebef47"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Tabla de predefinidos -> tablas y columnas que la referencian
REFERENCIAS = {
    "categories": [("transactions", "category_id"), ("recurring_movements", "category_id")],
    "account_types": [("accounts", "account_type_id")],
}


def _unificar(tabla: str) -> None:
    conexion = op.get_bind()

    # Grupos de filas del sistema cuyo nombre coincide si se ignoran los acentos.
    grupos = conexion.execute(
        sa.text(
            f"""
            SELECT lower(unaccent_simulado) AS clave, array_agg(id ORDER BY id) AS ids
            FROM (
                SELECT id,
                       translate(nombre, 'áéíóúÁÉÍÓÚñÑ', 'aeiouAEIOUnN') AS unaccent_simulado
                FROM {tabla}
                WHERE user_id IS NULL
            ) AS normalizados
            GROUP BY lower(unaccent_simulado)
            HAVING count(*) > 1
            """
        )
    ).all()

    for _clave, ids in grupos:
        conservado, *sobrantes = ids
        for tabla_ref, columna in REFERENCIAS[tabla]:
            conexion.execute(
                sa.text(
                    f"UPDATE {tabla_ref} SET {columna} = :conservado "
                    f"WHERE {columna} = ANY(:sobrantes)"
                ).bindparams(conservado=conservado, sobrantes=sobrantes)
            )
        conexion.execute(
            sa.text(f"DELETE FROM {tabla} WHERE id = ANY(:sobrantes)").bindparams(
                sobrantes=sobrantes
            )
        )


def upgrade() -> None:
    for tabla in REFERENCIAS:
        _unificar(tabla)


def downgrade() -> None:
    """No se puede deshacer.

    Los duplicados eran filas sin uso creadas por error; volver a crearlas no
    tendria ningun sentido ni forma de saber cuales eran.
    """
