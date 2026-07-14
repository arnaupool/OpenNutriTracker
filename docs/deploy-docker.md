# Desplegar la versión web en tu servidor con Docker

Guía paso a paso para levantar OpenNutriTracker web en tu propio servidor
usando Docker Compose, con HTTPS automático. Corresponde a la tarea **FW-07**
del tablero Kanvas.

> ¿Despliegas en **Portainer sobre Unraid** y ya tienes un reverse proxy
> corriendo (Nginx Proxy Manager, SWAG...)? Ve directa a
> [Variante: Portainer en Unraid con un reverse proxy ya existente](#variante-portainer-en-unraid-con-un-reverse-proxy-ya-existente)
> — el recorrido de abajo asume que Caddy es tu único proxy.

## Qué vamos a montar

Dos contenedores:

- **`app`** — imagen construida a partir de este repo: compila la app Flutter
  a estáticos (`flutter build web --release`) y los sirve con nginx.
- **`caddy`** — proxy inverso que expone los puertos 80/443 al exterior,
  obtiene y renueva un certificado TLS (Let's Encrypt) automáticamente para
  tu dominio, y reenvía el tráfico a `app`.

```
Internet ──HTTPS──▶ Caddy (80/443) ──HTTP interno──▶ app (nginx, puerto 80)
                        │
                        └─ certificado Let's Encrypt (automático)
```

`app` no expone ningún puerto al host directamente — solo es alcanzable a
través de Caddy, dentro de la red interna que crea Docker Compose.

## Por qué hace falta un dominio real (no vale una IP)

HTTPS es **obligatorio**, no opcional, para dos cosas que ya dependen de él en
este proyecto:

- La cámara (`getUserMedia`, usada por el escáner de códigos de barras) — los
  navegadores solo dan acceso a la cámara en un "contexto seguro" (HTTPS o
  `localhost`).
- Instalar la PWA a pantalla de inicio en iPhone (ver FW-06) — y por tanto
  evitar que Safari borre los datos tras ~7 días sin abrir la app.

Let's Encrypt no emite certificados para una IP pelada — necesita un dominio
que resuelva a la IP pública de tu servidor. Si no tienes uno, un
subdominio gratuito (p. ej. DuckDNS, No-IP) apuntando a tu IP sirve
perfectamente para esto.

## Prerrequisitos

1. **Docker y Docker Compose** instalados en el servidor (`docker compose
   version` debería funcionar; si tu servidor es más antiguo puede que
   necesites `docker-compose` con guion, la sintaxis de los comandos de más
   abajo cambia igual).
2. **Un dominio** apuntando a la IP pública del servidor — un registro DNS
   tipo `A` (o `AAAA` si es IPv6). Confírmalo con:
   ```bash
   dig +short tu-dominio.com
   ```
   Debería devolver la IP de tu servidor.
3. **Puertos 80 y 443 abiertos** hacia el servidor — en el firewall del
   propio servidor y, si está detrás de un router doméstico, con
   port-forwarding hacia la máquina que corre Docker. Caddy necesita el 80
   para el reto HTTP de Let's Encrypt además del 443 para servir HTTPS.
4. Los 4 valores reales de tu `.env` (Supabase, Sentry, FDC) — los mismos
   que usas en local. Si nunca los has rellenado, copia `.env.example` y
   sustituye los placeholders.

## Paso 1 — Clonar el repo en el servidor

```bash
git clone <tu-fork> opennutritracker
cd opennutritracker
```

Si ya lo tenías clonado, simplemente `git pull` para traer los ficheros de
Docker (`Dockerfile`, `docker-compose.yml`, `Caddyfile`, `.dockerignore`)
añadidos en FW-07.

## Paso 2 — Crear el `.env` con secretos reales

En la raíz del repo, en el servidor (este fichero está en `.gitignore`, no
llega por `git pull`):

```bash
cp .env.example .env
nano .env   # o el editor que prefieras
```

Rellena los 4 valores reales. Recuerda (ver FW-05): al ser una app web, estos
valores quedan embebidos en el JavaScript compilado y son técnicamente
visibles para cualquiera que inspeccione el bundle — es aceptable para la
`SUPABASE_PROJECT_ANON_KEY` (pensada para exponerse, protegida por Row Level
Security del lado del servidor) y para `SENTRY_DNS`/`FDC_API_KEY`, que no dan
acceso a nada sensible.

## Paso 3 — Apuntar el Caddyfile a tu dominio

Edita `Caddyfile` en la raíz del repo:

```caddyfile
tu-dominio-real.com {
    reverse_proxy app:80
}
```

Sustituye `your-domain.example.com` por tu dominio real. Es la única línea
que hace falta tocar — Caddy se encarga de todo lo demás (obtener el
certificado, renovarlo cada ~60 días, redirigir HTTP→HTTPS).

## Paso 4 — Build y arranque

```bash
docker compose up -d --build
```

La primera vez tarda varios minutos (descarga la imagen de Flutter, ~2-3GB,
y compila la app). Puedes seguir el progreso con:

```bash
docker compose logs -f app
```

Cuando `app` termine, Caddy debería obtener el certificado automáticamente en
los primeros segundos. Comprueba sus logs si algo no cuadra:

```bash
docker compose logs -f caddy
```

## Paso 5 — Verificar

```bash
curl -I https://tu-dominio-real.com
```

Debería devolver `HTTP/2 200`. Abre la URL en un navegador — deberías ver la
app cargar igual que en `localhost:8080` durante el desarrollo. Comprueba
también desde el móvil (datos móviles, no la wifi del servidor, para
confirmar que es de verdad accesible desde fuera).

## Actualizar tras cambios de código

```bash
git pull
docker compose up -d --build
```

Docker reconstruye solo las capas que cambiaron — si solo tocaste `lib/`,
`flutter pub get` no se vuelve a ejecutar gracias al orden de los `COPY` en
el `Dockerfile` (los manifiestos de dependencias van primero).

## Variante: Portainer en Unraid con un reverse proxy ya existente

Tutorial completo desde cero — asume que no tienes Docker ni Portainer
tocados todavía. Si ya tienes alguno de los primeros pasos hecho, sáltatelo.

Si tu Unraid ya tiene un reverse proxy corriendo (Nginx Proxy Manager, SWAG,
Traefik...) — muy habitual, y encima suele ocupar ya el puerto 80/443 del
host junto con la propia GUI de Unraid — **no despliegues el `caddy` del
`docker-compose.yml` de este repo**: competiría por esos puertos. En su lugar,
el contenedor `app` se expone en un puerto interno cualquiera y le dices a tu
proxy existente que apunte ahí; el HTTPS lo sigue gestionando él.

Construimos la imagen a mano por SSH/terminal en vez de dejar que Portainer
haga el build él solo desde el repositorio Git, por dos motivos: (1)
Portainer no tiene forma sencilla de meter un fichero `.env` con tus secretos
reales dentro del árbol que clona internamente antes de compilar, y (2) así
ves los errores de build directamente en la terminal en vez de tener que
interpretarlos desde el log de Portainer.

### 0. Habilitar Docker en Unraid

Unraid trae Docker integrado en el propio sistema operativo — no hay que
instalar nada aparte, solo confirmar que está encendido: **Settings → Docker**
→ el interruptor **"Enable Docker"** tiene que estar en **Yes**. Si lo acabas
de activar, dale a Apply y espera a que el servicio arranque (unos segundos).

### 1. Instalar el plugin Community Applications (si no lo tienes)

Es la "tienda de apps" de Unraid — la necesitas para instalar Portainer con
un par de clics en vez de a mano. Para comprobar si ya la tienes: mira si
existe una pestaña **"Apps"** en el menú superior de la WebUI de Unraid. Si
sí, salta al paso 2.

Si no la tienes: **Plugins → Install Plugin**, pega esta URL en el campo y
pulsa Install:

```
https://raw.githubusercontent.com/Squidly271/community.applications/master/plugins/community.applications.plg
```

Al terminar te aparecerá la pestaña "Apps" en el menú.

### 2. Instalar Portainer desde Community Applications

**Apps** → busca `Portainer` en el buscador → aparecerán varios resultados,
elige el que se llama **"Portainer-CE"** (Community Edition — es el oficial,
mantenido por el propio proyecto Portainer, no un fork de terceros) → botón
**Install**.

Te abre la plantilla de configuración del contenedor — los valores por
defecto sirven tal cual (WebUI en el puerto `9000`, datos persistentes en
`/mnt/user/appdata/portainer`). Baja del todo y pulsa **Apply**. Tarda medio
minuto en descargarse y arrancar.

### 3. Primer acceso a Portainer

Abre `http://<ip-de-tu-unraid>:9000` en el navegador. La primera vez te pide
crear un usuario administrador (usuario + contraseña) — dáselo, y en la
siguiente pantalla elige el entorno **"local"** (el Docker de tu propio
Unraid). Ya estás dentro.

### 4. Clonar el repo y preparar el `.env` por SSH/terminal de Unraid

Usa la terminal de Unraid (icono `>_` en la esquina superior derecha de la
WebUI) o SSH:

```bash
mkdir -p /mnt/user/appdata/opennutritracker-web
cd /mnt/user/appdata/opennutritracker-web
git clone <tu-fork> .
cp .env.example .env
nano .env   # rellena los 4 valores reales, igual que en el Paso 2 de arriba
```

`/mnt/user/appdata/` es la ubicación habitual en Unraid para los datos
persistentes de contenedores — así el árbol clonado sobrevive a reinicios del
array.

### 5. Construir la imagen

```bash
docker build -t opennutritracker-web:latest .
```

Tarda varios minutos la primera vez (descarga la imagen base de Flutter,
~2-3GB, y compila la app). Si falla, el mensaje de error sale directamente en
la terminal — normalmente es el `.env` incompleto (ver Solución de problemas
más abajo).

Esta imagen es 100% tuya: la construyó Docker en tu propio servidor, a partir
del `Dockerfile` de tu fork de GitHub — no viene de ningún registro público
ni "oficial". El nombre `opennutritracker-web:latest` no lleva prefijo de
registro (no es `docker.io/algo` ni `ghcr.io/algo`), así que Docker la trata
como una imagen puramente local: en el paso 6 la va a usar tal cual, sin ir a
buscarla a ningún sitio. Si quieres comprobarlo tú mismo:

```bash
docker image inspect opennutritracker-web:latest --format '{{.Created}}'
```

te da la fecha/hora exacta en la que la construiste — y `docker history
opennutritracker-web:latest` te enseña las capas reales del build (`flutter
pub get`, `flutter build web --release`...), no algo genérico.

### 6. Crear el stack en Portainer

- Menú lateral izquierdo → **Stacks**.
- Botón **"+ Add stack"** (arriba a la derecha).
- Campo **Name**: `opennutritracker`.
- Debajo hay varias pestañas de método de creación — deja marcada **"Web
  editor"** (la que sale por defecto).
- En el cuadro de texto grande, pega:

```yaml
services:
  app:
    image: opennutritracker-web:latest
    restart: unless-stopped
    ports:
      - "8090:80"
```

El `8090` es arbitrario — cualquier puerto libre del host vale, solo tiene
que coincidir con lo que configures en tu proxy en el paso 8. Como la imagen
ya está construida localmente (paso 5), Portainer no necesita acceso al
Dockerfile ni al repo para este stack — solo referencia la imagen por
nombre.

- Baja del todo y pulsa el botón azul **"Deploy the stack"**. Tarda pocos
  segundos (no construye nada, solo arranca un contenedor).

### 7. Comprobar que arrancó

Te lleva de vuelta a la lista de Stacks — el tuyo debería tener un punto
verde. Entra en su nombre y verás el contenedor `app` listado, también en
verde ("running"). Si está en rojo/parado: clic en el nombre del contenedor →
pestaña **"Logs"**. Lo más típico es que la imagen no exista todavía porque
el `docker build` del paso 5 falló o no llegó a ejecutarse — confírmalo con
`docker images | grep opennutritracker` en la terminal.

### 8. Apuntar tu proxy existente a `<ip-de-unraid>:8090`

Da igual cuál uses — la idea es siempre la misma: un "proxy host" / entrada
nueva en tu proxy con tu dominio como origen y `<ip-de-unraid>:8090` como
destino, con su opción de "Force SSL" / Let's Encrypt activada (la gestiona
tu proxy, no este stack). Consulta la documentación de tu proxy concreto para
el paso exacto — en Nginx Proxy Manager es "Proxy Hosts → Add Proxy Host".

### 9. Verificar

Igual que el Paso 5 de arriba: `curl -I https://tu-dominio-real.com` debería
devolver `200`, y la app debería cargar en el navegador y desde el móvil por
datos.

### Actualizar tras cambios de código (variante Portainer)

```bash
cd /mnt/user/appdata/opennutritracker-web
git pull
docker build -t opennutritracker-web:latest .
```

Docker no recrea el contenedor solo porque haya una imagen `latest` nueva.
En Portainer: **Containers** → busca el contenedor `app` de este stack
(nombre tipo `opennutritracker-app-1`) → ábrelo → botón **"Recreate"** arriba
→ en el diálogo, **desmarca "Pull latest image"** (importante — marcado
intentaría descargar de un registro que no existe, en vez de usar la imagen
local que acabas de construir) → confirmar.

Para llevar la cuenta de qué commit está corriendo en cada momento, puedes
etiquetar también con el hash corto de git al construir:

```bash
docker build -t opennutritracker-web:latest -t "opennutritracker-web:$(git rev-parse --short HEAD)" .
```

## Solución de problemas

**Caddy no consigue el certificado / `docker compose logs caddy` muestra
errores de ACME.**
Casi siempre es DNS o el puerto 80 sin abrir — Let's Encrypt necesita
alcanzar `http://tu-dominio/.well-known/acme-challenge/...` desde fuera
antes de emitir el certificado HTTPS. Verifica:
```bash
curl -I http://tu-dominio-real.com
```
Si esto no responde desde fuera de tu red, el problema es DNS o firewall/
port-forwarding, no Caddy.

**`docker compose build` (o `docker build` en la variante Portainer) falla en
el paso de `dart run build_runner build` con errores de `envied`.**
El `.env` no existe o le faltan claves — repasa el Paso 2 (o el paso 4 de la
variante Portainer). `envied` necesita las 4 claves presentes (aunque sean
placeholders) para generar el código; solo fallará si el fichero no existe en
absoluto o le falta alguna clave.

**(Variante Portainer) Recreo el contenedor pero sigue sirviendo la versión
vieja de la app.**
Casi seguro que "Pull latest image" estaba marcado al recrear — con eso
activado, Portainer intenta *descargar* `opennutritracker-web:latest` de un
registro remoto (que no existe, es una imagen solo local) en vez de usar la
que acabas de construir con `docker build`. Desmárcalo y vuelve a recrear.

**(Variante Portainer) El puerto que elegí (8090 u otro) ya está en uso.**
```bash
docker ps --format '{{.Names}}\t{{.Ports}}'
```
para ver qué contenedores ya publican qué puertos en el host, y elige uno
libre — no hay nada especial en el 8090, es solo un ejemplo.

**La app carga pero las búsquedas de productos no funcionan.**
Antes de asumir que es cosa del despliegue, mira la consola del navegador
(F12 → Console) y la pestaña Network — la causa más probable a estas alturas
(FW-05 ya cerrada) sería un problema puntual de Open Food Facts/Supabase, no
del despliegue en sí.

**Quiero ver los logs de nginx dentro del contenedor `app`.**
```bash
docker compose logs -f app
```
Al ser solo estáticos servidos por nginx, no debería haber mucho que ver
salvo accesos.

## Notas de seguridad

- El `.env` con tus secretos reales vive solo en el servidor — nunca se
  commitea (está en `.gitignore`) ni queda en la imagen final (el
  `Dockerfile` es multi-stage: la imagen que de verdad corre en producción
  solo contiene los estáticos compilados, no el código fuente ni el `.env`).
- Los certificados de Caddy se guardan en un volumen Docker con nombre
  (`caddy_data`) — sobreviven a un `docker compose down`/`up`, pero se
  perderían con `docker compose down -v`. No hace falta backup: se
  regeneran solos contra Let's Encrypt si se pierden.
