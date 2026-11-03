# Backend de recordatorios (Supabase)

Código: `supabase/migrations/20261027_reminders.sql` y `supabase/functions/`. El servidor nunca guarda pesos ni alimentos.

## Acceso

Sin login. Cada dispositivo genera un `device_token` aleatorio de 64 hex y lo envía en la cabecera `x-reminder-device`. Las funciones usan la service role y comprueban la cabecera; las tablas tienen RLS sin políticas. Desplegar con `--no-verify-jwt` (el webhook de Telegram y el cron no llevan JWT de usuario):

```sh
supabase functions deploy reminders-sync reminders-test email-verify reminders-tick telegram-webhook --no-verify-jwt
```

Todas las llamadas son `POST` a `https://<project>.supabase.co/functions/v1/<nombre>` con `Content-Type: application/json` y `x-reminder-device`. Errores: `{"error": "<codigo>"}` con 400/401/429/502.

## Modo cuenta (migración `20261103_reminders_accounts.sql`)

Las mismas funciones aceptan `Authorization: Bearer <JWT de usuario de Supabase Auth>`. Sin ese JWT (o con la clave anon como bearer) el comportamiento es el de dispositivo, descrito en el resto del documento, sin cambios.

- El servidor valida el JWT con `auth.getUser(jwt)` de la service role; nunca se fía de un `sub` sin verificar. JWT caducado o inválido: 401 `{"error":"invalid_jwt"}` (no cae a modo dispositivo).
- Con JWT, todo se guarda por `user_id`: un único juego de recordatorios, `meal_flags`, zona horaria, No molestar, Telegram y email verificado por cuenta (tabla `reminder_accounts`). `email_codes` también va por cuenta.
- `x-reminder-device` es opcional en modo cuenta. Si se envía, ese dispositivo queda ligado a la cuenta (`reminder_devices.user_id`) y es el dueño de `pushSubscription` (la suscripción push es siempre por dispositivo; sin cabecera, `pushSubscription` devuelve 400 `device_required`). `channels.push` indica si ese dispositivo tiene suscripción (sin cabecera: si la tiene alguno de la cuenta).
- `reminders-tick` envía cada recordatorio de cuenta una sola vez por email o Telegram, y por push a todos los dispositivos suscritos de la cuenta. Si ninguno recibe el push, cae a email (si verificado) o Telegram. Tras 3 fallos seguidos de un dispositivo, y con email verificado, los recordatorios push de la cuenta pasan a email.
- Telegram: `{"telegramLink":true}` con JWT genera un código aleatorio de un solo uso asociado a la cuenta; `telegram-webhook` lo resuelve primero contra cuentas y luego contra dispositivos.
- Cerrar sesión: el cliente llama sin JWT (solo con `x-reminder-device`) a `reminders-sync` con `{"detachAccount":true}`; el dispositivo deja de pertenecer a la cuenta y pierde su suscripción push. Los recordatorios del modo local (clave `device_token`) no se tocan.
- Los datos de dispositivo y de cuenta son independientes: una cuenta nueva empieza sin recordatorios y el cliente los sube con `reminders`.

### `account-delete`

`POST` con `Authorization: Bearer <JWT>` (sin cuerpo). Borra `account_records`, `account_keys`, `reminder_accounts` (en cascada recordatorios, flags y códigos), quita la suscripción push y el `user_id` de los dispositivos de la cuenta y, por último, el usuario de Auth. Solo actúa sobre quien llama. 200 `{"ok":true}`; 401 `{"error":"unauthorized"}` sin JWT de usuario válido.

Desplegar también `account-delete` con `--no-verify-jwt`.

## `reminders-sync`

Cuerpo (todas las claves son opcionales; solo se cambia lo presente):

```json
{
  "timezone": "Europe/Madrid",
  "quietStart": "23:00", "quietEnd": "07:00",
  "pushSubscription": { "endpoint": "https://...", "keys": { "p256dh": "...", "auth": "..." } },
  "reminders": [
    { "id": "r1", "type": "weigh_in|meal|custom", "mealType": "breakfast|lunch|snack|dinner",
      "label": "max 40", "time": "08:30", "days": [1,2,3,4,5,6,7],
      "channel": "push|email|telegram", "enabled": true, "skipIfLogged": true }
  ],
  "mealLogged": { "date": "2026-10-27", "mealType": "lunch" },
  "telegramLink": true
}
```

