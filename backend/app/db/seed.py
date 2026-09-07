"""Carga las categorias predefinidas del sistema (RF-003).

Son las que ve todo usuario nuevo. Tienen user_id NULL y no se pueden editar
ni borrar desde la API. Ejecutar con:  uv run python -m app.db.seed
"""

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models import Category
from app.models.enums import TipoMovimiento

CATEGORIAS_PREDEFINIDAS: list[tuple[str, TipoMovimiento, str, str]] = [
    # Gastos
    ("Alimentacion", TipoMovimiento.GASTO, "restaurant", "#FF7043"),
    ("Transporte", TipoMovimiento.GASTO, "directions_bus", "#42A5F5"),
    ("Vivienda", TipoMovimiento.GASTO, "home", "#8D6E63"),
    ("Servicios", TipoMovimiento.GASTO, "bolt", "#FFA726"),
    ("Salud", TipoMovimiento.GASTO, "local_hospital", "#EF5350"),
    ("Educacion", TipoMovimiento.GASTO, "school", "#5C6BC0"),
    ("Entretenimiento", TipoMovimiento.GASTO, "movie", "#AB47BC"),
    ("Ropa", TipoMovimiento.GASTO, "checkroom", "#EC407A"),
    ("Otros gastos", TipoMovimiento.GASTO, "category", "#78909C"),
    # Ingresos
    ("Salario", TipoMovimiento.INGRESO, "payments", "#66BB6A"),
    ("Trabajo independiente", TipoMovimiento.INGRESO, "work", "#26A69A"),
    ("Inversiones", TipoMovimiento.INGRESO, "trending_up", "#9CCC65"),
    ("Otros ingresos", TipoMovimiento.INGRESO, "savings", "#26C6DA"),
]


def cargar_categorias_predefinidas() -> int:
    """Inserta las que falten. Es idempotente: se puede correr varias veces sin duplicar."""
    creadas = 0
    with SessionLocal() as db:
        for nombre, tipo, icono, color in CATEGORIAS_PREDEFINIDAS:
            existe = db.scalar(
                select(Category).where(Category.user_id.is_(None), Category.nombre == nombre)
            )
            if existe is None:
                db.add(Category(user_id=None, nombre=nombre, tipo=tipo, icono=icono, color=color))
                creadas += 1
        db.commit()
    return creadas


if __name__ == "__main__":
    n = cargar_categorias_predefinidas()
    print(f"Categorias predefinidas creadas: {n}")
