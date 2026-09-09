"""Movimientos fijos: se cargan una vez y se repiten todos los meses.

Cubre gastos fijos (alquiler, cuotas, servicios) y tambien ingresos fijos
como el sueldo.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.api.v1.transactions import _validar_referencias
from app.models import RecurringMovement
from app.schemas.recurring import (
    RecurringCreate,
    RecurringOut,
    RecurringUpdate,
    ResultadoGeneracion,
)
from app.services import recurrentes

router = APIRouter(prefix="/recurring", tags=["movimientos fijos"])


@router.get("", response_model=list[RecurringOut])
def listar(usuario: CurrentUser, db: DbSession) -> list[RecurringMovement]:
    return list(
        db.scalars(
            select(RecurringMovement)
            .where(RecurringMovement.user_id == usuario.id)
            .options(selectinload(RecurringMovement.category))
            .order_by(RecurringMovement.dia_del_mes, RecurringMovement.id)
        ).all()
    )


@router.post("", response_model=RecurringOut, status_code=status.HTTP_201_CREATED)
def crear(datos: RecurringCreate, usuario: CurrentUser, db: DbSession) -> RecurringMovement:
    _validar_referencias(db, usuario, datos.account_id, datos.category_id)

    fijo = RecurringMovement(user_id=usuario.id, **datos.model_dump())
    db.add(fijo)
    db.commit()
    db.refresh(fijo)

    # Se generan de una los movimientos que ya correspondan, para que el usuario
    # vea el efecto sin tener que esperar a la proxima vez que abra la app.
    recurrentes.generar_pendientes(db, usuario.id)
    db.refresh(fijo)
    return fijo


def _propio(db: DbSession, usuario: CurrentUser, fijo_id: int) -> RecurringMovement:
    fijo = db.scalar(
        select(RecurringMovement).where(
            RecurringMovement.id == fijo_id, RecurringMovement.user_id == usuario.id
        )
    )
    if fijo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movimiento fijo no encontrado"
        )
    return fijo


@router.patch("/{fijo_id}", response_model=RecurringOut)
def editar(
    fijo_id: int, datos: RecurringUpdate, usuario: CurrentUser, db: DbSession
) -> RecurringMovement:
    """Cambia la plantilla de aca en adelante.

    Los movimientos ya generados no se tocan: si en marzo el alquiler fue otro,
    eso ya paso y es parte del historial. Para corregir un mes puntual se edita
    ese movimiento en la lista.
    """
    fijo = _propio(db, usuario, fijo_id)
    cambios = datos.model_dump(exclude_unset=True)
    _validar_referencias(db, usuario, cambios.get("account_id"), cambios.get("category_id"))

    for campo, valor in cambios.items():
        setattr(fijo, campo, valor)
    db.commit()
    db.refresh(fijo)

    recurrentes.generar_pendientes(db, usuario.id)
    db.refresh(fijo)
    return fijo


@router.delete("/{fijo_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(fijo_id: int, usuario: CurrentUser, db: DbSession) -> None:
    """Deja de generar movimientos nuevos.

    Los que ya se generaron quedan: el usuario efectivamente gasto esa plata y
    borrarlos le cambiaria el saldo y los informes de meses cerrados.
    """
    fijo = _propio(db, usuario, fijo_id)
    db.delete(fijo)
    db.commit()


@router.post("/run", response_model=ResultadoGeneracion)
def ponerse_al_dia(usuario: CurrentUser, db: DbSession) -> ResultadoGeneracion:
    """Genera los movimientos que falten hasta hoy.

    La app la llama al iniciar sesion. Es idempotente: llamarla de mas no
    duplica nada.
    """
    return ResultadoGeneracion(generados=recurrentes.generar_pendientes(db, usuario.id))
