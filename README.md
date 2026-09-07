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

### Qué hace hoy

- **Cuentas** con saldo calculado a partir de los movimientos.
- **Movimientos**: alta de ingresos y gastos, filtros y borrado.
- **Informes**: resumen del mes, gasto promedio por día, gasto día por día, en qué se va la plata y de dónde viene (por categoría), y la tendencia del año.
- **Categorías y tipos de cuenta** propios, además de los del sistema.

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

Requiere el [SDK de Flutter](https://docs.flutter.dev/get-started/install/macos) (`brew install --cask flutter`) y un emulador: **Android Studio** o **Xcode completo** (las Command Line Tools solas no alcanzan).

```bash
cd mobile
flutter pub get
flutter run
```

La app apunta al backend según dónde corra, en [`lib/core/api_client.dart`](mobile/lib/core/api_client.dart):

| Dónde corre | Dirección del backend |
|---|---|
| Emulador de Android | `http://10.0.2.2:8000` — para el emulador, `localhost` es él mismo, no tu Mac |
| Simulador de iOS | `http://localhost:8000` |

El backend tiene que estar corriendo antes de abrir la app.

#### Probar en Android

```bash
flutter run -d emulator-5554
```

Si no hay ningún emulador arrancado, se abre uno desde el Device Manager de Android Studio, o por consola:

```bash
~/Library/Android/sdk/emulator/emulator -avd NOMBRE_DEL_AVD
```

Para que `flutter doctor` quede sin avisos hace falta instalar el componente **cmdline-tools** (Android Studio → Settings → Languages & Frameworks → Android SDK → SDK Tools → *Android SDK Command-line Tools*) y aceptar las licencias del SDK:

```bash
flutter doctor --android-licenses
```

#### Probar en iPhone (iOS)

La carpeta `ios/` ya está creada y configurada — identificador `py.edu.ua.finanzas.appFinanzas`, iOS 15 como mínimo. Solo faltan las herramientas de Apple, que se instalan una sola vez:

1. **Xcode** desde el App Store (~10 GB, requiere Apple ID).
2. Apuntar las herramientas de línea de comandos a Xcode:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```
3. Primer arranque de Xcode y sus componentes:
   ```bash
   sudo xcodebuild -runFirstLaunch
   ```
4. **CocoaPods**, que es lo que enlaza los plugins de Flutter en iOS:
   ```bash
   brew install cocoapods
   ```
5. Correr la app:
   ```bash
   open -a Simulator
   flutter run -d iPhone
   ```

Con las Command Line Tools solas no alcanza: `flutter doctor` lo reporta como *"Xcode installation is incomplete"*.

## Comandos útiles

| Qué | Comando |
|---|---|
| Crear una migración tras cambiar los modelos | `cd backend && uv run alembic revision --autogenerate -m "descripcion"` |
| Aplicar migraciones | `cd backend && uv run alembic upgrade head` |
| Correr los tests del backend | `cd backend && uv run pytest` |
| Revisar el estilo del código Python | `cd backend && uv run ruff check .` |
| Correr los tests de la app | `cd mobile && flutter test` |
| Revisar el código Dart | `cd mobile && flutter analyze` |
| Apagar la base de datos | `docker compose down` |
| Borrar la base de datos y empezar de cero | `docker compose down -v` |

## Estado del proyecto

| Módulo | Contenido | Entrega | Estado |
|---|---|---|---|
| Fase 0 | Estructura, base de datos, esqueleto de la API | — | ✅ Listo |
| Módulo 1 | Autenticación, cuentas, categorías y transacciones | 09/10/2026 | ✅ Listo (backend + app) |
| Módulo 2 | Presupuestos y metas de ahorro | 16/10/2026 | Pendiente |
| Módulo 3 | Informes y gráficos | 23/10/2026 | ✅ Listo · ⏳ falta exportar a PDF/CSV |

## Flujo de trabajo en Git

Una rama por funcionalidad, pull request, revisión del líder y merge a `main`:

```bash
git checkout -b feat/nombre-de-la-funcionalidad
# ... cambios ...
git commit -m "feat: descripcion breve"
git push -u origin feat/nombre-de-la-funcionalidad
```
