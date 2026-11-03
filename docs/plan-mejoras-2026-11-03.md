# Plan: mejoras del 3 de noviembre de 2026

Seis peticiones del dueño, con sus decisiones. No se programa hasta que el dueño diga que empecemos.

## Decisiones

1. **Añadir al plan:** al escribir en el buscador del diálogo aparece una cuarta columna "Base de datos" (Open Food Facts y USDA), y abajo los botones "Nuevo favorito" y "Nueva receta"; al crear uno se vuelve al diálogo con lo creado listo para añadir.
2. **Fotos lentas:** la caché del contenedor ya funciona (0,01 s por foto guardada). Lo lento es abrir cada conexión con Open Food Facts (de 10 a 17 s de TCP y TLS; luego la foto llega en 0,4 s). Se reutilizan las conexiones.
3. **Recipes:** columna "Favoritos" entre Recetas y Comidas personalizadas (pestaña en móvil); el "+" permite crear un favorito. Se quita "Import recipe" del menú.
4. **Búsqueda:** un resultado debe contener todas las palabras en nombre o marca (sin distinguir acentos ni mayúsculas); orden: favoritos y personalizadas, luego nombre con todas las palabras, luego nombre y marca; la popularidad solo desempata y se mantiene la preferencia por España; si no hay nada, sección "Resultados parecidos". Tarjetas con marca, cantidad, kcal por 100 g y proteína.
5. **Diario:** mismo contenido y disposición; las tarjetas de resumen del día y "This week" pasan a recuadros delimitados (fondo, borde suave, márgenes, título). La píldora de kcal en tono del tema, roja solo si se supera el objetivo. En "This week", cada macro en su fila delimitada. "Ocultar" en el menú de la sección Activity (ya existe el ajuste "Mostrar seguimiento de actividad").
6. **Notas del plan:** una nota por semana al final del plan, texto libre con casillas ("- [ ] ..."), guardado automático y sincronizada con la cuenta.

## Huecos y cómo se cubren

| Hueco | Solución |
| --- | --- |
| USDA solo tiene nombres en inglés: con "todas las palabras", "leche" no encuentra "Milk" | La regla de todas las palabras se aplica a Open Food Facts; USDA mantiene su orden propio |
| Quitar "Import recipe" deja recetas compartidas por QR sin entrada visible | El escáner principal ya detecta un QR de receta e importa; se mantiene esa vía y el botón de compartir |
| Notas editadas a la vez en dos dispositivos | Gana la última escritura de toda la nota, como el resto de la sincronización; se documenta |
| Producto de la base de datos añadido al plan | La entrada del plan guarda sus macros (como hoy), no depende del producto |
| Open Food Facts cierra conexiones reutilizadas | Si una conexión reutilizada falla, nginx abre otra; la caché sigue sirviendo lo ya visto |

## Tareas

1. nginx: `upstream` con `keepalive` hacia Open Food Facts (imágenes y búsqueda), `proxy_http_version 1.1`, cabecera `Connection` vacía, reutilización de sesión TLS y tiempos de conexión razonables. Medir en Unraid antes y después.
2. Búsqueda: filtro y orden nuevos con tests (incluido "chocolate mercadona"), sección "Resultados parecidos", tarjetas con marca, cantidad, kcal y proteína.
3. Recipes: columna o pestaña Favoritos, "+" con "Nuevo favorito", quitar "Import recipe".
4. Añadir al plan: columna "Base de datos" al escribir y botones de crear con retorno al diálogo.
5. Diario: estilo delimitado de las dos tarjetas y "Ocultar" en Activity.
6. Notas por semana: caja nueva sincronizada (por perfil, en exportación .zip, borrada al cerrar sesión), editor con casillas, al final del plan.
7. Prueba en navegador de cada punto, capturas en `docs/qa/`, y versión publicada comunicada al dueño.
