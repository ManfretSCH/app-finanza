"""Punto de entrada de la API.

Levantar en desarrollo con:
    uv run uvicorn app.main:app --reload
Documentacion interactiva en http://localhost:8000/docs
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.seed import cargar_categorias_predefinidas, cargar_tipos_de_cuenta_predefinidos


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    """Deja la base lista antes de atender el primer pedido.

    Las categorias y los tipos de cuenta predefinidos son parte del estado base
    del sistema: sin ellos un usuario nuevo no podria cargar ni un gasto. La
    carga es idempotente, asi que correrla en cada arranque no duplica nada.

    Las migraciones NO se aplican aca sino en el comando de despliegue: si se
    levantaran varias instancias a la vez, todas intentarian migrar al mismo
    tiempo.
    """
    cargar_tipos_de_cuenta_predefinidos()
    cargar_categorias_predefinidas()
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="Backend de la aplicacion movil de gestion de finanzas personales.",
    lifespan=ciclo_de_vida,
    # En produccion se ocultan la documentacion interactiva y el esquema: no
    # hacen falta para la app y le dan a cualquiera el mapa completo de la API.
    docs_url=None if settings.es_produccion else "/docs",
    redoc_url=None if settings.es_produccion else "/redoc",
    openapi_url=None if settings.es_produccion else "/openapi.json",
)

# La app movil no usa CORS (no es un navegador), pero si alguna vez se hace una
# version web hay que listar los dominios en CORS_ORIGENES en vez del comodin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origenes_cors,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["sistema"])
def health() -> dict[str, str]:
    """Comprobacion rapida de que la API esta viva.

    Render la consulta para saber si el servicio quedo bien desplegado.
    """
    return {"status": "ok", "entorno": settings.ENTORNO}


app.include_router(api_router, prefix=settings.API_V1_PREFIX)
