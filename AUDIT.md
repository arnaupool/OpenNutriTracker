# Auditoría: motor dinámico frente a MacroFactor

Fecha: 2026-10-19. Estado: **Fase 2 implementada** (ver sección 5). Las decisiones de producto siguen la documentación de MacroFactor.

Reglas aplicadas:

- Cada afirmación sobre MacroFactor (MF) lleva una URL de fuente primaria (help.macrofactorapp.com o macrofactor.com). Lo que no tiene fuente primaria va en la sección "Sin verificar".
- Cada bug tiene pasos de reproducción en el emulador real y evidencia en [`docs/audit/`](docs/audit/). Lo que solo se vio leyendo código no entra como bug.

## 0. Material de partida (Fase 0)

### 0.1 Citas a MacroFactor ya presentes en el código

| Archivo | Qué afirma | Fuente citada |
| --- | --- | --- |
| [weight_trend_calc.dart:11-19](lib/core/utils/calc/weight_trend_calc.dart:11) | EWMA alpha = 0.1 | `ykawanabe/mf-sync` (tercero, no MF) |
| [weight_interpolation_calc.dart:13-18](lib/core/utils/calc/weight_interpolation_calc.dart:13) | Interpolación lineal de huecos | "MacroFactor documents" (sin URL) |
| [tdee_dynamic_calc.dart:4-17](lib/core/utils/calc/tdee_dynamic_calc.dart:4) | 3500 kcal/lb, ventana 21 días, change rate 20 días | Fat Loss Handbook (sin URL) |
| [tdee_dynamic_calc.dart:70-78](lib/core/utils/calc/tdee_dynamic_calc.dart:70) | Capa de suavizado adicional | help.macrofactorapp.com art. 26 |
| [dynamic_maintenance_calc.dart:2-9](lib/core/utils/calc/dynamic_maintenance_calc.dart:2) | Banda ±0.7 kg, corrección 0.15 %/semana | "MacroFactor documents" (sin URL) |
| [macro_dynamic_calc.dart:16-43](lib/core/utils/calc/macro_dynamic_calc.dart:16) | Proteína 1.6-2.2 g/kg, +0.1 g/kg en pérdida, suelo de grasa por altura | "MacroFactor documents" (sin URL) |
| [docs/fase-motor-testing.md](docs/fase-motor-testing.md) | Error inicial hasta ~590 kcal, calibración gradual ~30 días | macrofactor.com/algorithm-accuracy, art. 26 |

### 0.2 Lo que ya se evaluó y descartó o aplazó (Project.canvas e historial git)

| Tema | Dónde | Decisión |
| --- | --- | --- |
| Programas High-Carb / Low-Carb / Keto | FM-04 | No implementados: "MacroFactor solo los describe cualitativamente". |
| Selector manual de ritmo semanal | FM-08 (commit `b9161f13`) | Retirada la UI; `weeklyWeightGoalKg` queda solo como fallback estático. |
| "Check-in adaptativo" como lógica aparte | FM-06, `docs/fase-motor-testing.md` | Se decidió que sale gratis de recalcular la ventana cada día. |
| Salto estático a dinámico | FM-11 | Se añadió suavizado EWMA y mezcla 7 a 21 puntos (decisión tuya vía AskUserQuestion). |
| 21 medidas corporales de MF | FC-01 | Reducido a 7. |
| Sync bidireccional en la nube | FA-12 | Descartado en favor de snapshot zip. |
| FDC directa (API USDA) | PROJECT.md | Sin enchufar: "no compensa". |
| Health Connect, HealthKit, CI macOS | FF-01..03 | En backlog (morado). |

En el historial de `Project.canvas` (67 versiones) no hay tarjetas borradas. El diff sin commitear actual solo pasa 8 tarjetas de cian a verde.

### 0.3 Banco de pruebas en el emulador

