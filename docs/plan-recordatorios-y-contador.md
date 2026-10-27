# Plan: contador del plan y recordatorios (2026-10-27)

Especificación: la que pasó el dueño ("Especificaciones OpenNutriTracker: notificaciones y contador del plan").

## Decisiones

- El plan usa el motor de calorías actual: el ritmo en kg/semana se convierte en `weeklyRatePct` (ritmo / peso × 100) y la meta es `targetWeightKg`. Se añade un suelo de 1.500 kcal (hombres) / 1.200 kcal (mujeres; no binario: 1.350) con aviso.
- El dueño usa iPhone con la web (PWA). Canal principal recomendado: Telegram (fiable en iOS). Push web (VAPID, desde Supabase con `pg_cron` + Edge Function) funciona en iOS 16.4+ solo con la PWA añadida a inicio y certificado válido (p. ej. `tailscale serve`, no el autofirmado de 8443). Email (Resend) como respaldo. Sin ntfy.
- Android local (tarea 6): aplazada, el dueño no usa Android.
- El servidor nunca guarda pesos ni alimentos: solo horas, días, zona horaria, suscripción, email/chat de Telegram y un booleano "comida registrada hoy".

## Tareas

### Fase 1: plan y contador (local)

1. `DietPlan` (Hive, sincronizado) y su cálculo puro: fin = inicio + ⌈kg / ritmo × 7⌉ días + días en pausa; estado; días restantes por fecha local; progreso. Tests con los criterios de aceptación.
2. Onboarding: tras el peso, kg a perder (0,5–50, pasos 0,5) y ritmo (0,25 / 0,5 / 0,75; 0,5 por defecto); resumen "Llegarías el … (N días)" e interruptor de cuenta atrás. Suelo de kcal con aviso y ritmo menor propuesto.
3. Ajustes → Mi plan: automático / manual (semanas o fecha), inicio, kg, ritmo, pausar / reanudar, interruptor.
4. Widget de inicio: "Quedan N días", fin, barra, línea de peso con media de 7 días; casos límite (terminado, objetivo alcanzado, estancado 21 días, en pausa); refresco a medianoche; abre Mi plan.

### Fase 2 y 3: recordatorios

5. Modelo `Reminder` / `ReminderSettings` (Hive, sincronizado) y Ajustes → Recordatorios (5 por defecto, personalizados hasta 15, hora en pasos de 5 min, días, canal, activo, duplicar / renombrar / borrar, No molestar, estado de canales, Enviar prueba).
6. Android: programar notificaciones locales semanales por día; omitir comida ya registrada; No molestar; al pulsar, abrir pesaje o añadir alimento.
7. Backend Supabase: tablas `reminder_devices`, `reminders`, `meal_flags`, `email_codes`; RLS por id de dispositivo; secretos en Vault (VAPID, Resend, Telegram); Edge Functions `reminders-sync`, `reminders-tick` (cron), `reminders-test`, `email-verify`, `telegram-webhook`.
8. Web: service worker de push, permiso al activar el primer recordatorio, suscripción, envío de recordatorios y booleanos de comida, detección de iOS sin instalar, estado de canales.

## Pendiente del dueño

- Token del bot de Telegram (crear con @BotFather).
- Para enviar email a cualquier dirección, Resend exige verificar un dominio; sin dominio solo llega al email de la cuenta de Resend.
