"""Registro, inicio de sesion y perfil (RF-007).

Casos de uso del diagrama 01: Registrarse, Iniciar sesion, Cerrar sesion,
Cambiar contrasena.
"""

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core import limites
from app.core.config import settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas.user import LoginRequest, PasswordChange, Token, UserCreate, UserOut, UserUpdate

router = APIRouter(prefix="/auth", tags=["autenticacion"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def registrar(datos: UserCreate, db: DbSession) -> Token:
    """Crea la cuenta y devuelve el token, para que la app entre directo sin pedir login."""
    ya_existe = db.scalar(select(User).where(User.email == datos.email))
    if ya_existe:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe una cuenta con ese correo",
        )

    user = User(
        email=datos.email,
        nombre=datos.nombre,
        password_hash=hash_password(datos.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return Token(access_token=create_access_token(user.id), usuario=UserOut.model_validate(user))


@router.post("/login", response_model=Token)
def iniciar_sesion(datos: LoginRequest, peticion: Request, db: DbSession) -> Token:
    ip = peticion.client.host if peticion.client else "desconocida"

    if limites.esta_bloqueada(ip):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                "Demasiados intentos fallidos. "
                f"Espera {settings.VENTANA_LOGIN_MINUTOS} minutos y volve a intentar."
            ),
        )

    user = db.scalar(select(User).where(User.email == datos.email))
    # Mismo mensaje si falla el correo o la contrasena: no revelamos que correos existen.
    if user is None or not verify_password(datos.password, user.password_hash):
        limites.registrar_fallo(ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contrasena incorrectos",
        )

    limites.limpiar(ip)
    return Token(access_token=create_access_token(user.id), usuario=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
def mi_perfil(usuario: CurrentUser) -> User:
    return usuario


@router.patch("/me", response_model=UserOut)
def actualizar_perfil(datos: UserUpdate, usuario: CurrentUser, db: DbSession) -> User:
    cambia_email = datos.email is not None and datos.email != usuario.email
    if cambia_email and db.scalar(select(User).where(User.email == datos.email)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ese correo ya esta en uso",
        )
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(usuario, campo, valor)
    db.commit()
    db.refresh(usuario)
    return usuario


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def cambiar_password(datos: PasswordChange, usuario: CurrentUser, db: DbSession) -> None:
    """Pide la contrasena actual: si alguien roba el telefono desbloqueado, no puede cambiarla."""
    if not verify_password(datos.password_actual, usuario.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contrasena actual no es correcta",
        )
    usuario.password_hash = hash_password(datos.password_nueva)
    db.commit()