- AVD `ont_test`, paquete `com.opennutritracker.ont.opennutritracker` (flavor `full`, APK debug del 2026-07-23 23:39). El motor (`lib/core/utils/calc/`, `get_kcal_goal_usecase.dart`) no ha cambiado desde ese build.
- Peso: un registro diario del 29 jun al 29 jul 2026, bajando 0.15 kg/día (85.0 a 79.8 kg). Perfil: Lose Weight, objetivo 80 kg, Active.
- **Aviso sobre el banco:** la ingesta está contaminada por las pruebas de copiar/mover (FR-07/08/09). La mayoría de días tienen 2300 kcal, pero el 8 y 15 jul tienen 4600, el 23 jul 9200, del 24 al 26 jul 6900, el 27 y 28 jul 13800, el 29 jul 11500 y el 30 jul 9200 (múltiplos de 2300, copias). El 12 jul no tiene registro. Por eso las cifras absolutas (TDEE de ~4200) no son realistas. Los bugs de abajo se reproducen igual; donde la contaminación los amplifica, hay además una reproducción con datos limpios.
- Para recorrer semanas se cambió el reloj (`adb root`, `settings put global auto_time 0`, `adb shell date`). Al terminar se restauró `auto_time 1`; el reloj vuelve a 2026-10-19. Las entradas que añadí para probar (una actividad el 30 jul; dos comidas y un peso el 31 jul) están borradas, y el objetivo del 31 jul volvió a 4107 kcal.

## 1. Tabla de auditoría (ordenada por impacto/esfuerzo)

Esfuerzo: XS < 30 min, S ~1 h, M medio día, L más de un día. "Confianza" se refiere a la afirmación sobre MF.

