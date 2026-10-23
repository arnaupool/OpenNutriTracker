# Desplegar la versión web en Unraid

## Opción rápida: imagen ya construida (recomendada)

GitHub construye la imagen en cada push a `main` (workflow
`docker-image.yml`) y la publica en
`ghcr.io/arnaupool/opennutritracker:latest`. Unraid solo la descarga: no
compila Flutter, no hace falta Portainer.

### Una sola vez: dejar que Unraid pueda descargarla

El repo es privado, así que el paquete de GHCR también lo es. Elige una:

- **Hacerla pública (lo más fácil):** GitHub > tu perfil > Packages >
  `opennutritracker` > Package settings > Change visibility > Public. La
  imagen solo lleva la web compilada y la clave pública (anon) de Supabase;
  ningún dato tuyo, que viaja cifrado. Si añades `FDC_API_KEY` como secret,
  también iría dentro (ofuscada).
- **Dejarla privada:** crea un token (GitHub > Settings > Developer settings
  > Personal access tokens > classic, scope `read:packages`) y en la
  terminal de Unraid ejecuta `docker login ghcr.io -u arnaupool` y pega el
  token. Ojo: Unraid no guarda ese login tras reiniciar, así que habría que
  repetirlo antes de actualizar.

### Instalar

1. Terminal de Unraid (icono `>_` arriba a la derecha), pega esto:

   ```sh
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-OpenNutriTracker.xml      https://raw.githubusercontent.com/arnaupool/OpenNutriTracker/main/unraid/opennutritracker.xml
   ```

   (Si el repo sigue privado, ese `curl` no puede leerlo: copia a mano el
   contenido de `unraid/opennutritracker.xml` a ese mismo fichero.)
2. Docker > **Add Container** > *Template*: elige **OpenNutriTracker** >
   **Apply**. Puertos por defecto: **8443** (HTTPS) y 8090 (HTTP para un
   proxy).
3. Abre **`https://IP-de-tu-unraid:8443`**. La primera vez el navegador
   avisa de que el certificado no es de confianza (es autofirmado):
   "Avanzado" > "Continuar". Después ya no vuelve a preguntar.
4. En la web: Ajustes > Sincronización entre dispositivos > **Vincular este
   dispositivo** y pega el código que te da el móvil.

**Por qué HTTPS:** la app cifra tus datos locales con la API de cifrado del
navegador, que solo existe en HTTPS (o `localhost`). Por
`http://IP:puerto` sale una página que te manda a la dirección HTTPS.

**Actualizar:** Docker > *Check for Updates* > *apply update*. El
certificado se guarda en `/mnt/user/appdata/opennutritracker/certs`, así que
el aviso no vuelve tras actualizar.

**Certificado de verdad (opcional):** pon Nginx Proxy Manager o
`tailscale serve` delante apuntando al puerto 8090, o deja tus
`cert.pem` y `key.pem` en esa carpeta `certs`.

## Opción alternativa: construir en Unraid con Portainer + Nginx Proxy Manager

Portainer clona tu fork directamente de GitHub y construye la imagen él
solo — no hace falta SSH ni `docker build` a mano. Para actualizar tras un
cambio de código, un botón en Portainer ("Pull and redeploy").

## Prerrequisitos

- Un dominio apuntando a tu IP pública (Let's Encrypt no emite certificado
  para una IP pelada).
- Los 4 valores reales de tu `.env` a mano: la clave de USDA FDC
  (búsqueda de alimentos genéricos), Sentry, y Supabase del backup en la
  nube (ver `docs/cloud-backup-setup.md`).
- Como tu fork es privado, un **Personal Access Token** de GitHub con
  permiso de lectura sobre el repo: GitHub → Settings → Developer settings →
  Personal access tokens → Generate new token (classic vale; scope `repo`
  basta).

## 1. Docker + Portainer en Unraid

- **Settings → Docker → Enable Docker: Yes** (viene integrado, no hay que
  instalar nada).
- Si no tienes pestaña **Apps**: Plugins → Install Plugin → pega:
  ```
  https://raw.githubusercontent.com/Squidly271/community.applications/master/plugins/community.applications.plg
  ```
