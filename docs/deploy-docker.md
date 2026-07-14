# Desplegar la versión web en Unraid (Portainer + Nginx Proxy Manager)

Portainer clona tu fork directamente de GitHub y construye la imagen él
solo — no hace falta SSH ni `docker build` a mano. Para actualizar tras un
cambio de código, un botón en Portainer ("Pull and redeploy").

## Prerrequisitos

- Un dominio apuntando a tu IP pública (Let's Encrypt no emite certificado
  para una IP pelada).
- Los 4 valores reales de tu `.env` (Supabase, Sentry, FDC) a mano.
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
  `SUPABASE_PROJECT_URL`, `SUPABASE_PROJECT_ANON_KEY`, `FDC_API_KEY`,
  `SENTRY_DNS`.
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

## Actualizar tras cambios de código

Stacks → `opennutritracker` → botón **"Pull and redeploy"** (o "Update the
stack" según la versión de Portainer). Vuelve a clonar `main` y reconstruye
— nada de SSH.

## Problemas típicos

- **Portainer no puede clonar el repo** → revisa el Personal Access Token
  (caducado, o sin scope `repo`) y que "Authentication" esté activado.
- **Build falla en `dart run build_runner build` / errores de `envied`** →
  falta alguna de las 4 "Environment variables" en el stack, o tiene un
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
  docker system prune -a
  ```
  (borra imágenes y caché de build sin usar; no toca contenedores en
  marcha). Si el build sigue sin caber, sube el tamaño del docker vDisk en
  Settings → Docker.