| # | Área | Comportamiento de MacroFactor (fuente) | Esta app (archivo:línea) | Gap | Confianza | Esfuerzo | Impacto |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Ejercicio registrado | El gasto se estima a partir de la ingesta y la tendencia de peso, sin datos de quema de wearables, y MF no necesita esos datos para ajustar calorías ([wearables](https://macrofactor.com/wearables/), [art. 20](https://help.macrofactorapp.com/en/articles/20-expenditure)). Su calculadora de ejercicio advierte que no debe usarse para "earning" calories ([calculadora](https://macrofactor.com/exercise-calorie-calculator/)). | Suma las kcal de las actividades de hoy al objetivo dinámico ya completo: [get_kcal_goal_usecase.dart:42-49](lib/core/domain/usecase/get_kcal_goal_usecase.dart:42). | **Bug B1** (reproducido): doble conteo. 60 min de bici suben el objetivo +678 kcal. | Verificado | S | Alto |
| 2 | Días sin registrar / pausa | V3 solo pausa las actualizaciones si faltan más de 3 días de nutrición en 7, e infiere la ingesta de los días no registrados ([expenditure-v3](https://macrofactor.com/expenditure-v3/)). Tras un hueco largo "carry forward" el último gasto de "high confidence" ([core philosophy](https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/)). | Ventana de ingesta = 25 días antes de hoy ([get_kcal_goal_usecase.dart:117-141](lib/core/domain/usecase/get_kcal_goal_usecase.dart:117)), pero la ventana de peso son los últimos 21 puntos de tendencia, por antiguos que sean ([tdee_dynamic_calc.dart:45-47](lib/core/utils/calc/tdee_dynamic_calc.dart:45)). Sin intake vuelve al estático ([get_kcal_goal_usecase.dart:77](lib/core/domain/usecase/get_kcal_goal_usecase.dart:77)). | **Bug B2** (reproducido): sin registrar nada, el objetivo sube de 4063 a 12429 kcal en 25 días y luego cae de golpe a 2114 (estático). Con datos limpios la deriva es +218 kcal y después el mismo salto. | Verificado | M | Alto |
| 3 | Objetivo perder/ganar | El ritmo se fija como "percentage of body weight per week" y el objetivo es gasto menos el déficit que exige ese ritmo ([art. 222](https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal)). | Con peso objetivo fijado, perder/ganar siempre usa la corrección de mantenimiento de 0.15 %/semana ([get_kcal_goal_usecase.dart:148-155](lib/core/domain/usecase/get_kcal_goal_usecase.dart:148)). La rama "fuera de banda, ritmo elegido" que describen la tarjeta FM-06 y el commit `abfa72c7` nunca se implementó. | **Bug B3** (reproducido): Lose Weight a 1.1 kg del objetivo da solo 134 kcal/día de déficit. | Verificado | M (requiere decisión de producto) | Alto |
| 4 | Objetivo mantener | Dynamic maintenance se aplica a los objetivos de mantenimiento. Dentro de 1.5 lb (~0.7 kg) del peso a mantener, la ingesta sigue al gasto. Fuera, aplica un déficit o superávit pequeño de 0.15 % del peso por semana ([art. 125](https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor)). | Maintain devuelve el TDEE puro e ignora el peso objetivo ([get_kcal_goal_usecase.dart:144-146](lib/core/domain/usecase/get_kcal_goal_usecase.dart:144)). | **Bug B4** (reproducido): Maintain a 0.8 kg sobre el objetivo da "matches your observed TDEE" sin corrección. Es el inverso del #3: la banda está en el objetivo equivocado. | Verificado | S (junto al #3) | Medio |
| 5 | Coherencia del objetivo del día | Un único número por día. | Diary muestra `TrackedDay.calorieGoal`, una foto tomada al crear el día y solo ajustada por actividades o cambios de perfil ([calendar_day_bloc.dart:113](lib/features/diary/presentation/bloc/calendar_day_bloc.dart:113), [day_info_widget.dart:420](lib/features/diary/presentation/widgets/day_info_widget.dart:420)). Home y Strategy calculan en vivo. | **Bug B5** (reproducido): 30 jul, Diary 3489 kcal frente a Home/Strategy 4081 kcal; macros de Diary 176 g de proteína frente a 151 g en Home. | N/A (bug interno) | S | Medio |
| 6 | Frecuencia de actualización | "Check-ins are weekly" ([art. 247](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules)). Las recomendaciones de calorías y macros son "for the next week" ([art. 20](https://help.macrofactorapp.com/en/articles/20-expenditure)). Cada semana es "a self-contained unit" ([art. 222](https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal)). | El objetivo se recalcula en cada lectura, incluida la ingesta parcial de hoy ([get_kcal_goal_usecase.dart:126-136](lib/core/domain/usecase/get_kcal_goal_usecase.dart:126)). | Gap (observado): una sola pesada a mitad de día movió el objetivo de hoy de 4107 a 4531 kcal (+424); un snack de 1000 kcal lo movió +5. **Ya evaluado** en FM-06/FM-11, que optaron por recálculo diario amortiguado. Se reabre solo porque ahora hay fuente primaria del modelo semanal. | Verificado | L | Medio (decisión de producto) |
| 7 | Proteína | Calculada con "a rough estimate of your lean body mass" ([art. 58](https://help.macrofactorapp.com/en/articles/58-change-your-body-fat-percentage)), con categorías low/moderate/high/extra high ([art. 34](https://help.macrofactorapp.com/en/articles/34-what-are-the-different-program-options-in-coached-mode)). | 1.8 g/kg fijos sobre el peso de báscula del perfil (`user.weightKG`), sin selector ([get_macro_goal_usecase.dart:17](lib/core/domain/usecase/get_macro_goal_usecase.dart:17), [get_macro_goal_usecase.dart:68](lib/core/domain/usecase/get_macro_goal_usecase.dart:68)). | Gap: base corporal distinta (peso total frente a masa magra) y sin elección de categoría. | Verificado (método); sin cifras públicas | M (requiere input de % de grasa) | Medio |
| 8 | Tarjeta Weight Trend tras un hueco | La tendencia es una media móvil recalculada "each day that you weigh in" ([weight trend](https://help.macrofactorapp.com/dashboard/weight_trend/)). No hay fuente sobre cómo muestra MF un ritmo antiguo. | Muestra el ritmo de los últimos 20 puntos aunque el último peso tenga 82 días ([weight_trend_summary_card.dart:50-65](lib/features/home/presentation/widgets/weight_trend_summary_card.dart:50)). Goal Progress, en la misma pantalla, dice que falta una semana de datos. | **Bug B6** (reproducido): 19 oct, "-1.0 kg/week" junto a "Log at least a week of weigh-ins". Es incoherencia interna; la comparación con MF está sin verificar. | Inferido | S | Bajo |
| 9 | Distancia al objetivo en Profile | MF compara la tendencia con el objetivo ([art. 125](https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor)). | Profile usa `abs(target - user.weightKG)`, el peso de báscula y sin signo ([profile_page.dart:564](lib/features/profile/profile_page.dart:564)). | **Bug B7** (reproducido): 31 jul, Profile "0.3 kg to your target" frente a Strategy "0.8 kg from your target" (trend 80.8). Además, por báscula ya está por debajo del objetivo con goal Lose. | Verificado | XS | Bajo |
| 10 | Redondeo de macros | N/A | Home trunca (`toInt`, [macro_nutriments_widget.dart:54](lib/core/presentation/widgets/macro_nutriments_widget.dart:54), 91, 128) y Strategy redondea ([strategy_page.dart:814](lib/features/strategy/presentation/strategy_page.dart:814)). | **Bug B8** (reproducido): mismo día, Home 151/83/188 g frente a Strategy 152/84/189 g. | N/A | XS | Bajo |
| 11 | Programas de macros | Cuatro estructuras: balanced, low-fat, low-carb y keto. Low-carb "tends to cap daily carbs at around 30% of total calories, or <200 grams per day" ([art. 34](https://help.macrofactorapp.com/en/articles/34-what-are-the-different-program-options-in-coached-mode)). | Solo balanced ([macro_dynamic_calc.dart:9](lib/core/utils/calc/macro_dynamic_calc.dart:9)). | Gap. **Ya descartado en FM-04** por falta de cifras. La nueva fuente solo aporta cifra para low-carb; low-fat y keto siguen siendo cualitativos. | Verificado (parcial) | S | Bajo |

### Lo que ya coincide con MF (verificado, sin acción)

- Interpolación lineal de los pesos que faltan ([weight trend](https://help.macrofactorapp.com/dashboard/weight_trend/)) frente a [weight_interpolation_calc.dart:31](lib/core/utils/calc/weight_interpolation_calc.dart:31).
- Change rate sobre 20 días expresado por semana ([art. 19](https://help.macrofactorapp.com/en/articles/19-change-rate)) frente a [tdee_dynamic_calc.dart:17](lib/core/utils/calc/tdee_dynamic_calc.dart:17).
- Banda ±1.5 lb y nudge de 0.15 %/semana ([art. 125](https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor)) frente a [dynamic_maintenance_calc.dart:5-9](lib/core/utils/calc/dynamic_maintenance_calc.dart:5). Las constantes son correctas; el fallo es a qué objetivo se aplican (#3, #4).
- Balanced reparte las calorías no proteicas a partes iguales entre carbohidrato y grasa ([art. 34](https://help.macrofactorapp.com/en/articles/34-what-are-the-different-program-options-in-coached-mode)), y carbohidrato ≈ 2-2.5 veces la grasa en gramos ([art. 93](https://help.macrofactorapp.com/en/articles/93-balanced-macro-program)).
- Sin datos de wearables en el gasto ([wearables](https://macrofactor.com/wearables/)).
- La estimación inicial tarda en asentarse unas 2-3 semanas ([FAQ gasto](https://help.macrofactorapp.com/FAQ/interpet_energy_expenditure)), coherente con la mezcla 7 a 21 puntos de FM-11.

## 2. Bugs reproducidos (pasos exactos)

Preparación común: emulador `ont_test` arrancado, `adb root`, `adb shell settings put global auto_time 0`, `adb shell date MMDD1200YYYY.00`, force-stop y relanzar la app antes de cada lectura. Lecturas con `uiautomator dump`.

### B1. Las actividades registradas se suman encima del TDEE dinámico

1. Reloj al 2026-07-30. Strategy: Today's Target **4081 kcal**, TDEE 4215 ([04-home-jul30-before-activity.png](docs/audit/04-home-jul30-before-activity.png)).
2. Home, botón +, Activity, "bicycling, mountain", 60 min (~677 kcal) y Add ([05-activity-detail.png](docs/audit/05-activity-detail.png)).
3. Home muestra 677 burned. Strategy: Today's Target **4759 kcal** con el TDEE sin cambiar en 4215 ([06](docs/audit/06-home-jul30-after-activity.png), [07](docs/audit/07-strategy-jul30-after-activity.png)).
4. Borrar la actividad desde Diary: el objetivo vuelve a 4081.

El TDEE dinámico ya contiene el ejercicio habitual, porque sale de la ingesta y del peso. Sumar la actividad lo cuenta dos veces.

### B2. El objetivo deriva sin datos nuevos y luego cae de golpe al estático

1. Banco tal cual (último peso el 29 jul). No registrar nada.
2. Leer Strategy a las 12:00 de: 29 jul, 30 jul, 1, 3, 6, 10, 15, 20, 23, 24 y 25 ago, 1 sep, y con el reloj real (19 oct).
3. Resultado ([strategy-sampling-jul29-sep01.txt](docs/audit/strategy-sampling-jul29-sep01.txt)): 4063, 4081, 4144, 4052, 4281, 4369, 5361, 8954, **12429** (23 ago), y desde el 24 ago **2114** con "Insufficient data" (estático). El 19 oct sigue en 2114 ([02-strategy-today-after-gap.png](docs/audit/02-strategy-today-after-gap.png), [01-home-today-after-gap.png](docs/audit/01-home-today-after-gap.png)).
4. Con datos limpios (2300 kcal constantes, -0.15 kg/día, 31 días) y la misma selección de datos que el usecase ([repro_drift_clean_data.dart.txt](docs/audit/repro_drift_clean_data.dart.txt), salida de `flutter test` incluida): 3080 kcal, sube sin datos nuevos hasta 3298 el día 25 y el día 26 da `null` (vuelta al estático).

Causa: la ventana de ingesta (25 días antes de hoy) se desliza, pero la de peso (últimos 21 puntos de tendencia) se queda fija en los últimos pesos registrados. A medida que salen días de ingesta, la media se calcula con cada vez menos días, que se comparan con el mismo cambio de peso. Con días atípicos en el banco, el efecto se multiplica. MF pausa en vez de seguir calculando y conserva el último valor fiable.

### B3. Perder peso con peso objetivo solo aplica la corrección de mantenimiento

1. Reloj al 2026-07-29. Perfil: Lose Weight, objetivo 80 kg, trend 81.1 kg.
2. Strategy: "1.1 kg from your target, correcting by **134 kcal/day**" ([03-strategy-jul29.png](docs/audit/03-strategy-jul29.png)).
3. 134 kcal/día = 0.15 % × 81.1 kg × 7716 kcal/kg / 7, que es el nudge de mantenimiento ([dynamic_maintenance_calc.dart:45-52](lib/core/utils/calc/dynamic_maintenance_calc.dart:45)). La distancia al objetivo no cambia el déficit: a 1 kg o a 20 kg sería el mismo.

Contexto: la tarjeta FM-06 y el mensaje del commit `abfa72c7` describen una rama "fuera de banda: TDEE menos el déficit del ritmo elegido" que no está en el código de `abfa72c7` ni en HEAD. FM-08 retiró después la UI del ritmo, así que ahora no hay forma de elegirlo.

### B4. Mantener ignora el peso objetivo

1. Reloj al 2026-07-31, con una pesada de prueba que deja la trend en 80.8 kg y el objetivo en 80 kg (0.8 kg fuera de la banda de 0.7).
2. Profile, Goal, Maintain Weight.
3. Strategy: "4669 kcal, Maintaining, matches your observed TDEE", igual al TDEE de 4669 y sin nudge ([15-strategy-jul31-maintain.png](docs/audit/15-strategy-jul31-maintain.png)). Con Lose Weight en el mismo estado aplicaba -134 kcal ([11](docs/audit/11-strategy-jul31-after-weighin.png)).
4. Goal restaurado a Lose Weight y pesada de prueba borrada.

### B5. Diary y Home muestran objetivos distintos para el mismo día

1. Reloj al 2026-07-30. Home/Strategy: 4081 kcal; macros de Home 434/193/151 g.
2. Diary, 30 jul: "9200/**3489** kcal" (sin actividad). Con la actividad de B1: Diary **4167** frente a Strategy **4759**; macros de Diary 462/179/176 g ([08-diary-jul30-goal-mismatch.png](docs/audit/08-diary-jul30-goal-mismatch.png), [07](docs/audit/07-strategy-jul30-after-activity.png)).
3. 31 jul, tras pesar y añadir un snack: Diary 4530 frente a Home 4536 ([13-diary-jul31-goal.png](docs/audit/13-diary-jul31-goal.png), [12](docs/audit/12-strategy-jul31-after-snack.png)).

Causa: Diary lee la foto `TrackedDay.calorieGoal`, guardada cuando se creó el día (en el 30 jul, al copiar comidas a fechas futuras el 23 jul), y nunca se refresca cuando cambia el objetivo dinámico.

### B6. Ritmo de tendencia antiguo mostrado como actual

1. Reloj real (2026-10-19); último peso el 29 jul.
2. Home: "81.1 kg Trend Weight, -1.0 kg/week" y, debajo, Goal Progress "Log at least a week of weigh-ins to see your goal progress" ([01-home-today-after-gap.png](docs/audit/01-home-today-after-gap.png)).

### B7. Profile y Strategy dan distancias al objetivo distintas

1. Reloj al 2026-07-31. Profile: "Weight 79.8 kg, 0.3 kg to your target", objetivo 80 kg ([14-profile-jul31.png](docs/audit/14-profile-jul31.png)).
2. Strategy en el mismo estado: "1.1 kg from your target" (trend 81.1) ([09](docs/audit/09-strategy-jul31-before-meal.png)).

### B8. Gramos de macros distintos en Home y Strategy

1. Reloj real, mismo estado. Home: 0/188 g carbs, 0/83 g fat, 0/151 g protein ([01](docs/audit/01-home-today-after-gap.png)). Strategy: 189 / 84 / 152 g ([02](docs/audit/02-strategy-today-after-gap.png)).

## 3. Sin verificar: requiere confirmación manual

Afirmaciones que el código atribuye a MF y para las que **no encontré fuente primaria** en esta sesión. No las trato como gaps ni como aciertos.

| Afirmación en el código | Qué encontré | Cómo confirmarlo |
| --- | --- | --- |
| EWMA alpha = 0.1 ([weight_trend_calc.dart:19](lib/core/utils/calc/weight_trend_calc.dart:19)) | MF solo dice "moving average ... greater emphasis on more recent weigh-ins" ([weight trend](https://help.macrofactorapp.com/dashboard/weight_trend/)). El 0.1 viene de mf-sync, un tercero. | Meter la misma serie en MF y comparar la tendencia día a día (ya descrito en `docs/fase-motor-testing.md`). |
| Ventana de 21 días para el TDEE ([tdee_dynamic_calc.dart:14](lib/core/utils/calc/tdee_dynamic_calc.dart:14)) | El artículo V3 dice explícitamente que no divulga detalles de implementación ([expenditure-v3](https://macrofactor.com/expenditure-v3/)). | Citar la página exacta del Fat Loss Handbook o tratarlo como elección propia. |
| 3500 kcal/lb ([tdee_dynamic_calc.dart:9](lib/core/utils/calc/tdee_dynamic_calc.dart:9)) | V3 llama a la regla de 3500 kcal "a decent general heuristic" y da densidades de 39.5 MJ/kg para grasa y 7.6 MJ/kg para tejido magro, sin decir qué constante usa. | Fat Loss Handbook. |
| Proteína 1.6-2.2 g/kg y +0.1 g/kg en pérdida ([macro_dynamic_calc.dart:17-22](lib/core/utils/calc/macro_dynamic_calc.dart:17)) | Los artículos de MF no dan cifras; solo categorías y base de masa magra (#7). | Comprobarlo en la app MF (pantalla de programa) o en una fuente de SBS. |
| Suelo de grasa `((altura-150)*0.5)+30` ([macro_dynamic_calc.dart:40](lib/core/utils/calc/macro_dynamic_calc.dart:40)) | MF menciona un "lower limit" de grasa sin fórmula ([art. 34](https://help.macrofactorapp.com/en/articles/34-what-are-the-different-program-options-in-coached-mode)). | Igual que la fila anterior. |
| Qué hace MF al alcanzar el peso objetivo en perder/ganar | Solo se ofrece "continue pursuing your goal until you reach Trend Weight" ([goal features](https://macrofactor.com/goal-features/)); no está claro si pasa a mantenimiento. | Confirmación manual en la app MF. |

## 4. Decisiones que necesitan tu criterio antes de la Fase 2

1. **Aprobar o recortar la lista.** Propuesta de orden: B1, B2, B3+B4, B5, B8, B7, B6. Los gaps #6, #7 y #11 quedan fuera hasta que decidas.
2. **B1 (ejercicio):** con el motor dinámico, ¿dejar de sumar actividades (alineado con MF), sumarlas solo en la parte estática de la mezcla, o mantenerlo como opción en Settings?
3. **B3 (ritmo de pérdida/ganancia):** recuperar un selector de ritmo en % de peso/semana (como MF), lo que deshace parcialmente FM-08, o derivar el ritmo de la distancia y una fecha objetivo.
4. **B2 (pausa):** qué umbral usar. Propuesta: el de MF V3 (pausar si faltan más de 3 días de ingesta en los últimos 7, y conservar el último valor fiable en vez de volver al estático).
5. **#6 (check-in semanal):** ¿reabrir la decisión de FM-11 o mantener el recálculo diario?

Nada de esto se ha implementado. Espero tu aprobación del documento.

## 5. Estado de implementación (Fase 2)

Todo verificado en el emulador con el banco de pruebas; evidencia `fm12-*`, `fm13-*`, `fm14-*`, `fd12-*`, `fd13-*` y `fm15-*` en [`docs/audit/`](docs/audit/). `flutter analyze` sin incidencias y `flutter test` en verde (895 tests) en el último commit.

| Item | Kanvas | Commit | Resultado verificado |
| --- | --- | --- | --- |
| B1 ejercicio | FM-12 | `c81992e5` | 60 min de bici ya no cambian el objetivo (4081 antes y después). |
| B2 pausa | FM-13 | `ce06d384` | Sin registrar, 4063 kcal fijos del 29 jul al 19 oct, con estado "Paused". |
| B3+B4 ritmo y banda | FM-14 | `77d84b0f` | Lose al 0.5 %: -447 kcal; al 1 %: -894 kcal; Maintain: nudge de -134 kcal. |
| B5 Diary | FD-12 | `bceb1202` | Home, Strategy y Diary con 3750 kcal y las mismas macros. |
| B8, B7, B6 | FD-13 | `1c6a4034` | Macros iguales en Home y Strategy; 1.1 kg en Profile y Strategy; "No weigh-ins in the last 20 days". |
| Gap 6 check-in semanal | FM-15 | `2cd5be9f` | Objetivo fijo entre check-ins; el 5 ago se ofrecen 4207 frente a 3750 y se aplica en Strategy y Home. |

Fuera de esta ronda: gap 7 (proteína sobre masa magra, requiere el % de grasa) y gap 11 (programas low-fat/keto sin cifras públicas).
