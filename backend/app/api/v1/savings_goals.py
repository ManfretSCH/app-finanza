"""Metas de ahorro y seguimiento de su progreso (RF-005).

Casos de uso del diagrama 05: Crear meta de ahorro, Ver metas.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import case, select

from app.api.deps import CurrentUser, DbSession
from app.models import SavingsGoal
from app.models.enums import EstadoMeta
from app.schemas.savings_goal import (
    AporteMeta,
    SavingsGoalCreate,
    SavingsGoalOut,
    SavingsGoalUpdate,
)

router = APIRouter(prefix="/goals", tags=["metas de ahorro"])


def _actualizar_estado(meta: SavingsGoal) -> None:
    """Completada si lo ahorrado alcanza el objetivo; si no, activa.

    Una meta cancelada queda cancelada hasta que el usuario la reactive. Se
    recalcula en cada cambio: si se sube el objetivo de una meta completada,
    vuelve a estar activa.
    """
    if meta.estado == EstadoMeta.CANCELADA:
        return
    if meta.monto_actual >= meta.monto_objetivo:
        meta.estado = EstadoMeta.COMPLETADA
    else:
        meta.estado = EstadoMeta.ACTIVA


def _salida(meta: SavingsGoal) -> SavingsGoalOut:
    progreso = min(100.0, float(meta.monto_actual / meta.monto_objetivo * 100))
    return SavingsGoalOut(
        id=meta.id,
        nombre=meta.nombre,
        descripcion=meta.descripcion,
        monto_objetivo=meta.monto_objetivo,
        monto_actual=meta.monto_actual,
        fecha_objetivo=meta.fecha_objetivo,
        estado=meta.estado,
        progreso=round(progreso, 2),
    )


def _propia(db: DbSession, usuario: CurrentUser, goal_id: int) -> SavingsGoal:
    meta = db.scalar(
        select(SavingsGoal).where(SavingsGoal.id == goal_id, SavingsGoal.user_id == usuario.id)
    )
    if meta is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meta no encontrada")
    return meta


@router.get("", response_model=list[SavingsGoalOut])
def listar(usuario: CurrentUser, db: DbSession) -> list[SavingsGoalOut]:
    """Primero las activas, por fecha objetivo más próxima; al final las cerradas."""
    metas = db.scalars(
        select(SavingsGoal)
        .where(SavingsGoal.user_id == usuario.id)
        .order_by(
            case((SavingsGoal.estado == EstadoMeta.ACTIVA, 0), else_=1),
            SavingsGoal.fecha_objetivo,
            SavingsGoal.id,
        )
    ).all()
    return [_salida(m) for m in metas]


@router.post("", response_model=SavingsGoalOut, status_code=status.HTTP_201_CREATED)
def crear(datos: SavingsGoalCreate, usuario: CurrentUser, db: DbSession) -> SavingsGoalOut:
    meta = SavingsGoal(user_id=usuario.id, estado=EstadoMeta.ACTIVA, **datos.model_dump())
    _actualizar_estado(meta)
    db.add(meta)
    db.commit()
    db.refresh(meta)
    return _salida(meta)


@router.patch("/{goal_id}", response_model=SavingsGoalOut)
def editar(
    goal_id: int, datos: SavingsGoalUpdate, usuario: CurrentUser, db: DbSession
) -> SavingsGoalOut:
    """Cambia los datos de la meta, la cancela (estado "cancelada") o la reactiva ("activa")."""
    meta = _propia(db, usuario, goal_id)
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(meta, campo, valor)
    _actualizar_estado(meta)
    db.commit()
    db.refresh(meta)
    return _salida(meta)


@router.post("/{goal_id}/aportar", response_model=SavingsGoalOut)
def aportar(
    goal_id: int, datos: AporteMeta, usuario: CurrentUser, db: DbSession
) -> SavingsGoalOut:
    """Suma plata a lo ya ahorrado, que es lo que el usuario hace casi siempre."""
    meta = _propia(db, usuario, goal_id)
    if meta.estado == EstadoMeta.CANCELADA:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La meta está cancelada. Reactivala para seguir sumando.",
        )
    meta.monto_actual += datos.monto
    _actualizar_estado(meta)
    db.commit()
    db.refresh(meta)
    return _salida(meta)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(goal_id: int, usuario: CurrentUser, db: DbSession) -> None:
    meta = _propia(db, usuario, goal_id)
    db.delete(meta)
    db.commit()
