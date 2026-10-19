# Informe QA en la app real

Fecha: 2026-10-19. Emulador `ont_test` (Android), flavor `develop` con perfiles limpios hechos para estas pruebas (los datos previos de ese flavor están respaldados en `/sdcard/develop-backup.tgz`). El banco de 30 días del flavor `full` no se ha tocado; solo se ha instalado la última build. Todas las capturas citadas están en esta carpeta.

## Método

- **Onboarding real** con perfiles conocidos. Cada número de la app se compara con un cálculo hecho a mano con la fórmula publicada.
- **Historial controlado:** [`qa_scenario.py`](qa_scenario.py) genera un zip que se importa desde Settings > Import, con 35 a 49 días de pesadas y comidas. La pérdida de peso sale del balance energético de un gasto real conocido (3000 kcal/día frente a 2400 de ingesta). El mismo script calcula, sin usar el código Dart, lo que el motor documentado debería mostrar.
- **Avance real del reloj** con `adb shell date` para recorrer cuatro semanas, el cambio de hora del 25 oct, check-ins y pausas.
- Lectura de cada pantalla con `uiautomator`.
- Cada bug se reprodujo antes del arreglo y se verificó después en el emulador, con un test que falla antes y pasa después.

## Lo que funciona y cuadra con el cálculo independiente

| Prueba | App | Referencia |
| --- | --- | --- |
| 35 días importados: TDEE estimado / tendencia / ajuste al 0.5 % | 2910 kcal / 88.0 kg / -485 | 2910.3 / 88.03 / -485.2 |
| Gasto real conocido (3000 kcal) | estimado 2910 → 2948 → 2972 kcal en 3 semanas | se acerca a 3000 (error -3 %, luego -1 %) |
| Check-in 26 oct | nuevo objetivo 2466 kcal | 2465.8 |
| Check-in 2 nov, tras el cambio de hora | 2493 kcal | 2492.7 |
| Sin registrar del 2 nov al 1 dic | 2493 kcal fijos, estado "Paused" | sin cambio |
| Balance energético 7 días / ritmo de peso | -597 kcal / -0.5 kg/semana | -600 / -0.525 |
| Comida: añadir, editar cantidad (100 → 150), copiar a otro día | Home, Diary y diálogo cuadran (960 kcal, 120/30/52.5 g) | ídem |
| Límite de día a las 04:00 | un snack a las 02:00 cuenta en el día anterior; a las 05:00 empieza el día nuevo | ídem |
| Aviso de objetivo bajo | aparece por debajo de 1200 kcal (mujer, 50 kg) | umbral documentado |

Evidencia: `qa05`-`qa10`, `qa20`.

## Bugs encontrados y arreglados

Todos están en `main`, con test que falla antes y pasa después, y verificados en el emulador.

| # | Gravedad | Bug | Evidencia antes / después | Commit |
| --- | --- | --- | --- | --- |
| 1 | **Alta** | La fórmula IOM 2005 aplicaba el coeficiente de actividad solo al término del peso, no al de la altura ([fuente](https://www.cdc.gov/PCD/issues/2006/oct/06_0034.htm)). El TDEE estático de toda persona no sedentaria salía bajo: -489 kcal/día para un hombre de 36 años, 90 kg, 180 cm y muy activo. | `qa03` 2887 → `qa14` 3376 | `c04d5b17` |
| 2 | **Alta** | El cumpleaños por defecto del onboarding era ayer: un solo OK guardaba edad 0 y la ecuación de adultos daba 2547 kcal. Profile permitía fechas de 1900 a 2100. | `qa01`, `qa02` → `qa15` | `57263ffe` |
| 3 | Media | La edad se calculaba como días/365, que adelanta el cumpleaños hasta ~9 días a los 36 años. | test `user_age_test` | `57263ffe` |
| 4 | **Alta** | El resumen del onboarding prometía las macros fijas 60/25/15 (108 g de proteína para 90 kg) y luego Home aplicaba proteína primero (171 g). | `qa03` → `qa16`, `qa17` | `0004684d` |
| 5 | Media | Profile mostraba un ritmo de 0.5 %/semana, pero el objetivo estático restaba 500 kcal fijos: para 50 kg son 276 kcal, no 500. | test de cableado | `0004684d` |
| 6 | Media | Con kJ elegido, Strategy, el check-in, el gasto semanal y las explicaciones seguían en kcal. Con unidades imperiales, la explicación seguía en kg. | `qa13` → `qa18`, `qa19` | `b94423a2` |
| 7 | Baja | Unas pantallas truncaban y otras redondeaban: el mismo objetivo salía 2465 en Diary y 2466 en Strategy; 52.5 g salían 52 en Home y 53 en el diálogo. | test `DashboardWidget rounds` | `b94423a2` |
| 8 | Media | Las fechas interpoladas se desplazaban una hora al cruzar el cambio de hora. Lo arregló la sesión aparte. | test de cambio de hora | `9b060d7b` |

`flutter analyze`: sin incidencias. `flutter test`: 905 tests en verde.

## Pendiente, sin arreglar en esta ronda

| Tema | Por qué no | Riesgo |
| --- | --- | --- |
| Con unidades imperiales, el agua sigue en ml. | Solo afecta a cómo se muestra; no toca ningún cálculo de salud. | Bajo |
| El peso del onboarding no se añade al historial de pesadas, así que el motor dinámico empieza con la primera pesada registrada. | Es una decisión de diseño, no un error de cálculo. | Bajo |
| Las macros usan el último peso del perfil (`user.weightKG`), no la tendencia. Importar pesadas no actualiza ese peso. | MacroFactor usa una estimación de masa magra (gap 7 del audit, aplazado). | Medio en el caso de importación |
| Con ritmos altos el objetivo puede bajar de 1200 kcal; solo se muestra un aviso, no hay un mínimo. | MacroFactor no documenta un mínimo; la app avisa con el umbral de Harvard Health. | Medio: decisión de producto |
| Un ritmo nuevo no se aplica hasta el siguiente check-in. | Es el comportamiento documentado de MacroFactor (art. 222). | Ninguno |
