"""Metas de ahorro y seguimiento de progreso (RF-005)."""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from app.api.deps import CurrentUser, DbSession
from app.models import SavingsGoal
from app.models.enums import EstadoMeta
from app.schemas.savings_goal import SavingsGoalCreate, SavingsGoalOut, SavingsGoalUpdate

router = APIRouter(prefix="/goals", tags=["metas de ahorro"])

def _out(g: SavingsGoal) -> SavingsGoalOut:
    progreso = min(100.0, float(g.monto_actual / g.monto_objetivo * 100)) if g.monto_objetivo else 0
    return SavingsGoalOut(id=g.id, nombre=g.nombre, descripcion=g.descripcion,
        monto_objetivo=g.monto_objetivo, monto_actual=g.monto_actual,
        fecha_objetivo=g.fecha_objetivo, estado=g.estado, progreso=round(progreso, 2))

@router.get("", response_model=list[SavingsGoalOut])
def listar(usuario: CurrentUser, db: DbSession) -> list[SavingsGoalOut]:
    return [_out(g) for g in db.scalars(select(SavingsGoal).where(SavingsGoal.user_id == usuario.id).order_by(SavingsGoal.fecha_objetivo, SavingsGoal.id)).all()]

@router.post("", response_model=SavingsGoalOut, status_code=status.HTTP_201_CREATED)
def crear(datos: SavingsGoalCreate, usuario: CurrentUser, db: DbSession) -> SavingsGoalOut:
    g = SavingsGoal(user_id=usuario.id, **datos.model_dump())
    if g.monto_actual >= g.monto_objetivo: g.estado = EstadoMeta.COMPLETADA
    db.add(g); db.commit(); db.refresh(g)
    return _out(g)

@router.patch("/{goal_id}", response_model=SavingsGoalOut)
def editar(goal_id: int, datos: SavingsGoalUpdate, usuario: CurrentUser, db: DbSession) -> SavingsGoalOut:
    g = db.scalar(select(SavingsGoal).where(SavingsGoal.id == goal_id, SavingsGoal.user_id == usuario.id))
    if g is None: raise HTTPException(status_code=404, detail="Meta no encontrada")
    for campo, valor in datos.model_dump(exclude_unset=True).items(): setattr(g, campo, valor)
    if g.estado == EstadoMeta.ACTIVA and g.monto_actual >= g.monto_objetivo: g.estado = EstadoMeta.COMPLETADA
    db.commit(); db.refresh(g)
    return _out(g)

@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(goal_id: int, usuario: CurrentUser, db: DbSession) -> None:
    g = db.scalar(select(SavingsGoal).where(SavingsGoal.id == goal_id, SavingsGoal.user_id == usuario.id))
    if g is None: raise HTTPException(status_code=404, detail="Meta no encontrada")
    db.delete(g); db.commit()
