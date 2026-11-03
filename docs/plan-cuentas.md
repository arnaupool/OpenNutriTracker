# Plan: cuentas de usuario (2026-11-03)

Sustituye la sincronización por código QR y la copia en la nube por cuentas con email y contraseña. Decisiones del dueño tomadas en entrevista.

## Decisiones

1. **Cuenta = perfil.** Cada cuenta ocupa un perfil local (`ProfileScope`); en un dispositivo puede haber varias cuentas con sesión abierta y se cambia entre ellas sin volver a escribir la contraseña.
2. **Login con email y contraseña** (Supabase Auth). Nada de enlaces mágicos: en iOS un enlace del email abre Safari y no la PWA instalada.
3. **Registro abierto por defecto**, con un interruptor en un panel de administración para cerrarlo. Administrador: los emails de la lista `admin_emails` del servidor (de inicio, el del dueño).
4. **Cifrado de extremo a extremo.** Cada cuenta tiene una clave de datos aleatoria (la AES-256-GCM que ya usa el motor de sync). En el servidor se guarda envuelta con una clave derivada de la contraseña (PBKDF2-SHA256). Clave de recuperación opcional en Ajustes.
5. **Modo local permitido.** Un perfil sin cuenta funciona como hoy, sin sincronizar; puede crear o vincular una cuenta después.
6. **Migración: subir y fusionar.** Al crear la cuenta, los datos del perfil suben; al iniciar sesión en otro dispositivo, lo local se fusiona con la cuenta (gana el `modified_at` más reciente, como ahora).
7. **Se eliminan** la sincronización por código QR (`SyncPairing`, `DeviceSyncScreen`) y la copia en la nube (FA-09 a FA-16, bucket `backups`). Queda la exportación a .zip.
8. **Recordatorios por cuenta.** Telegram y email se vinculan una vez por cuenta; push sigue siendo por dispositivo. En modo local siguen por dispositivo.
9. **Emails de cuenta por Resend con dominio propio** configurado como SMTP de Supabase.
10. **Sesión sin caducidad** (refresh token renovado). Cerrar sesión quita la cuenta y sus datos del dispositivo tras comprobar que no queda nada pendiente de subir. Hay "Eliminar cuenta", que borra la cuenta y sus datos en la nube.

## Huecos detectados y cómo se cubren

| Hueco | Solución |
| --- | --- |
| Confirmación y recuperación por enlace abren Safari, no la PWA | Códigos de 6 dígitos por email (`verifyOtp` tipo `signup` y `recovery`) que se escriben en la app |
| Restablecer la contraseña deja la clave de datos envuelta con la contraseña vieja | Si queda un dispositivo con sesión, al abrirlo detecta la versión de envoltorio caducada, pide la contraseña nueva y vuelve a envolver. Si no queda ninguno: clave de recuperación; sin ella, la app avisa de que los datos de la nube no se pueden abrir y ofrece empezar de cero |
| Cambiar la contraseña desde la app | Se vuelve a envolver la clave en la misma operación, antes de llamar a `updateUser` |
| PBKDF2 en Dart puro es muy lento en web | Paquete `cryptography` (usa WebCrypto en web); 310.000 iteraciones, sal aleatoria por cuenta guardada junto al envoltorio |
| `supabase_flutter` es un singleton con una sola sesión | Un `GoTrueClient` por cuenta con su propio almacén de sesión en `flutter_secure_storage` con sufijo de perfil; `SyncRemote` sigue con HTTP propio, ahora con `Authorization: Bearer <jwt>` |
| Las filas de `sync_records` van por token (`x-sync-token`) | Columna `user_id uuid references auth.users`, RLS `user_id = auth.uid()`; las filas antiguas se borran desde el cliente tras migrar (el cliente conoce su token) |
| Supabase no permite abrir o cerrar el registro desde una app | Tabla `app_settings` (`signups_open`) y Auth Hook "before user created" que rechaza el alta si está cerrado; solo el admin puede escribir esa tabla (RLS con `admin_emails`) |
| Los recordatorios usan `device_id` | `reminders`, `meal_flags` y canales Telegram/email pasan a `user_id`; `reminder_devices` queda solo para suscripciones push, con `user_id`; las Edge Functions verifican el JWT |
| Eliminar cuenta necesita la service role | Edge Function `account-delete` que comprueba el JWT y borra filas y usuario |
| El proyecto gratuito de Supabase se pausa tras una semana sin actividad | Ya ocurrió una vez; el cron de recordatorios cada minuto lo mantiene activo, pero se documenta cómo reactivarlo |

