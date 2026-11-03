# Plan: alimentos favoritos (2026-11-03)

Problema: al buscar "leche" salen marcas que el dueño no consume, con macros distintas. Quiere guardar sus alimentos como favoritos, con sus macros, porción y código de barras, y tenerlos a mano al registrar y en el plan de comidas.

## Decisiones del dueño

1. Un favorito es una **copia local editable** de cualquier alimento (Open Food Facts, USDA o comida personalizada), o uno creado a mano. Las comidas personalizadas siguen siendo lo que se crea cuando algo no existe; también se pueden marcar como favoritas.
2. La copia no cambia si cambia el producto original. Se puede editar en cualquier momento; lo ya registrado no cambia.
3. En el buscador normal, los favoritos que coinciden salen primero, marcados con estrella.
4. Al escanear un código que es de un favorito, gana el favorito, con opción "ver el producto original". Un favorito admite varios códigos.
5. Cada favorito tiene una porción por defecto (por ejemplo "vaso, 250 ml"), editable.

## Tareas

### Fase 1: modelo y guardado
1. `FavoriteFoodDBO` (Hive, adaptador escrito a mano con un typeId libre, como los demás DBO recientes): id, nombre, marca opcional, macros y micronutrientes por 100 g o 100 ml, unidad base (g o ml), porción por defecto (nombre y cantidad), lista de códigos de barras, origen (fuente e id del producto copiado), fechas de creación y modificación.
2. Caja propia por perfil, incluida en `profileBoxNames`, en la sincronización de la cuenta, en la exportación e importación .zip y en el borrado al cerrar sesión. Tests.

### Fase 2: crear y editar
3. Estrella en el detalle de cualquier alimento (búsqueda, escáner, registro del diario): crea la copia y abre el editor.
4. "Nuevo favorito" a mano, con escáner para añadir códigos.
5. Editor: nombre, macros, porción por defecto, códigos (añadir escaneando o a mano, borrar), borrar favorito.

### Fase 3: usarlos
6. Pestaña "Favoritos" la primera al añadir comida; tocar uno registra con su porción por defecto, editable.
7. Buscador: favoritos coincidentes arriba con estrella.
8. Escáner: favorito antes que Open Food Facts, con "ver el producto original".
9. Plan de comidas: columna "Favoritos" en escritorio y pestaña en el selector del móvil. Borrar un favorito no rompe las entradas del plan (guardan sus macros).

### Fase 4: comprobación
10. Prueba completa en navegador: crear favorito de leche, añadirle un código, registrarlo, verlo en el plan y en otro dispositivo de la misma cuenta.
