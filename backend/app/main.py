"""Punto de entrada de la API.

Levantar en desarrollo con:
    uv run uvicorn app.main:app --reload
Documentacion interactiva en http://localhost:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="Backend de la aplicacion movil de gestion de finanzas personales.",
)

# La app Flutter corre en otro origen (emulador), asi que necesita CORS abierto en desarrollo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["sistema"])
def health() -> dict[str, str]:
    """Comprobacion rapida de que la API esta viva."""
    return {"status": "ok"}


app.include_router(api_router, prefix=settings.API_V1_PREFIX)
