"""Dependencias compartidas por los endpoints."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

DbSession = Annotated[Session, Depends(get_db)]


def get_current_user(
    db: DbSession,
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Resuelve el usuario dueno del token.

    Todos los endpoints protegidos dependen de esto, y despues filtran sus consultas
    por el id de este usuario. Asi ningun usuario puede ver datos de otro (RNF-002).
    """
    credenciales_invalidas = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales invalidas o sesion vencida",
        headers={"WWW-Authenticate": "Bearer"},
    )

    user_id = decode_access_token(token)
    if user_id is None:
        raise credenciales_invalidas

    user = db.get(User, user_id)
    if user is None:
        raise credenciales_invalidas
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
