# OpenNutriTracker (fork)

Repo: https://github.com/arnaupool/OpenNutriTracker

## Qué es

Fork personal de [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker), app Flutter (Android/iOS/Web) de seguimiento nutricional. Datos locales en Hive cifrado AES. Fuentes de alimentos: Open Food Facts (productos de marca, fuerte en Europa) y USDA FDC vía Supabase (alimentos genéricos/crudos, EE.UU.).

Despliegue propio: build web self-hosted en servidor con Docker/Portainer, no en App/Play Store.

## Qué pretende

El fork sustituye el motor de cálculo estático del original (TDEE fijo IOM 2005, macros 60/25/15 fijos) por un motor dinámico estilo MacroFactor:

- Peso de tendencia (EWMA) sobre el peso en bruto, para filtrar ruido del agua/comida
- TDEE dinámico: se infiere de la relación real ingesta vs. cambio de peso, no de una fórmula estática
- Macros protein-first dinámicos, derivados del TDEE dinámico
- Objetivo diario que se amortigua y mezcla gradualmente (no saltos bruscos día a día)

Encima de eso, Home se ha rediseñado como un dashboard (gasto energético 7 días, balance energético, peso de tendencia, progreso hacia objetivo, calendarios de hábito de peso/registro, resumen de medidas corporales) en vez de duplicar lo que ya muestra Diary.

## Cómo lo hace

**Arquitectura**: Clean Architecture por feature. Cada feature tiene `data/` (DTOs + fuentes remotas/locales), `domain/` (entidades + casos de uso), `presentation/` (BLoC + widgets). DI con GetIt (`lib/core/utils/locator.dart`).

**Estado**: flutter_bloc en toda la app. Cada pantalla tiene su `*Bloc`/`*Event`/`*State`.

**Motor dinámico** (`lib/core/utils/calc/`):
- `WeightInterpolationCalc` rellena huecos de peso por interpolación lineal
- `WeightTrendCalc` aplica EWMA sobre la serie rellenada → peso de tendencia
- `TdeeDynamicCalc` infiere el TDEE real del cambio de tendencia vs. ingesta en una ventana rodante, con suavizado adicional
- `DynamicMaintenanceCalc` / `MacroDynamicCalc` traducen eso a objetivo de kcal y macros del día
- `GetKcalGoalUsecase` / `GetMacroGoalUsecase` son los puntos únicos de verdad que Home/Diary/Strategy consultan — nunca recalculan por su cuenta

**Datos**: Hive local (AES-256, clave en flutter_secure_storage). Cajas principales: `IntakeBox` (comidas registradas), `UserActivityBox`, `TrackedDayBox` (totales diarios cacheados), `WeightLogBox`, `CustomMealBox`, `RecipeBox`, cachés de búsqueda remota.

**Búsqueda de alimentos**: `ProductsRepository` agrega OFF (Search-a-licious + re-ranking por relevancia/popularidad fusionados) y Supabase FDC (full-text search en Postgres). Caché local de resultados para repetir búsquedas sin red. Hay una tercera fuente (FDC directa vía API key de USDA) ya escrita pero sin enchufar a la UI — Europa ya está bien cubierta por OFF, así que no compensa.

**IA**: integración OpenRouter para registro por foto/texto ("Magic") y escaneo de etiqueta con fallback manual.

## Estructura

```
lib/
  core/           # Compartido: data sources, DBOs/DTOs, entidades, usecases, calc/, locator.dart
  features/
    home/         # Dashboard dinámico
    diary/        # Calendario + registro diario, copiar/mover items (individual, por comida, por rango, por día completo)
    strategy/     # Explicación del motor (por qué el objetivo de hoy es el que es)
    add_meal/     # Búsqueda, escaneo, Magic (IA), recetas, presets
    meal_detail/  # Detalle nutricional de un item, con calorías/macros en vivo al editar cantidad
    profile/      # Peso, medidas corporales, fotos de progreso
    fasting/      # Temporizador de ayuno intermitente
    settings/     # Export/import, backup en la nube (Supabase), tema, unidades
  generated/      # l10n compilado — se edita a mano (ver más abajo), nunca se regenera
  l10n/           # ARBs fuente de localización
```

## Localización

Fuente en `lib/l10n/intl_en.arb` (+ de/cs/it/pl/sk/tr/uk/zh). Los generados en `lib/generated/` (`l10n.dart`, `intl/messages_en.dart`) **se editan a mano** — el generador automático no respeta el formato a 120 columnas del proyecto. Al añadir o cambiar una clave hay que tocar los tres archivos a la vez, si no el texto antiguo se queda pegado en runtime.

## Gestión del proyecto

Planificación y backlog en `Project.canvas` (Obsidian Canvas), gestionado solo vía `python canvas-tool.py "Project.canvas" <comando>` — nunca editado a mano. Flujo: propuesta (morado) → el usuario aprueba a rojo → agente empieza (naranja) → termina (cian) → el usuario revisa y marca verde.

Desde el 2026-10-19 el tablero no es una puerta de aprobación: el agente trabaja de forma autónoma (implementa, verifica, commitea y pushea) sin esperar a que las tarjetas pasen a rojo o verde.

## Comandos

```sh
just install       # flutter pub get
just build          # dart run build_runner build
just test           # flutter test
just ci              # install + format + intl check + build + analyze + test
flutter analyze
flutter test test/ruta/al/archivo_test.dart
```

Flutter 3.41.7 vía FVM. `.env` (gitignored) con claves de OFF/FDC/Supabase/Sentry, necesario para generar `env.g.dart`.