- `reminders`: reemplazo completo (máx. 30). `mealType` obligatorio solo si `type` es `meal`. `days`: 1 = lunes .. 7 = domingo. Hora local del dispositivo, `HH:MM`.
- `quietStart`/`quietEnd`: `null` los desactiva; el rango puede cruzar la medianoche.
- `pushSubscription`: `null` la elimina. Omitida, se conserva.
- `mealLogged.date`: fecha local del dispositivo.

Respuesta 200:

```json
{
  "vapidPublicKey": "...",
  "channels": { "push": true, "email": false, "telegram": false },
  "emailAddress": null,
  "reminders": [ { "id": "r1", "channel": "push" } ],
  "telegramLink": { "code": "ab12...", "url": "https://t.me/<bot>?start=<code>" }
}
```

`reminders` devuelve el canal vigente: el servidor cambia push a email tras 3 fallos seguidos, así que el cliente debe adoptar ese canal. `telegramLink` solo aparece si se pidió.

## `reminders-test`

`{"reminderId": "r1"}` envía ya ese recordatorio (ignora hora y No molestar). 200 `{"ok":true,"channel":"push"}`; 502 `{"ok":false,"error":"..."}`; 404 si no existe.

## `email-verify`

- `{"action":"request","email":"a@b.com"}`: envía un código de 6 cifras (caduca en 10 min; 1 por minuto). 200 `{"ok":true}`.
- `{"action":"confirm","code":"123456"}`: máx. 5 intentos. 200 `{"ok":true,"email":"a@b.com"}`; errores `wrong_code`, `expired`, `too_many_attempts`.

## Payload de la notificación

`{ "title": "OpenNutriTracker", "body": "...", "url": "..." }`. El service worker (`web/push_sw.js`) abre `url`; la app lee `open` al arrancar y navega a la pantalla:

| Tipo | `body` | `url` |
| --- | --- | --- |
| weigh_in | Pésate en ayunas antes de beber nada | `/?open=weigh_in` |
| meal | Registra tu desayuno/almuerzo/merienda/cena | `/?open=meal&meal=<breakfast\|lunch\|snack\|dinner>` |
| custom | la etiqueta | `/` |

Push falla con 404/410: se borra la suscripción y se usa email (si verificado) o Telegram (si vinculado).

## Secretos en Vault

Ejecutar en el SQL editor (sustituir los marcadores; nunca subir claves reales al repo). Generar VAPID con `npx web-push generate-vapid-keys`.

```sql
select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
select vault.create_secret('<RANDOM_LONG_SECRET>', 'cron_secret');
select vault.create_secret('<VAPID_PUBLIC_KEY>', 'vapid_public_key');
select vault.create_secret('<VAPID_PRIVATE_KEY>', 'vapid_private_key');
select vault.create_secret('mailto:<tu-email>', 'vapid_subject');
select vault.create_secret('<RESEND_API_KEY>', 'resend_api_key');
select vault.create_secret('OpenNutriTracker <recordatorios@<tu-dominio>>', 'resend_from');
select vault.create_secret('<TELEGRAM_BOT_TOKEN>', 'telegram_bot_token');
select vault.create_secret('<BOT_USERNAME_SIN_ARROBA>', 'telegram_bot_username');
select vault.create_secret('<SECRETO_ALEATORIO_LARGO>', 'telegram_webhook_secret');
```

`cron_secret` es un secreto aleatorio cualquiera: `reminders_cron()` lo envía en la cabecera `x-cron-secret` y `reminders-tick` lo compara con el de Vault.

## Webhook de Telegram

```sh
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://<project-ref>.supabase.co/functions/v1/telegram-webhook" \
  -d "secret_token=<SECRETO_ALEATORIO_LARGO>"
```

El secreto debe coincidir con el de Vault `telegram_webhook_secret`. Flujo: el cliente llama a `reminders-sync` con `{"telegramLink":true}`, abre `telegramLink.url`, el usuario pulsa Iniciar y el bot responde "Recordatorios vinculados"; después `channels.telegram` pasa a `true`.

## Cron

La migración programa `reminders-tick` cada minuto con `pg_cron` (`public.reminders_cron()`, que también borra `meal_flags` de más de 3 días). Si faltan los secretos `project_url` o `cron_secret`, no hace nada.
