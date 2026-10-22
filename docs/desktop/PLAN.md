# Versión de escritorio: plan

Fecha: 2026-10-22. Decisiones tomadas por ti (AskUserQuestion):

| Tema | Decisión |
| --- | --- |
| Plataforma | Web de escritorio: la misma web de tu servidor con un diseño para pantalla ancha. |
| Datos | Sincronización completa en los dos sentidos: el diario se puede editar desde el móvil y desde el escritorio. |
| Planificación | Plan semanal por día y comida, totales frente al objetivo, lista de la compra y registro del plan en el móvil con un toque. |
| Vistas | Peso y gasto, adherencia, diario completo editable y exportación a CSV. |

## Fases

Cada fase se cierra con tests, verificación en el emulador o en el navegador, y un commit con push.

### Fase 1: sincronización por registros (camino crítico)

Sin ella el escritorio no tiene datos, porque hoy todo vive cifrado en el móvil.

- **Servidor:** tu proyecto de Supabase del backup. Hay una tabla `sync_records`: `token`, `box`, `id`, `payload`, `modified_at` (reloj del cliente, para resolver conflictos), `updated_at` (reloj del servidor, para saber qué hay que descargar) y `deleted`. La RLS limita cada fila al token de emparejamiento que va en una cabecera, el mismo patrón que el backup.
- **Cifrado de extremo a extremo:** el `payload` se cifra en el dispositivo con una clave que viaja en el código de emparejamiento (QR) y nunca llega al servidor. Supabase solo ve datos opacos.
- **Cliente:** un registro de cambios local (`SyncLog`) que alimentan las fuentes de datos en cada alta, cambio o borrado; los borrados quedan como marcas. Al sincronizar se sube lo pendiente y se baja lo nuevo desde el último cursor.
- **Conflictos:** gana la última escritura por registro, comparando `modified_at`.
- **Totales:** los totales diarios (`TrackedDay`) se recalculan a partir de las comidas después de cada descarga, para que dos dispositivos que registran el mismo día no se pisen. Los objetivos del día se sincronizan como cualquier otro registro.
- **Cuándo se sincroniza:** al abrir la app, al volver a ella, tras cada cambio (con un retardo de unos segundos) y con un botón manual.
- **Cajas:** comidas, actividades, totales diarios, pesadas, medidas, recetas, comidas propias, plantillas de actividad, agua, ayuno, perfil, ajustes y planes. Las fotos siguen yendo en el backup en zip.

### Fase 2: diseño de escritorio en la web

- A partir de unos 1000 px de ancho, la barra inferior pasa a un menú lateral (`NavigationRail`). Home y Diary se reparten en columnas y los formularios dejan de ocupar todo el ancho.
- El móvil no cambia.

### Fase 3: vistas de revisión y CSV

- Peso: escala frente a tendencia, cambio por semana y pesadas por rango.
- Gasto: TDEE estimado día a día, objetivo e historial de check-ins.
- Adherencia: kcal y macros frente al objetivo por día, semana y mes.
- Diario: tabla por día y semana, con edición.
- Exportar a CSV cualquier vista o rango.

### Fase 4: planificación de comidas

- Modelo nuevo `MealPlanEntry`: día, comida, alimento o receta con su cantidad, y estado "planificado" o "registrado". Se sincroniza.
- Vista semanal: totales de cada día frente al objetivo de ese día.
- Lista de la compra: suma los ingredientes de las recetas y alimentos de un rango de días.
- En el móvil, "Registrar plan" convierte las entradas del día en comidas registradas con un toque.

### Después de la fase 1: perfiles (decidido 2026-10-22)

- Varios perfiles en el mismo móvil o web (por ejemplo, la familia), cada uno con su diario, objetivos y token de sincronización, y un selector de perfil. Sin cuentas ni login: se mantiene el modelo de privacidad actual.

### Idiomas (decidido 2026-10-22)

- Añadir castellano (`es`) y valenciano (`ca`, normas AVL, etiqueta "Valencià") además del inglés, en una sesión aparte.

## Lo que necesito de ti

1. **Reactivar Supabase:** el proyecto `openfoodtracker` (el del backup) está en pausa (`INACTIVE`), así que hoy el backup en la nube tampoco funciona. Hay que reactivarlo y crear la tabla `sync_records`.
2. **Pausas del plan gratuito:** Supabase pausa los proyectos gratuitos tras 7 días sin actividad. Con la sincronización activa no debería volver a pasar mientras uses la app.