## Tareas

### Fase A: servidor

1. Migración SQL: `user_id` en `sync_records`, RLS por `auth.uid()`; tabla `account_keys` (`user_id`, `wrapped_key`, `salt`, `iterations`, `version`, `recovery_wrapped_key` opcional); `app_settings` con `signups_open`; `admin_emails`; Auth Hook "before user created".
2. Recordatorios por cuenta: migrar tablas a `user_id`, adaptar `reminders-sync`, `reminders-tick`, `reminders-test`, `email-verify` y `telegram-webhook` a JWT.
3. Edge Function `account-delete`. Plantillas de email en español con `{{ .Token }}` y SMTP de Resend (cuando exista el dominio).

### Fase B: cliente, núcleo

4. `AccountKeyService`: generar clave de datos, envolver y desenvolver con PBKDF2 (`cryptography`), clave de recuperación, detectar envoltorio caducado. Tests unitarios.
5. `AccountSessionService`: un `GoTrueClient` por perfil, registro, login, códigos de verificación y recuperación, cambio de contraseña, cierre de sesión, sesión persistente. Tests con un cliente falso.
6. Motor de sync: sustituir token y `SyncPairing` por JWT y clave de la cuenta; borrar las filas antiguas del token tras la primera subida. Tests del motor existentes adaptados.

### Fase C: cliente, pantallas

7. Pantallas de cuenta: entrar, crear cuenta, código de verificación, olvidé la contraseña, nueva contraseña.
8. Selector de cuentas (sustituye al de perfiles): lista de cuentas y perfiles locales, añadir cuenta, cambiar, cerrar sesión con comprobación de pendientes, eliminar cuenta, clave de recuperación.
9. Panel de administración (solo admins): interruptor de registro abierto.
10. Recordatorios: la pantalla lee el estado de Telegram y email de la cuenta, no del dispositivo.

### Fase D: limpieza

11. Eliminar `SyncPairing`, `DeviceSyncScreen`, la copia en la nube (casos de uso, pantalla de vinculación, `CloudBackupTokenService`), sus cadenas y docs; borrar el bucket `backups` y las filas de token antiguas que queden.
12. Docs (`docs/cuentas.md`, `deploy-docker.md`), prueba de extremo a extremo en web: crear cuenta, segundo dispositivo, cambiar contraseña, recuperar contraseña, cerrar sesión, eliminar cuenta.

Orden: A1 → (A2, A3, B4) → B5 → B6 → (C7, C8, C9, C10) → D11 → D12.

## Pendiente del dueño

- Dominio para Resend y sus 3 registros DNS (sin él, los códigos solo llegan al email de la cuenta de Resend).
- Confirmar el email de administrador.
- Plantillas y SMTP en el panel de Supabase (no se pueden desplegar desde el repo). Qué pegar:
  - Authentication > Email Templates > "Confirm signup": asunto y cuerpo en español que muestren solo `{{ .Token }}` (código de 6 dígitos), sin enlaces ni `{{ .ConfirmationURL }}`. Ejemplo de cuerpo: "Tu código para crear la cuenta es {{ .Token }}. Caduca en una hora. Si no lo pediste, ignora este mensaje."
  - Authentication > Email Templates > "Reset Password": igual, con `{{ .Token }}` y sin `{{ .ConfirmationURL }}`. Ejemplo: "Tu código para restablecer la contraseña es {{ .Token }}. Si no lo pediste, ignora este mensaje."
  - Authentication > SMTP Settings (activar "Enable custom SMTP"): Host `smtp.resend.com`, Port `465`, Username `resend`, Password = la API key de Resend, Sender email `no-reply@<dominio>`, Sender name `OpenNutriTracker`.
