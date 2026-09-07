#!/usr/bin/env bash
#
# Levanta la base de datos y el backend en un solo comando.
#
# Hace lo mismo que se haria a mano, en orden: abre Docker si esta apagado,
# levanta PostgreSQL, espera a que acepte conexiones, aplica las migraciones
# que falten y arranca el servidor.
#
#   ./scripts/arrancar-backend.sh
#
# Se detiene con Ctrl+C. La base queda encendida; para apagarla tambien:
#   docker compose down
#
set -euo pipefail

cd "$(dirname "$0")/.."

echo "1/4  Docker"
if ! docker info >/dev/null 2>&1; then
  echo "     Docker esta apagado, abriendolo..."
  open -a Docker
  for _ in $(seq 1 40); do
    docker info >/dev/null 2>&1 && break
    sleep 5
  done
  if ! docker info >/dev/null 2>&1; then
    echo "     No se pudo iniciar Docker. Abrilo a mano y volve a intentar."
    exit 1
  fi
fi
echo "     listo"

echo "2/4  Base de datos"
docker compose up -d >/dev/null
# Levantar el contenedor no significa que PostgreSQL ya acepte conexiones:
# si se sigue sin esperar, las migraciones fallan.
for _ in $(seq 1 30); do
  docker exec finanzas-db pg_isready -U finanzas -d finanzas >/dev/null 2>&1 && break
  sleep 2
done
if ! docker exec finanzas-db pg_isready -U finanzas -d finanzas >/dev/null 2>&1; then
  echo "     PostgreSQL no respondio. Revisa: docker compose logs db"
  exit 1
fi
echo "     PostgreSQL acepta conexiones"

cd backend

echo "3/4  Migraciones"
if [ ! -f .env ]; then
  echo "     Falta el archivo .env; se crea desde .env.example con una clave nueva."
  python3 - <<'PY'
import pathlib, secrets
texto = pathlib.Path(".env.example").read_text()
texto = texto.replace(
    "SECRET_KEY=cambiar-esta-clave-en-produccion",
    "SECRET_KEY=" + secrets.token_urlsafe(32),
)
pathlib.Path(".env").write_text(texto)
PY
fi
uv run alembic upgrade head >/dev/null 2>&1
echo "     base al dia ($(uv run alembic current 2>/dev/null | tail -1))"

echo "4/4  Servidor"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo '')"
echo
echo "     Documentacion:  http://localhost:8000/docs"
[ -n "$IP" ] && echo "     Desde la red:   http://${IP}:8000"
echo "     Ctrl+C para detenerlo"
echo

# --reload reinicia el servidor solo al guardar un archivo del backend.
exec uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
