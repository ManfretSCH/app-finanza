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
- **Exportar** el informe del mes en CSV (para planilla) o PDF (para imprimir o enviar).

**API desplegada:** https://finanzas-api-zbqy.onrender.com — backend en Render, base en Neon. Ver la [guía de despliegue](docs/despliegue.md).

Documentación en [`docs/`](docs/): [requerimientos](docs/requerimientos.md), [modelo de datos](docs/modelo-datos.md), [diagramas de casos de uso](docs/diagramas/) y [guía de despliegue](docs/despliegue.md).

## Cómo levantar el proyecto

### El camino corto

Dos terminales, un comando en cada una:

```bash
./scripts/arrancar-backend.sh
```

```bash
cd mobile && flutter run
```

El primer script abre Docker si hace falta, levanta PostgreSQL, aplica las migraciones que falten y arranca el servidor. El segundo compila la app y la instala en el emulador que esté abierto.

Si no hay ningún emulador corriendo, se abre uno antes desde el Device Manager de Android Studio, o por consola:

```bash
~/Library/Android/sdk/emulator/emulator -avd ClickVirtual_Pixel7
```

Para apagar todo: `Ctrl+C` en cada terminal, y `docker compose down` para la base.

### El camino largo, paso a paso

Conviene conocerlo para poder diagnosticar cuando algo falla.

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

#### Repartir un APK al equipo

Para que los demás prueben la app en su celular sin instalar nada de desarrollo:

```bash
./scripts/apk-para-el-equipo.sh https://finanzas-api.onrender.com
```

El script compila el APK apuntando a esa dirección y deja en `build-equipo/` el archivo y un instructivo para pasarles.

Si se le pasa una IP en vez de una URL (o nada, y detecta la de esta máquina), apunta al backend local. En ese caso compila en modo depuración, porque Android bloquea el tráfico sin cifrar en las compilaciones de release; y todos tienen que estar en la misma Wi-Fi con el backend encendido.

Dos cosas que hay que tener en cuenta:

- **La dirección del backend se fija al compilar.** Si cambia, hay que generar un APK nuevo. Por eso conviene apuntar al backend desplegado y no a una IP de red local.
- **El APK se firma con las claves de depuración**, que es lo que Flutter usa por defecto. Sirve para repartir entre nosotros, pero antes de publicar en Play Store hay que generar una clave propia.

El APK excluye la arquitectura `x86_64`, que solo usan los emuladores: son 20 MB que ningún teléfono real necesita. Para probar en un emulador conviene usar `flutter run`.

### Desplegar el backend

Para que la app funcione desde cualquier lado sin depender de la computadora de nadie: ver la [guía de despliegue](docs/despliegue.md). Backend en Render y base en Neon, ambos con capa gratuita.

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
| Módulo 3 | Informes, gráficos y exportación | 23/10/2026 | ✅ Listo |

## Flujo de trabajo en Git

La rama `main` está protegida: **nadie puede pushear directo a ella**, y todo cambio entra por pull request con la aprobación del líder del grupo. Es lo que se planificó en el Hito 2, ahora aplicado por GitHub y no solo por acuerdo.

Cada funcionalidad va en su propia rama:

```bash
git checkout main && git pull
git checkout -b feat/presupuestos
# ... cambios ...
git commit -m "Agregar presupuestos mensuales por categoria"
git push -u origin feat/presupuestos
```

Después, desde GitHub, "Compare & pull request". La plantilla recuerda qué verificar antes de pedir revisión.

**Qué pasa si intentás pushear a `main` directamente:** GitHub rechaza el push con un mensaje sobre reglas de protección. No es un error tuyo, es la protección haciendo su trabajo. Creá una rama y abrí un pull request.

Antes de pedir revisión, que todo esté en verde:

```bash
cd backend && uv run pytest && uv run ruff check .
cd ../mobile && flutter test && flutter analyze
```

Cada push a `main` redespliega el backend en Render automáticamente, así que `main` tiene que estar siempre en condiciones de desplegarse. Por eso la protección.
