"""Esquemas de usuario y autenticacion (RF-007)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    nombre: str = Field(min_length=2, max_length=120)
    password: str = Field(min_length=8, max_length=72, description="Minimo 8 caracteres")


class UserUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=2, max_length=120)
    email: EmailStr | None = None


class PasswordChange(BaseModel):
    password_actual: str
    password_nueva: str = Field(min_length=8, max_length=72)


class UserOut(BaseModel):
    """Lo que devuelve la API: nunca incluye el hash de la contrasena."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    nombre: str
    created_at: datetime


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UserOut
