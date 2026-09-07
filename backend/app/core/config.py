"""Configuracion de la aplicacion, leida desde variables de entorno o el archivo .env."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Conexion a PostgreSQL
    DATABASE_URL: str = "postgresql+psycopg://finanzas:finanzas@localhost:5433/finanzas"

    # Seguridad (RNF-002)
    SECRET_KEY: str = "cambiar-esta-clave-en-produccion"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # una semana

    # Metadatos de la API
    PROJECT_NAME: str = "API de Finanzas Personales"
    API_V1_PREFIX: str = "/api/v1"


settings = Settings()
