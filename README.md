# App de Gestión de Finanzas Personales

Aplicación móvil para centralizar el control de ingresos, gastos, cuentas, presupuestos y metas de ahorro.

**Taller de Ingeniería de Software** — Gustavo Molinas (líder), Matias Moreno, Maiquel Schroter, Ezequiel Rejala, Luana Aguayo.

## Arquitectura

Tres capas, según el Hito 3:

| Capa | Tecnología | Carpeta |
|---|---|---|
| Presentación | Flutter (Dart) | `mobile/` |
| Lógica de negocio | Python + FastAPI | `backend/` |
| Datos | PostgreSQL 16 | `docker-compose.yml` |

Documentación del análisis en [`docs/`](docs/): [requerimientos](docs/requerimientos.md), [modelo de datos](docs/modelo-datos.md) y los [diagramas de casos de uso](docs/diagramas/).

## Cómo levantar el proyecto

### 1. Base de datos

Requiere **Docker Desktop abierto**.

```bash
docker compose up -d
```

Postgres queda escuchando en `localhost:5433` (usuario `finanzas`, contraseña `finanzas`, base `finanzas`). Se usa el puerto 5433 y no el 5432 para no chocar con un Postgres que ya esté instalado en la máquina.

Para verificar que arrancó:

```bash
docker compose ps
```

### 2. Backend

Requiere [uv](https://docs.astral.sh/uv/) (`brew install uv`). El proyecto está fijado a **Python 3.13**; uv lo descarga solo si no lo tenés.

```bash
cd backend
cp .env.example .env      # y generá tu propia SECRET_KEY
uv sync                   # instala dependencias en .venv
uv run alembic upgrade head   # crea las tablas
uv run uvicorn app.main:app --reload
```

La API queda en `http://localhost:8000` y la documentación interactiva en **http://localhost:8000/docs**.

Para generar una `SECRET_KEY` propia:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 3. App móvil

> **Todavía no creada.** Falta instalar el SDK de Flutter en la máquina.

Requiere el [SDK de Flutter](https://docs.flutter.dev/get-started/install/macos) y un emulador (Android Studio o Xcode).

```bash
cd mobile
flutter pub get
flutter run
```

## Comandos útiles

| Qué | Comando |
|---|---|
| Crear una migración tras cambiar los modelos | `cd backend && uv run alembic revision --autogenerate -m "descripcion"` |
| Aplicar migraciones | `cd backend && uv run alembic upgrade head` |
| Correr los tests del backend | `cd backend && uv run pytest` |
| Revisar el estilo del código Python | `cd backend && uv run ruff check .` |
| Apagar la base de datos | `docker compose down` |
| Borrar la base de datos y empezar de cero | `docker compose down -v` |

## Estado del proyecto

| Módulo | Contenido | Entrega | Estado |
|---|---|---|---|
| Fase 0 | Estructura, base de datos, esqueleto de la API | — | ✅ Listo |
| Módulo 1 | Autenticación, cuentas, categorías y transacciones | 09/10/2026 | ✅ Backend listo · ⏳ App móvil pendiente |
| Módulo 2 | Presupuestos y metas de ahorro | 16/10/2026 | Pendiente |
| Módulo 3 | Reportes, gráficos y exportación | 23/10/2026 | Pendiente |

## Flujo de trabajo en Git

Una rama por funcionalidad, pull request, revisión del líder y merge a `main`:

```bash
git checkout -b feat/nombre-de-la-funcionalidad
# ... cambios ...
git commit -m "feat: descripcion breve"
git push -u origin feat/nombre-de-la-funcionalidad
```
