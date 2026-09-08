"""Categorias de ingresos y gastos (RF-003).

El usuario ve las predefinidas del sistema mas las suyas propias.
Las predefinidas no se pueden editar ni borrar.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import or_, select

from app.api.deps import CurrentUser, DbSession
from app.models import Category, Transaction
from app.models.enums import TipoMovimiento
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate

router = APIRouter(prefix="/categories", tags=["categorias"])


@router.get("", response_model=list[CategoryOut])
def listar_categorias(
    usuario: CurrentUser, db: DbSession, tipo: TipoMovimiento | None = None
) -> list[Category]:
    consulta = select(Category).where(
        or_(Category.user_id.is_(None), Category.user_id == usuario.id)
    )
    if tipo is not None:
        consulta = consulta.where(Category.tipo == tipo)
    return list(db.scalars(consulta.order_by(Category.tipo, Category.nombre)).all())


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def crear_categoria(datos: CategoryCreate, usuario: CurrentUser, db: DbSession) -> Category:
    categoria = Category(user_id=usuario.id, **datos.model_dump())
    db.add(categoria)
    db.commit()
    db.refresh(categoria)
    return categoria


def _categoria_propia(db: DbSession, usuario: CurrentUser, category_id: int) -> Category:
    categoria = db.get(Category, category_id)
    if categoria is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Categoría no encontrada")
    if categoria.user_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Las categorías predefinidas del sistema no se pueden modificar",
        )
    if categoria.user_id != usuario.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Categoría no encontrada")
    return categoria


@router.patch("/{category_id}", response_model=CategoryOut)
def editar_categoria(
    category_id: int, datos: CategoryUpdate, usuario: CurrentUser, db: DbSession
) -> Category:
    categoria = _categoria_propia(db, usuario, category_id)
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(categoria, campo, valor)
    db.commit()
    db.refresh(categoria)
    return categoria


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_categoria(category_id: int, usuario: CurrentUser, db: DbSession) -> None:
    """No se borra una categoria en uso: dejaria transacciones sin clasificar."""
    categoria = _categoria_propia(db, usuario, category_id)
    en_uso = db.scalar(
        select(Transaction.id).where(Transaction.category_id == category_id).limit(1)
    )
    if en_uso:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La categoría tiene movimientos asociados y no se puede eliminar",
        )
    db.delete(categoria)
    db.commit()