- **Apps** → busca `Portainer` → instala **Portainer-CE** → Apply (valores
  por defecto: puerto `9000`).
- Entra en `http://<ip-unraid>:9000`, crea el usuario admin, elige entorno
  **local**.

## 2. Stack en Portainer, apuntando a GitHub

Stacks → Add stack → nombre `opennutritracker`:

- Pestaña **Repository** (no Web editor).
- **Repository URL**: `https://github.com/arnaupool/OpenNutriTracker`
- **Repository reference**: `refs/heads/main`
- **Authentication**: actívalo → usuario de GitHub + el Personal Access
  Token del paso anterior (el repo es privado, sin esto Portainer no puede
  clonarlo).
- **Compose path**: `docker-compose.unraid.yml` (no el `docker-compose.yml`
  por defecto — ese lleva Caddy, que no necesitas con NPM).
- **Environment variables**: añade las 4 claves reales, una por una:
  `FDC_API_KEY`, `SENTRY_DNS`, `BACKUP_SUPABASE_PROJECT_URL`,
  `BACKUP_SUPABASE_PROJECT_ANON_KEY`.
- **Deploy the stack**.

La primera vez tarda varios minutos (Portainer descarga la imagen base de
Flutter, ~2-3GB, y compila la app) — sigue el progreso desde el propio log
de despliegue que muestra Portainer.

## 3. Nginx Proxy Manager

Proxy Hosts → Add Proxy Host:

- **Domain Names**: tu dominio.
- **Forward Hostname/IP**: IP de tu Unraid.
- **Forward Port**: `8090`.
- Pestaña **SSL**: Request a new SSL Certificate, activa **Force SSL** y
  acepta los términos de Let's Encrypt.

Save.

## 4. Verificar

```bash
curl -I https://tu-dominio-real.com
```

`200` esperado. Abre la URL en el navegador y desde el móvil por datos.

Para confirmar que lo que ves es realmente el build más reciente (y no una
copia en caché de Cloudflare/el navegador — ver el problema real que dio
esto más abajo): **Settings**, baja del todo, debajo del número de versión
sale la fecha/hora UTC en la que se construyó esa imagen. Si acabas de
darle a "Pull and redeploy" y sigue saliendo una hora de hace rato, no es
el build nuevo lo que estás viendo — toca purgar caché (Cloudflare y/o el
navegador/PWA).

## Actualizar tras cambios de código

Stacks → `opennutritracker` → botón **"Pull and redeploy"** (o "Update the
stack" según la versión de Portainer). Vuelve a clonar `main` y reconstruye
— nada de SSH.

## Problemas típicos

- **Portainer no puede clonar el repo** → revisa el Personal Access Token
  (caducado, o sin scope `repo`) y que "Authentication" esté activado.
- **Build falla en `dart run build_runner build` / errores de `envied`** →
  falta alguna de las 6 "Environment variables" en el stack, o tiene un
  valor vacío.
- **La app carga pero con datos raros / build viejo** → confirma que el
  "Compose path" es `docker-compose.unraid.yml`, no el genérico.
- **Puerto 8090 ocupado** → `docker ps --format '{{.Names}}\t{{.Ports}}'` en
  la terminal de Unraid y elige otro libre (edítalo también en el stack y en
  Nginx Proxy Manager).
- **"no space left on device" durante el build** → el `Dockerfile` ya no usa
  la imagen base `cirruslabs/flutter` (llevaba el SDK de Android entero
  metido, varios GB que un build web no toca para nada); ahora instala solo
  el SDK de Flutter a pelo. Si ya te quedaste sin espacio con un intento
  anterior, límpialo antes de reintentar — terminal de Unraid:
  ```bash
  docker builder prune -a -f
  docker image prune -a -f
  ```
  Ninguno de los dos toca contenedores, ni parados ni en marcha — solo
  caché de build e imágenes que ningún contenedor esté usando (ahí cae la
  imagen grande de Android si llegó a descargarse). **No uses `docker system
  prune`** para esto: ese sí borra todos los contenedores parados de tu
  Unraid, no solo lo relacionado con este build. Si el build sigue sin
  caber, sube el tamaño del docker vDisk en Settings → Docker.
