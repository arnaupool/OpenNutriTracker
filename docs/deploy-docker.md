# Desplegar la versión web en Unraid (Portainer + Nginx Proxy Manager)

## Prerrequisitos

- Un dominio apuntando a tu IP pública (Let's Encrypt no emite certificado
  para una IP pelada).
- Los 4 valores reales de tu `.env` (Supabase, Sentry, FDC) a mano.

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

## 2. Clonar y construir la imagen

Terminal de Unraid (icono `>_`) o SSH:

```bash
mkdir -p /mnt/user/appdata/opennutritracker-web
cd /mnt/user/appdata/opennutritracker-web
git clone <tu-fork> .
cp .env.example .env
nano .env   # rellena los 4 valores reales
docker build -t opennutritracker-web:latest .
```

Tarda varios minutos la primera vez. La imagen es local (nombre sin
prefijo de registro) — Docker no va a buscarla a ningún sitio.

## 3. Stack en Portainer

Stacks → Add stack → nombre `opennutritracker` → Web editor → pega:

```yaml
services:
  app:
    image: opennutritracker-web:latest
    restart: unless-stopped
    ports:
      - "8090:80"
```

Deploy the stack. (`8090` es libre de elegir — solo tiene que coincidir con
el paso 4.)

## 4. Nginx Proxy Manager

Proxy Hosts → Add Proxy Host:

- **Domain Names**: tu dominio.
- **Forward Hostname/IP**: IP de tu Unraid.
- **Forward Port**: `8090`.
- Pestaña **SSL**: Request a new SSL Certificate, activa **Force SSL** y
  acepta los términos de Let's Encrypt.

Save.

## 5. Verificar

```bash
curl -I https://tu-dominio-real.com
```

`200` esperado. Abre la URL en el navegador y desde el móvil por datos.

## Actualizar tras cambios de código

```bash
cd /mnt/user/appdata/opennutritracker-web
git pull
docker build -t opennutritracker-web:latest .
```

Portainer → Containers → contenedor `app` → **Recreate** → **desmarca "Pull
latest image"** (la imagen es local, no de un registro) → confirmar.

## Problemas típicos

- **Build falla en `dart run build_runner build` / errores de `envied`** →
  falta el `.env` o le faltan claves.
- **Recreate sigue sirviendo la versión vieja** → "Pull latest image" estaba
  marcado; desmárcalo.
- **Puerto 8090 ocupado** → `docker ps --format '{{.Names}}\t{{.Ports}}'` y
  elige otro libre.
