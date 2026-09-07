# Desplegar el backend

Guía para poner la API en internet, de modo que la app funcione desde cualquier lugar sin depender de que una computadora del equipo esté encendida.

**Base de datos:** PostgreSQL en [Neon](https://neon.tech) — capa gratuita sin vencimiento.
**Backend:** [Render](https://render.com) — capa gratuita.

Ninguno de los dos pide tarjeta.

## Antes de empezar

Hace falta el repositorio en GitHub. Render despliega desde un repositorio Git, no desde archivos sueltos.

```bash
git remote add origin https://github.com/USUARIO/app-finanza.git
git push -u origin main
```

## 1. Crear la base de datos en Neon

1. Entrar a [neon.tech](https://neon.tech) y crear una cuenta.
2. Crear un proyecto. Elegir la región más cercana (`AWS us-east-1` anda bien desde Paraguay).
3. Copiar la cadena de conexión que muestra al terminar. Se ve así:

   ```
   postgresql://usuario:contraseña@ep-algo-123456.us-east-1.aws.neon.tech/neondb?sslmode=require
   ```

4. **Cambiar el principio** de `postgresql://` a `postgresql+psycopg://`. Sin eso SQLAlchemy no sabe qué driver usar y falla al arrancar. Queda:

   ```
   postgresql+psycopg://usuario:contraseña@ep-algo-123456.us-east-1.aws.neon.tech/neondb?sslmode=require
   ```

Guardar esa cadena, se usa en el paso siguiente.

## 2. Desplegar el backend en Render

Entrar a [render.com](https://render.com) y crear una cuenta con GitHub. Después **New +** → **Web Service**.

> El repositorio incluye un [`render.yaml`](../render.yaml) para desplegar por Blueprint, pero esa opción no está en el menú "New +": Render la ubica en una sección **Blueprints** aparte. Creando el servicio a mano queda igual; la diferencia es que la configuración vive en el panel en vez del archivo.
>
> **Si el servicio ya está creado a mano, no apliques el Blueprint después.** Render lo trataría como algo nuevo y levantaría un segundo servicio en paralelo, con su propia dirección, apuntando a la misma base.

Configuración del servicio:

| Campo | Valor |
|---|---|
| Source | el repositorio del proyecto |
| Name | `finanzas-api` |
| Language / Runtime | **Docker** |
| Branch | `main` |
| **Root Directory** | `backend` |
| Instance Type | Free |
| Health Check Path | `/health` |

**El `Root Directory` en `backend` es el campo que más se olvida.** Sin eso Render busca el `Dockerfile` en la raíz del repositorio y el build falla.

Si el repositorio es privado y no aparece en la lista, hay que darle acceso desde GitHub: en el enlace de configuración de la cuenta, elegir "Only select repositories" y marcarlo.

Después, en **Environment Variables**, cargar las tres:

| Clave | Valor |
|---|---|
| `ENTORNO` | `produccion` |
| `DATABASE_URL` | la cadena de Neon del paso anterior, ya modificada |
| `SECRET_KEY` | una clave propia: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` |

**`ENTORNO` es fácil de pasar por alto y no da ningún error visible.** Si falta, el servidor arranca igual pero en modo local: `/docs` y `/openapi.json` quedan publicados para cualquiera. Se comprueba con `curl .../health`, que tiene que responder `"entorno":"produccion"`.

Dejar **Auto-Deploy** en `On Commit`: cada push a `main` vuelve a desplegar solo. Por eso conviene que a `main` solo llegue lo revisado por pull request.

El primer despliegue tarda unos minutos: compila la imagen de Docker y aplica las migraciones.

Al terminar queda una dirección tipo `https://finanzas-api.onrender.com`. Para comprobar que anda:

```bash
curl https://finanzas-api.onrender.com/health
```

Debe responder `{"status":"ok","entorno":"produccion"}`.

## 3. Generar el APK apuntando al servidor

```bash
./scripts/apk-para-el-equipo.sh https://finanzas-api.onrender.com
```

Como la dirección es HTTPS, el script compila en modo release. Queda en `build-equipo/` junto con el instructivo.

**Este APK ya no depende de la red de nadie.** Funciona con datos móviles, desde la facultad o desde la casa.

## Qué esperar de la capa gratuita

- **El servicio se duerme** tras un rato sin uso. El primer pedido después tarda entre 30 y 60 segundos en responder mientras se despierta. Si van a mostrar la app en la defensa, conviene abrirla unos minutos antes.
- Neon también suspende la base por inactividad, pero se despierta en segundos.
- Render reconstruye y vuelve a desplegar en cada push a `main`.

## Qué se endureció para publicarlo

Estas cosas no hacían falta con el backend en la red local y sí al exponerlo a internet:

| Qué | Por qué |
|---|---|
| El arranque falla si `SECRET_KEY` sigue siendo la de ejemplo | Es la clave con la que se firman los tokens. Si quedara la del repositorio, cualquiera podría fabricarse una sesión de cualquier usuario. |
| Límite de 10 intentos de login por IP cada 15 minutos | Sin eso se pueden probar contraseñas indefinidamente. |
| `/docs` y `/openapi.json` ocultos en producción | Le dan a cualquiera el mapa completo de la API. En desarrollo siguen disponibles. |
| El APK de release exige HTTPS | Los datos financieros y el token no viajan en claro. En desarrollo se sigue permitiendo HTTP contra `localhost`. |
| El contenedor no corre como `root` | Reduce el daño si alguien lograra ejecutar algo dentro. |

## Limitaciones conocidas

- **El límite de intentos vive en la memoria del proceso.** Se reinicia cuando se reinicia el servidor, y si algún día se levantan varias instancias cada una llevaría su propia cuenta. La versión robusta usaría Redis. Para una sola instancia, alcanza.
- **No hay copias de seguridad automáticas.** Neon guarda un historial corto en su capa gratuita. Antes de la entrega final conviene exportar la base a mano.
- **No hay recuperación de contraseña por correo.** El caso de uso está en el diagrama pero requiere un servicio de envío de correos.

## Probar la imagen en tu máquina antes de desplegar

Sirve para no descubrir un error recién en el servidor:

```bash
docker build -t finanzas-api ./backend
docker run --rm --network app-finanza_default \
  -e ENTORNO=produccion \
  -e SECRET_KEY="$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')" \
  -e DATABASE_URL="postgresql+psycopg://finanzas:finanzas@db:5432/finanzas" \
  -e PORT=8000 -p 8100:8000 finanzas-api
```

Y en otra terminal: `curl http://localhost:8100/health`
