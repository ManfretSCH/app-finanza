# Imagen del backend, usada por Render.
#
# Se compila con Docker y no con el entorno de Python de Render para que lo que
# corre en el servidor sea exactamente lo mismo que corre en la maquina de cada
# uno: misma version de Python y mismas dependencias fijadas en uv.lock.

FROM python:3.13-slim

# uv resuelve e instala las dependencias respetando uv.lock
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Las dependencias se instalan antes de copiar el codigo: mientras uv.lock no
# cambie, Docker reutiliza esta capa y el despliegue tarda mucho menos.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app

RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

# La app no corre como root: si alguien lograra ejecutar algo dentro del
# contenedor, lo hace con los permisos minimos.
RUN useradd --create-home --uid 1000 finanzas && chown -R finanzas:finanzas /app
USER finanzas

EXPOSE 8000

# Render entrega el puerto en la variable PORT.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
