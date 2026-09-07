"""Tipos de cuenta: los predefinidos del sistema mas los que crea el usuario.

Mismo criterio que las categorias: los predefinidos no se pueden editar ni borrar,
y uno propio no se borra si hay cuentas usandolo.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import or_, select

from app.api.deps import CurrentUser, DbSession
from app.models import Account, AccountType
from app.schemas.account_type import AccountTypeCreate, AccountTypeOut, AccountTypeUpdate

router = APIRouter(prefix="/account-types", tags=["tipos de cuenta"])


@router.get("", response_model=list[AccountTypeOut])
def listar_tipos(usuario: CurrentUser, db: DbSession) -> list[AccountType]:
    return list(
        db.scalars(
            select(AccountType)
            .where(or_(AccountType.user_id.is_(None), AccountType.user_id == usuario.id))
            .order_by(AccountType.user_id.is_(None).desc(), AccountType.nombre)
        ).all()
    )


@router.post("", response_model=AccountTypeOut, status_code=status.HTTP_201_CREATED)
def crear_tipo(datos: AccountTypeCreate, usuario: CurrentUser, db: DbSession) -> AccountType:
    tipo = AccountType(user_id=usuario.id, **datos.model_dump())
    db.add(tipo)
    db.commit()
    db.refresh(tipo)
    return tipo


def _tipo_propio(db: DbSession, usuario: CurrentUser, tipo_id: int) -> AccountType:
    tipo = db.get(AccountType, tipo_id)
    if tipo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tipo de cuenta no encontrado"
        )
    if tipo.user_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Los tipos de cuenta predefinidos no se pueden modificar",
        )
    if tipo.user_id != usuario.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tipo de cuenta no encontrado"
        )
    return tipo


@router.patch("/{tipo_id}", response_model=AccountTypeOut)
def editar_tipo(
    tipo_id: int, datos: AccountTypeUpdate, usuario: CurrentUser, db: DbSession
) -> AccountType:
    tipo = _tipo_propio(db, usuario, tipo_id)
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(tipo, campo, valor)
    db.commit()
    db.refresh(tipo)
    return tipo


@router.delete("/{tipo_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_tipo(tipo_id: int, usuario: CurrentUser, db: DbSession) -> None:
    tipo = _tipo_propio(db, usuario, tipo_id)
    en_uso = db.scalar(select(Account.id).where(Account.account_type_id == tipo_id).limit(1))
    if en_uso:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Hay cuentas usando este tipo y no se puede eliminar",
        )
    db.delete(tipo)
    db.commit()
