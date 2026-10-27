# Backend de recordatorios (Supabase)

Código: `supabase/migrations/20261027_reminders.sql` y `supabase/functions/`. El servidor nunca guarda pesos ni alimentos.

## Acceso

Sin login. Cada dispositivo genera un `device_token` aleatorio de 64 hex y lo envía en la cabecera `x-reminder-device`. Las funciones usan la service role y comprueban la cabecera; las tablas tienen RLS sin políticas. Desplegar con `--no-verify-jwt` (el webhook de Telegram y el cron no llevan JWT de usuario):

```sh
supabase functions deploy reminders-sync reminders-test email-verify reminders-tick telegram-webhook --no-verify-jwt
```

Todas las llamadas son `POST` a `https://<project>.supabase.co/functions/v1/<nombre>` con `Content-Type: application/json` y `x-reminder-device`. Errores: `{"error": "<codigo>"}` con 400/401/429/502.

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

`{ "title": "OpenNutriTracker", "body": "...", "url": "..." }`. El service worker abre `url`:

| Tipo | `body` | `url` |
| --- | --- | --- |
| weigh_in | Pésate en ayunas antes de beber nada | `/#/weightHistory` |
| meal | Registra tu desayuno/almuerzo/merienda/cena | `/#/addMeal?meal=<breakfast\|lunch\|snack\|dinner>` |
| custom | la etiqueta | `/` |

Push falla con 404/410: se borra la suscripción y se usa email (si verificado) o Telegram (si vinculado).

## Secretos en Vault

Ejecutar en el SQL editor (sustituir los marcadores; nunca subir claves reales al repo). Generar VAPID con `npx web-push generate-vapid-keys`.

```sql
select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
select vault.create_secret('<VAPID_PUBLIC_KEY>', 'vapid_public_key');
select vault.create_secret('<VAPID_PRIVATE_KEY>', 'vapid_private_key');
select vault.create_secret('mailto:<tu-email>', 'vapid_subject');
select vault.create_secret('<RESEND_API_KEY>', 'resend_api_key');
select vault.create_secret('OpenNutriTracker <recordatorios@<tu-dominio>>', 'resend_from');
select vault.create_secret('<TELEGRAM_BOT_TOKEN>', 'telegram_bot_token');
select vault.create_secret('<BOT_USERNAME_SIN_ARROBA>', 'telegram_bot_username');
select vault.create_secret('<SECRETO_ALEATORIO_LARGO>', 'telegram_webhook_secret');
```

`service_role_key` debe ser la misma clave que usa el entorno de las funciones (`SUPABASE_SERVICE_ROLE_KEY`), porque `reminders-tick` compara el `Authorization` con ella.

## Webhook de Telegram

```sh
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://<project-ref>.supabase.co/functions/v1/telegram-webhook" \
  -d "secret_token=<SECRETO_ALEATORIO_LARGO>"
```

El secreto debe coincidir con el de Vault `telegram_webhook_secret`. Flujo: el cliente llama a `reminders-sync` con `{"telegramLink":true}`, abre `telegramLink.url`, el usuario pulsa Iniciar y el bot responde "Recordatorios vinculados"; después `channels.telegram` pasa a `true`.

## Cron

La migración programa `reminders-tick` cada minuto con `pg_cron` (`public.reminders_cron()`, que también borra `meal_flags` de más de 3 días). Si faltan los secretos `project_url` o `service_role_key`, no hace nada.
