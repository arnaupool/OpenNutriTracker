# Cuentas de usuario

Guía para el dueño de la instancia. El diseño y las decisiones están en [`plan-cuentas.md`](plan-cuentas.md). Esta página explica cómo se usa y qué hay que configurar.

## Cómo funcionan

- **Una cuenta ocupa un perfil.** En Ajustes, la fila de sincronización abre la lista de cuentas. Un dispositivo puede tener varias cuentas con la sesión abierta y cambiar entre ellas sin volver a escribir la contraseña. Los perfiles locales (sin cuenta) siguen existiendo y no sincronizan.
- **Inicio de sesión con correo y contraseña.** No hay enlaces mágicos. El correo de confirmación y el de restablecimiento llevan un código de 6 dígitos que se escribe en la app.
- **Cifrado de extremo a extremo.** Cada cuenta tiene una clave de datos aleatoria. El servidor solo guarda esa clave envuelta con una clave derivada de la contraseña (PBKDF2-SHA256, 310.000 iteraciones) y los registros cifrados con AES-256-GCM. Ni el servidor ni tú podéis leer los datos de una cuenta.
- **Crear la cuenta desde un perfil local** sube los datos del perfil. **Iniciar sesión en otro dispositivo** fusiona lo local con la cuenta; si el mismo registro existe en los dos sitios gana la copia de la cuenta, y lo que solo existe en el dispositivo se sube.
- **Sesión sin caducidad.** El token se renueva solo mientras se use la app.
- Un perfil que antes sincronizaba con el código QR (función retirada) y no tiene cuenta conserva sus datos, deja de sincronizar y muestra "Inicia sesión para sincronizar" en Ajustes.

## Panel de administración

Los administradores son los correos de la lista `admin_emails` del servidor (de inicio, el del dueño). Si inicias sesión con uno de ellos, Ajustes muestra la sección **Administración** con el interruptor **Registro abierto**. Con el interruptor apagado nadie puede crear cuentas nuevas (lo comprueba la app y, además, un Auth Hook del servidor rechaza el alta). Las cuentas existentes siguen funcionando. Para añadir o quitar administradores se edita la lista `admin_emails` en la base de datos.

## Clave de recuperación

Opcional. En la lista de cuentas, menú de la cuenta, **Clave de recuperación**, **Generar**. La clave se muestra una sola vez; guárdala en un gestor de contraseñas. Generar una nueva sustituye a la anterior. Sirve para abrir los datos de la nube cuando se restablece la contraseña y ningún dispositivo guarda la clave de datos.

## Qué pasa al restablecer la contraseña

1. En la pantalla de inicio de sesión, **¿Olvidaste tu contraseña?**: llega un código de 6 dígitos al correo y se elige una contraseña nueva.
2. La clave de datos sigue envuelta con la contraseña vieja. Qué ocurre a continuación depende de lo que haya:
   - **Queda un dispositivo con la sesión abierta**: al abrir la app detecta que el envoltorio caducó, muestra el aviso "Se restableció tu contraseña en otro dispositivo", pide la contraseña nueva y vuelve a envolver la clave. No se pierde nada.
   - **No queda ninguno, pero hay clave de recuperación**: al iniciar sesión se pide la clave y los datos se abren.
   - **Ni dispositivo ni clave**: los datos de la nube no se pueden abrir. La app lo avisa y ofrece **Empezar de cero**: borra los datos de la nube de la cuenta y sube los que haya en el dispositivo.
3. **Cambiar la contraseña desde la app** (menú de la cuenta) no tiene este problema: la clave se vuelve a envolver en la misma operación.

## Cerrar sesión

Quita la cuenta y sus datos de este dispositivo; los datos siguen en la nube. Antes la app sincroniza. Si algo no se pudo subir, avisa ("Cambios sin subir") y solo continúa si confirmas **Cerrar sesión y perder los cambios**. Tras cerrar sesión en el perfil principal (que no se puede borrar) el dispositivo queda como recién instalado: vacío y con la elección inicial de crear cuenta, iniciar sesión o usar sin cuenta.

## Eliminar cuenta

Menú de la cuenta, **Eliminar cuenta**. Pide escribir el correo de la cuenta para confirmar. Borra para siempre la cuenta, su clave y todos sus registros en la nube (Edge Function `account-delete`) y la quita del dispositivo. No se puede deshacer. La exportación a .zip de Ajustes sigue disponible para llevarse una copia antes.

## Correo y SMTP (Resend)

El plan gratuito de Supabase limita mucho los correos y solo entrega a los miembros del proyecto. Para enviar códigos a cualquier usuario hay que configurar SMTP propio con un dominio. Los pasos exactos (dominio y registros DNS de Resend, plantillas "Confirm signup" y "Reset Password" que muestran solo `{{ .Token }}`, y los datos de Authentication > SMTP Settings) están en la sección **Pendiente del dueño** de [`plan-cuentas.md`](plan-cuentas.md#pendiente-del-dueño). No se pueden desplegar desde el repositorio: se pegan en el panel de Supabase.

## Servidor

Las migraciones están en `supabase/migrations/`: tablas de cuentas (`account_keys`, `account_records`, `app_settings`, `admin_emails`), recordatorios por cuenta y la retirada de `sync_records` y del bucket `backups`. El proyecto gratuito de Supabase se pausa tras una semana sin actividad; el cron de recordatorios y el workflow `supabase-keepalive` lo mantienen activo. Si se pausa, se reactiva desde el panel.
