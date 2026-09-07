"""Configuracion de la aplicacion, leida desde variables de entorno o el archivo .env."""

import secrets
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

CLAVE_DE_EJEMPLO = "cambiar-esta-clave-en-produccion"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # "local" en la maquina de cada uno, "produccion" en el servidor desplegado.
    ENTORNO: Literal["local", "produccion"] = "local"

    # Conexion a PostgreSQL
    DATABASE_URL: str = "postgresql+psycopg://finanzas:finanzas@localhost:5433/finanzas"

    # Seguridad (RNF-002)
    SECRET_KEY: str = CLAVE_DE_EJEMPLO
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # una semana

    # Intentos de inicio de sesion permitidos por IP antes de bloquear un rato
    INTENTOS_LOGIN_MAXIMOS: int = 10
    VENTANA_LOGIN_MINUTOS: int = 15

    # Origenes permitidos para CORS, separados por coma.
    # La app movil no usa CORS, pero si alguna vez se hace una version web hay
    # que listar aca los dominios en lugar de dejar el comodin.
    CORS_ORIGENES: str = "*"

    # Metadatos de la API
    PROJECT_NAME: str = "API de Finanzas Personales"
    API_V1_PREFIX: str = "/api/v1"

    @property
    def es_produccion(self) -> bool:
        return self.ENTORNO == "produccion"

    @property
    def origenes_cors(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGENES.split(",") if o.strip()]

    @model_validator(mode="after")
    def _validar_para_produccion(self) -> "Settings":
        """Corta el arranque si el servidor quedaria expuesto con la clave de ejemplo.

        Es preferible que el despliegue falle a que quede publicado firmando
        tokens con una clave que esta escrita en el repositorio: cualquiera
        podria fabricarse una sesion de cualquier usuario.
        """
        if self.es_produccion and self.SECRET_KEY == CLAVE_DE_EJEMPLO:
            nueva = secrets.token_urlsafe(32)
            raise ValueError(
                "SECRET_KEY sigue siendo la de ejemplo y el entorno es produccion.\n"
                f"Defini la variable SECRET_KEY con un valor propio, por ejemplo:\n  {nueva}"
            )
        return self


settings = Settings()
