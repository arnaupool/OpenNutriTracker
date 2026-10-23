// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'es';

  static String mPlanWeekOf(value) =>
      "Semana del ${value}";

  static String mPlanLogged(count) =>
      "Registradas en el diario: ${count}";

  static String mPlanGoalValue(planned, goal) =>
      "${planned} / ${goal} kcal";

  static String mPlanTodaySummary(count, kcal) =>
      "${count} en el plan · ${kcal} kcal";


  static String mSyncStatusIdle(value) =>
      "Al día · última sincronización ${value}";

  static String mSyncDoneSnackbar(pulled, pushed) =>
      "Sincronizado: ${pulled} recibidos, ${pushed} enviados";

  static String m0(versionNumber) =>
      "Versión ${versionNumber}";

  static String m1(pctCarbs, pctFats, pctProteins) =>
      "${pctCarbs}% carbohidratos, ${pctFats}% grasas, ${pctProteins}% proteínas";

  static String m2(count, size) =>
      "${count} elemento(s) · ${size}";

  static String m3(imported, skipped) =>
      "Se han importado ${imported} comida(s); se han omitido ${skipped} fila(s) por datos no válidos.";

  static String m4(count) =>
      "Se han importado ${count} comida(s).";

  static String m5(unit) =>
      "${unit} en una ración";

  static String m6(loser, winner) =>
      "Todas las entradas registradas con ${loser} pasarán a mostrar ${winner}, y ${loser} se eliminará de tus alimentos personalizados. Esta acción no se puede deshacer.";

  static String m7(winner) =>
      "Combinados: ${winner} tiene ahora 1 entrada registrada.";

  static String m8(count, winner) =>
      "Combinados: ${winner} tiene ahora ${count} entradas registradas.";

  static String m9(count) =>
      "${count} elementos copiados";

  static String m10(count) =>
      "¿Eliminar ${count} receta(s)?";

  static String m11(consumed, target) =>
      "${consumed} / ${target} kcal";

  static String m12(value) =>
      "ref. ${value}";

  static String m13(value) =>
      "Ayuno terminado tras ${value}.";

  static String m14(max) =>
      "Introduce entre 1 y ${max} horas.";

  static String m15(count, value) =>
      "Últimos 7 días: ${count} registrados, media de ${value}";

  static String m16(remaining) =>
      "Ayuno · quedan ${remaining}";

  static String m17(value) =>
      "Ayuno · ${value}";

  static String m18(value) =>
      "${value} por encima del objetivo";

  static String m19(value) =>
      "Quedan ${value}";

  static String m20(value) =>
      "Inicio: ${value}";

  static String m21(value) =>
      "Objetivo: ${value}";

  static String m22(rate) =>
      "${rate}/semana";

  static String m23(count) =>
      "¿Importar ${count} actividades?";

  static String m24(mealType) =>
      "Estos elementos se añadirán a ${mealType}.";

  static String m25(count) =>
      "¿Importar ${count} elementos?";

  static String m26(count) =>
      "${count} elemento(s) no se han podido obtener de OpenFoodFacts.";

  static String m27(count) =>
      "¿Importar esta receta con ${count} ingrediente(s)?";

  static String m28(amount) =>
      "Añadir ${amount} ml";

  static String m29(threshold) =>
      "La mayoría de los adultos no deberían comer menos de ${threshold} kcal al día durante un tiempo prolongado sin supervisión médica. Plantéate hablar con un profesional sanitario antes de mantener un objetivo tan bajo.";

  static String m30(kcal) =>
      "(+${kcal} kcal con la selección actual)";

  static String m31(consumed, goal) =>
      "Total del día: ${consumed} / ${goal}";

  static String m32(qty, unit) =>
      "Por ${qty} ${unit}";

  static String m33(riskValue) =>
      "Riesgo de comorbilidades: ${riskValue}";

  static String m34(value) =>
      "${value} para tu objetivo";

  static String m35(ratePct) =>
      "${ratePct}% del peso corporal por semana";

  static String m36(mealType) =>
      "Añadido a ${mealType}";

  static String m37(count) =>
      "${count} ingrediente(s)";

  static String m38(count) =>
      "Añadir todo (${count} elementos)";

  static String m39(kcal) =>
      "${kcal} kcal en total";

  static String m40(count) =>
      "${count} seleccionados";

  static String m41(hour) =>
      "${hour}:00";

  static String m42(hour, minute) =>
      "${hour}:${minute}";

  static String m43(time) =>
      "Hora del recordatorio: ${time}";

  static String m44(newTarget, currentTarget) =>
      "Tu revisión semanal está lista. Nuevo objetivo: ${newTarget} (ahora ${currentTarget}).";

  static String m45(date) =>
      "Próxima revisión: ${date}";

  static String m46(distance, correction) =>
      "A ${distance} de tu objetivo: corrigiendo ${correction}/día hacia la meta";

  static String m47(ratePct, adjustment) =>
      "Buscando un ${ratePct}% del peso corporal por semana: ${adjustment}/día respecto a tu TDEE";

  static String m48(band) =>
      "A menos de ${band} de tu objetivo: mantenimiento con tu TDEE observado";

  static String m49(floor) =>
      "Fijado en el mínimo de ${floor}: tu ritmo semanal está limitado para que el objetivo nunca baje de ahí.";

  static String m50(current, goal) =>
      "${current} / ${goal} ml";

  static String m51(age) =>
      "${age} años";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "activityExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., correr, bici, yoga..."),
        "activityLabel": MessageLookupByLibrary.simpleMessage(
            "Actividad"),
        "addItemBodyMeasurementsExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., cintura, pecho, cadera"),
        "addItemLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir elemento:"),
        "addItemMenuMagicLabel": MessageLookupByLibrary.simpleMessage(
            "Magia"),
        "addItemMenuMagicSubtitle": MessageLookupByLibrary.simpleMessage(
            "Foto, texto o ambos"),
        "addItemMenuPresetsLabel": MessageLookupByLibrary.simpleMessage(
            "Plantillas"),
        "addItemMenuPresetsSubtitle": MessageLookupByLibrary.simpleMessage(
            "Comidas guardadas"),
        "addItemMenuRecentlyLabel": MessageLookupByLibrary.simpleMessage(
            "Recientes"),
        "addItemMenuRecentlySubtitle": MessageLookupByLibrary.simpleMessage(
            "Registrar de nuevo"),
        "addItemMenuScanProductLabel": MessageLookupByLibrary.simpleMessage(
            "Escanear producto"),
        "addItemMenuScanProductSubtitle": MessageLookupByLibrary.simpleMessage(
            "Código de barras"),
        "addItemMenuSearchLabel": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "addItemMenuSearchSubtitle": MessageLookupByLibrary.simpleMessage(
            "Base de datos de alimentos"),
        "addItemWeightExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., el pesaje de esta mañana"),
        "addLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir"),
        "additionalInfoLabelBedca": MessageLookupByLibrary.simpleMessage(
            "Más información en\nBEDCA (AESAN)"),
        "additionalInfoLabelCompendium2011": MessageLookupByLibrary.simpleMessage(
            "Información proporcionada\n por el \n\'2024 Compendium\n of Physical Activities\'"),
        "additionalInfoLabelCustom": MessageLookupByLibrary.simpleMessage(
            "Alimento personalizado"),
        "additionalInfoLabelFDC": MessageLookupByLibrary.simpleMessage(
            "Más información en\nFoodData Central"),
        "additionalInfoLabelOFF": MessageLookupByLibrary.simpleMessage(
            "Más información en\nOpenFoodFacts"),
        "additionalInfoLabelUnknown": MessageLookupByLibrary.simpleMessage(
            "Alimento desconocido"),
        "ageLabel": MessageLookupByLibrary.simpleMessage(
            "Edad"),
        "allItemsLabel": MessageLookupByLibrary.simpleMessage(
            "Todos"),
        "alphaVersionName": MessageLookupByLibrary.simpleMessage(
            "[Alfa]"),
        "appDescription": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker es un contador de calorías y nutrientes libre y de código abierto que respeta tu privacidad."),
        "appLicenseLabel": MessageLookupByLibrary.simpleMessage(
            "Licencia GPL-3.0"),
        "appTitle": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker"),
        "appVersionName": m0,
        "appearanceTitle": MessageLookupByLibrary.simpleMessage(
            "Apariencia"),
        "barcodeInvalidEan13CheckDigit": MessageLookupByLibrary.simpleMessage(
            "Parece que este código de 13 dígitos está mal escrito: el último dígito no cuadra con el resto"),
        "baseQuantityLabel": MessageLookupByLibrary.simpleMessage(
            "Cantidad base (g/ml)"),
        "bedcaDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Fuente: AESAN/BEDCA Base de Datos Española de Composición de Alimentos v1.0 (2010). Los valores son por 100 g de porción comestible. Los datos se ofrecen para uso personal y no comercial; no se garantiza que sean exactos ni completos."),
        "betaVersionName": MessageLookupByLibrary.simpleMessage(
            "[Beta]"),
        "bmiInfo": MessageLookupByLibrary.simpleMessage(
            "El índice de masa corporal (IMC) es un índice para clasificar el sobrepeso y la obesidad en adultos. Se define como el peso en kilogramos dividido por el cuadrado de la altura en metros (kg/m²).\n\nEl IMC no distingue entre masa grasa y masa muscular y puede ser engañoso para algunas personas."),
        "bmiLabel": MessageLookupByLibrary.simpleMessage(
            "IMC"),
        "bodyMeasurementsAddEntry": MessageLookupByLibrary.simpleMessage(
            "Añadir registro"),
        "bodyMeasurementsBicepsLabel": MessageLookupByLibrary.simpleMessage(
            "Bíceps"),
        "bodyMeasurementsChartEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra al menos dos entradas de esta medida para ver su tendencia."),
        "bodyMeasurementsChestLabel": MessageLookupByLibrary.simpleMessage(
            "Pecho"),
        "bodyMeasurementsCompareAfterLabel": MessageLookupByLibrary.simpleMessage(
            "Después"),
        "bodyMeasurementsCompareBackgroundDarkLabel": MessageLookupByLibrary.simpleMessage(
            "Oscuro"),
        "bodyMeasurementsCompareBackgroundLabel": MessageLookupByLibrary.simpleMessage(
            "Fondo"),
        "bodyMeasurementsCompareBackgroundWhiteLabel": MessageLookupByLibrary.simpleMessage(
            "Blanco"),
        "bodyMeasurementsCompareBeforeLabel": MessageLookupByLibrary.simpleMessage(
            "Antes"),
        "bodyMeasurementsCompareEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Aún no hay fotos de progreso con este ángulo."),
        "bodyMeasurementsCompareSelectDateLabel": MessageLookupByLibrary.simpleMessage(
            "Seleccionar fecha"),
        "bodyMeasurementsCompareShareTooltip": MessageLookupByLibrary.simpleMessage(
            "Compartir"),
        "bodyMeasurementsCompareTitle": MessageLookupByLibrary.simpleMessage(
            "Comparar fotos"),
        "bodyMeasurementsCompareTooltip": MessageLookupByLibrary.simpleMessage(
            "Comparar fotos"),
        "bodyMeasurementsDateLabel": MessageLookupByLibrary.simpleMessage(
            "Fecha"),
        "bodyMeasurementsHipsLabel": MessageLookupByLibrary.simpleMessage(
            "Cadera"),
        "bodyMeasurementsNeckLabel": MessageLookupByLibrary.simpleMessage(
            "Cuello"),
        "bodyMeasurementsNoEntries": MessageLookupByLibrary.simpleMessage(
            "Aún no hay medidas. Añade la primera para empezar a hacer el seguimiento."),
        "bodyMeasurementsNoteLabel": MessageLookupByLibrary.simpleMessage(
            "Nota (opcional)"),
        "bodyMeasurementsPhotoBackLabel": MessageLookupByLibrary.simpleMessage(
            "Espalda"),
        "bodyMeasurementsPhotoFrontLabel": MessageLookupByLibrary.simpleMessage(
            "Frente"),
        "bodyMeasurementsPhotoSideLabel": MessageLookupByLibrary.simpleMessage(
            "Perfil"),
        "bodyMeasurementsPhotosLabel": MessageLookupByLibrary.simpleMessage(
            "Fotos"),
        "bodyMeasurementsShouldersLabel": MessageLookupByLibrary.simpleMessage(
            "Hombros"),
        "bodyMeasurementsThighLabel": MessageLookupByLibrary.simpleMessage(
            "Muslo"),
        "bodyMeasurementsWaistLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura"),
        "bodyMeasurementsWaistToHeightRatioLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura-altura"),
        "bodyMeasurementsWaistToHipRatioLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura-cadera"),
        "breakfastExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., cereales, leche, café..."),
        "breakfastLabel": MessageLookupByLibrary.simpleMessage(
            "Desayuno"),
        "burnedLabel": MessageLookupByLibrary.simpleMessage(
            "quemadas"),
        "buttonNextLabel": MessageLookupByLibrary.simpleMessage(
            "SIGUIENTE"),
        "buttonResetLabel": MessageLookupByLibrary.simpleMessage(
            "Restablecer"),
        "buttonSaveLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar"),
        "buttonStartLabel": MessageLookupByLibrary.simpleMessage(
            "EMPEZAR"),
        "buttonYesLabel": MessageLookupByLibrary.simpleMessage(
            "SÍ"),
        "calciumLabel": MessageLookupByLibrary.simpleMessage(
            "calcio"),
        "calculationsMacronutrientsDistributionLabel": MessageLookupByLibrary.simpleMessage(
            "Distribución de macros"),
        "calculationsMacrosDistribution": m1,
        "calculationsRecommendedLabel": MessageLookupByLibrary.simpleMessage(
            "(recomendado)"),
        "calculationsTDEEIOM2006Label": MessageLookupByLibrary.simpleMessage(
            "Ecuación del Institute of Medicine (2005)"),
        "calculationsTDEELabel": MessageLookupByLibrary.simpleMessage(
            "Ecuación de TDEE"),
        "caloriesLabel": MessageLookupByLibrary.simpleMessage(
            "calorías"),
        "caloriesProfileAveragedLabel": MessageLookupByLibrary.simpleMessage(
            "Referencia promedio (predeterminada)"),
        "caloriesProfileEstrogenTypicalLabel": MessageLookupByLibrary.simpleMessage(
            "Referencia de perfil estrogénico"),
        "caloriesProfileInfoBody": MessageLookupByLibrary.simpleMessage(
            "No existe una referencia calórica publicada para personas no binarias: las ecuaciones de referencia se basan en muestras de hombres y mujeres. Por defecto usamos la media de ambas, un punto de partida neutro que no te pide revelar nada más sobre tu cuerpo. El control de kcal de Ajustes siempre está disponible para afinarlo; esto es un punto de partida, no una estimación precisa."),
        "caloriesProfileInfoTitle": MessageLookupByLibrary.simpleMessage(
            "Referencia calórica"),
        "caloriesProfileTestosteroneTypicalLabel": MessageLookupByLibrary.simpleMessage(
            "Referencia de perfil testosterónico"),
        "carbohydrateLabel": MessageLookupByLibrary.simpleMessage(
            "carbohidratos"),
        "carbsLabel": MessageLookupByLibrary.simpleMessage(
            "carbohidratos"),
        "carbsLabelShort": MessageLookupByLibrary.simpleMessage(
            "c"),
        "cholesterolLabel": MessageLookupByLibrary.simpleMessage(
            "colesterol"),
        "chooseWeightGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Elige tu objetivo de peso"),
        "clearOffCacheConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Elimina los resultados de búsqueda y escaneo de Open Food Facts y FDC guardados en caché en el dispositivo. La caché se vuelve a crear automáticamente a medida que buscas y escaneas productos. Tus alimentos personalizados no se ven afectados."),
        "clearOffCacheConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Borrar elementos en caché?"),
        "clearOffCacheLabel": MessageLookupByLibrary.simpleMessage(
            "Borrar elementos en caché"),
        "clearOffCacheSubtitle": m2,
        "cloudBackupPairInstructionsLabel": MessageLookupByLibrary.simpleMessage(
            "Escanea el código QR que aparece en tu otro dispositivo o pega el código de vinculación a mano."),
        "cloudBackupPairInvalidTokenError": MessageLookupByLibrary.simpleMessage(
            "Eso no parece un código de vinculación válido"),
        "cloudBackupPairPasteHint": MessageLookupByLibrary.simpleMessage(
            "Pega aquí el código de vinculación"),
        "cloudBackupPairScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositivo"),
        "cloudBackupPairSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Dispositivo vinculado"),
        "cloudBackupTokenDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Código de vinculación de la copia en la nube"),
        "cmLabel": MessageLookupByLibrary.simpleMessage(
            "cm"),
        "codeCopiedLabel": MessageLookupByLibrary.simpleMessage(
            "Código copiado"),
        "copyActionLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar"),
        "copyCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar código"),
        "copyDayDialogTitle": MessageLookupByLibrary.simpleMessage(
            "¿A qué fecha(s) copias este día?"),
        "copyDialogDateLabel": MessageLookupByLibrary.simpleMessage(
            "Fecha"),
        "copyDialogTitle": MessageLookupByLibrary.simpleMessage(
            "¿A qué comida y día lo copias?"),
        "copyOrDeleteTimeDialogContent": MessageLookupByLibrary.simpleMessage(
            "Con \"Copiar\" puedes copiar la comida a otro sitio. Con \"Eliminar\" puedes eliminarla."),
        "copyOrDeleteTimeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "¿Qué quieres hacer?"),
        "createCustomDialogContent": MessageLookupByLibrary.simpleMessage(
            "¿Quieres crear un alimento personalizado?"),
        "createCustomDialogTitle": MessageLookupByLibrary.simpleMessage(
            "¿Crear alimento personalizado?"),
        "createRecipeTitle": MessageLookupByLibrary.simpleMessage(
            "Crear receta"),
        "csvImportContributeOffAndroidLink": MessageLookupByLibrary.simpleMessage(
            "Android"),
        "csvImportContributeOffIosLink": MessageLookupByLibrary.simpleMessage(
            "iOS"),
        "csvImportContributeOffPrefix": MessageLookupByLibrary.simpleMessage(
            "¿Tiene código de barras? Ayuda a todo el mundo aportando el producto a Open Food Facts:"),
        "csvImportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No se ha podido leer el archivo CSV. Revisa el formato e inténtalo de nuevo."),
        "csvImportPartialLabel": m3,
        "csvImportSuccessLabel": m4,
        "customActivityDescription": MessageLookupByLibrary.simpleMessage(
            "Introduce directamente las calorías quemadas, para entrenamientos que no están en la lista o lecturas de una pulsera de actividad"),
        "customActivityDescriptionKj": MessageLookupByLibrary.simpleMessage(
            "Introduce directamente los kilojulios quemados, para entrenamientos que no están en la lista o lecturas de una pulsera de actividad"),
        "customActivityKcalHint": MessageLookupByLibrary.simpleMessage(
            "p. ej., 250"),
        "customActivityKcalLabel": MessageLookupByLibrary.simpleMessage(
            "Calorías quemadas"),
        "customActivityName": MessageLookupByLibrary.simpleMessage(
            "Actividad personalizada"),
        "customActivityNameFieldHint": MessageLookupByLibrary.simpleMessage(
            "p. ej., vuelta en bici al trabajo"),
        "customActivityNameFieldLabel": MessageLookupByLibrary.simpleMessage(
            "Nombre (opcional)"),
        "customActivityPickFromTemplate": MessageLookupByLibrary.simpleMessage(
            "Elegir de las plantillas guardadas"),
        "customActivitySaveAsTemplate": MessageLookupByLibrary.simpleMessage(
            "Guardar como plantilla para la próxima vez"),
        "customActivityTemplatesEmpty": MessageLookupByLibrary.simpleMessage(
            "Aún no has guardado ninguna plantilla. Marca \"Guardar como plantilla para la próxima vez\" para recordar una actividad personalizada más adelante."),
        "customMealBarcodeHint": MessageLookupByLibrary.simpleMessage(
            "Escanea o escribe un código de barras para recuperar este alimento más adelante"),
        "customMealBarcodeInvalid": MessageLookupByLibrary.simpleMessage(
            "El código de barras debe tener entre 8 y 14 dígitos"),
        "customMealBarcodeLabel": MessageLookupByLibrary.simpleMessage(
            "Código de barras"),
        "customMealBarcodeScanButton": MessageLookupByLibrary.simpleMessage(
            "Escanear código de barras"),
        "customMealFormAdvanced": MessageLookupByLibrary.simpleMessage(
            "Avanzado"),
        "customMealFormAdvancedHelp": MessageLookupByLibrary.simpleMessage(
            "Define la cantidad base y los valores por 100 para escalar con precisión."),
        "customMealFormModeLabel": MessageLookupByLibrary.simpleMessage(
            "Vista del formulario"),
        "customMealFormSimple": MessageLookupByLibrary.simpleMessage(
            "Sencillo"),
        "customMealFormSimpleFieldHelper": m5,
        "customMealFormSimpleHelp": MessageLookupByLibrary.simpleMessage(
            "Escribe los totales de una ración."),
        "customMealsDeleteConfirmContent": MessageLookupByLibrary.simpleMessage(
            "También se eliminarán todas las entradas del diario que usen este alimento."),
        "customMealsDeleteConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar alimento personalizado?"),
        "customMealsEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Aún no has guardado alimentos personalizados."),
        "customMealsMergeAction": MessageLookupByLibrary.simpleMessage(
            "Combinar con otro alimento personalizado"),
        "customMealsMergeChooseSurvivorTitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuál se queda?"),
        "customMealsMergeConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Combinar"),
        "customMealsMergeConfirmContent": m6,
        "customMealsMergeConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Combinar alimentos personalizados?"),
        "customMealsMergeContinueAction": MessageLookupByLibrary.simpleMessage(
            "Continuar"),
        "customMealsMergePickerTitle": MessageLookupByLibrary.simpleMessage(
            "Elige el alimento personalizado con el que combinar"),
        "customMealsMergeSuccessSnackbarOne": m7,
        "customMealsMergeSuccessSnackbarOther": m8,
        "customMealsRowMoreTooltip": MessageLookupByLibrary.simpleMessage(
            "Más acciones"),
        "dailyKcalAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajuste diario de kcal:"),
        "dailyKjAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajuste diario de kJ:"),
        "dataCollectionLabel": MessageLookupByLibrary.simpleMessage(
            "Enviar informes de errores anónimos para ayudar a corregir fallos. No se incluye tu registro de comidas, tu peso ni ningún dato personal."),
        "dayCopiedSnackbar": m9,
        "deleteAllLabel": MessageLookupByLibrary.simpleMessage(
            "Eliminar todo"),
        "deleteSelectedRecipesConfirmTitle": m10,
        "deleteTimeDialogContent": MessageLookupByLibrary.simpleMessage(
            "¿Quieres eliminar el elemento seleccionado?"),
        "deleteTimeDialogPluralContent": MessageLookupByLibrary.simpleMessage(
            "¿Quieres eliminar todos los elementos de esta comida?"),
        "deleteTimeDialogPluralTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar elementos?"),
        "deleteTimeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar elemento?"),
        "dialogCancelLabel": MessageLookupByLibrary.simpleMessage(
            "CANCELAR"),
        "dialogCloseLabel": MessageLookupByLibrary.simpleMessage(
            "Cerrar"),
        "dialogCopyLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar a hoy"),
        "dialogDeleteLabel": MessageLookupByLibrary.simpleMessage(
            "ELIMINAR"),
        "dialogOKLabel": MessageLookupByLibrary.simpleMessage(
            "Aceptar"),
        "diaryFutureDateWarning": MessageLookupByLibrary.simpleMessage(
            "Estás editando una fecha futura"),
        "diaryLabel": MessageLookupByLibrary.simpleMessage(
            "Diario"),
        "diaryMealKcalConsumedOfTarget": m11,
        "diaryNutrientPanelDataDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Aquí solo se suman los nutrientes registrados en las comidas que has anotado. Una comida sin un valor no aporta nada a ese nutriente, así que estos totales pueden quedarse cortos."),
        "diaryNutrientPanelTitle": MessageLookupByLibrary.simpleMessage(
            "Nutrientes de hoy"),
        "diarySortByCarbs": MessageLookupByLibrary.simpleMessage(
            "Carbohidratos (de más a menos)"),
        "diarySortByFat": MessageLookupByLibrary.simpleMessage(
            "Grasas (de más a menos)"),
        "diarySortByKcal": MessageLookupByLibrary.simpleMessage(
            "Calorías (de más a menos)"),
        "diarySortByLabel": MessageLookupByLibrary.simpleMessage(
            "Ordenar por"),
        "diarySortByProtein": MessageLookupByLibrary.simpleMessage(
            "Proteínas (de más a menos)"),
        "diarySortByTime": MessageLookupByLibrary.simpleMessage(
            "Hora de registro"),
        "diaryWeeklyBarsTitle": MessageLookupByLibrary.simpleMessage(
            "Esta semana"),
        "dinnerExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., sopa, pollo, vino..."),
        "dinnerLabel": MessageLookupByLibrary.simpleMessage(
            "Cena"),
        "discardChangesConfirmLabel": MessageLookupByLibrary.simpleMessage(
            "Descartar"),
        "discardChangesContent": MessageLookupByLibrary.simpleMessage(
            "Se perderán los cambios sin guardar."),
        "discardChangesTitle": MessageLookupByLibrary.simpleMessage(
            "¿Descartar cambios?"),
        "disclaimerText": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker no es una aplicación médica. Los datos proporcionados no están validados y deben usarse con precaución. Mantén un estilo de vida saludable y consulta a un profesional si tienes cualquier problema. No se recomienda su uso durante una enfermedad, el embarazo o la lactancia. Para ver las fuentes revisadas por pares de cada cálculo, toca el icono de información en la pantalla de Inicio o de Perfil."),
        "downloadSampleCsvAction": MessageLookupByLibrary.simpleMessage(
            "Comidas de ejemplo (csv)"),
        "downloadSampleJsonAction": MessageLookupByLibrary.simpleMessage(
            "Comidas de ejemplo (json)"),
        "downloadSampleRecipesCsvAction": MessageLookupByLibrary.simpleMessage(
            "Recetas de ejemplo (csv)"),
        "downloadSampleRecipesJsonAction": MessageLookupByLibrary.simpleMessage(
            "Recetas de ejemplo (json)"),
        "driPanelInfoBody": MessageLookupByLibrary.simpleMessage(
            "Estas cantidades de referencia proceden de las ingestas dietéticas de referencia (DRI) del IOM para adultos y varían según la edad y el sexo. Son un punto de referencia, no un objetivo: tus necesidades pueden ser distintas."),
        "driPanelInfoLinkLabel": MessageLookupByLibrary.simpleMessage(
            "Fuente: IOM Dietary Reference Intakes"),
        "driPanelInfoTitle": MessageLookupByLibrary.simpleMessage(
            "Ingesta de referencia"),
        "driPanelReferenceLabel": m12,
        "duplicateMealDialogContent": MessageLookupByLibrary.simpleMessage(
            "Este alimento ya se ha añadido hoy a esta comida. ¿Añadirlo otra vez?"),
        "duplicateRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Duplicar"),
        "duplicateRecipeNameSuffix": MessageLookupByLibrary.simpleMessage(
            "(copia)"),
        "editItemDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Editar elemento"),
        "editMealLabel": MessageLookupByLibrary.simpleMessage(
            "Editar comida"),
        "editRecipeTitle": MessageLookupByLibrary.simpleMessage(
            "Editar receta"),
        "energyLabel": MessageLookupByLibrary.simpleMessage(
            "energía"),
        "energyLeftLabel": MessageLookupByLibrary.simpleMessage(
            "restantes"),
        "energyTooMuchLabel": MessageLookupByLibrary.simpleMessage(
            "de más"),
        "energyUnitKcalLabel": MessageLookupByLibrary.simpleMessage(
            "Kilocalorías (kcal)"),
        "energyUnitKjLabel": MessageLookupByLibrary.simpleMessage(
            "Kilojulios (kJ)"),
        "errorFetchingProductData": MessageLookupByLibrary.simpleMessage(
            "Error al obtener los datos del producto"),
        "errorLoadingActivities": MessageLookupByLibrary.simpleMessage(
            "Error al cargar las actividades"),
        "errorMealSave": MessageLookupByLibrary.simpleMessage(
            "Error al guardar la comida. ¿Has introducido bien la información?"),
        "errorOpeningBrowser": MessageLookupByLibrary.simpleMessage(
            "Error al abrir el navegador"),
        "errorOpeningEmail": MessageLookupByLibrary.simpleMessage(
            "Error al abrir la aplicación de correo"),
        "errorProductNotFound": MessageLookupByLibrary.simpleMessage(
            "Producto no encontrado"),
        "exportAction": MessageLookupByLibrary.simpleMessage(
            "Exportar"),
        "exportImportAppDataLabel": MessageLookupByLibrary.simpleMessage(
            "Exportar / Importar datos de la app"),
        "exportImportCsvRecipesNote": MessageLookupByLibrary.simpleMessage(
            "El CSV conserva tus actividades, tu registro de comidas y los días registrados. Las recetas y las fotos que hayas adjuntado solo van en JSON; cambia a JSON si quieres incluirlas en la copia."),
        "exportImportDescription": MessageLookupByLibrary.simpleMessage(
            "Puedes exportar los datos de la app a un archivo zip e importarlos más tarde. Es útil si quieres hacer una copia de seguridad de tus datos o pasarlos a otro dispositivo.\n\nLa app no usa ningún servicio en la nube para guardar tus datos."),
        "exportImportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error al exportar / importar"),
        "exportImportIncludeProgressPhotosLabel": MessageLookupByLibrary.simpleMessage(
            "Incluir fotos de progreso"),
        "exportImportSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Exportación / importación correcta"),
        "fastingAddPast": MessageLookupByLibrary.simpleMessage(
            "Añadir ayuno pasado"),
        "fastingCancel": MessageLookupByLibrary.simpleMessage(
            "Terminar ayuno"),
        "fastingCancelConfirmBody": MessageLookupByLibrary.simpleMessage(
            "Esto cerrará la sesión actual."),
        "fastingCancelConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Terminar el ayuno ahora?"),
        "fastingComplete": MessageLookupByLibrary.simpleMessage(
            "Sesión completada"),
        "fastingDeleteBody": MessageLookupByLibrary.simpleMessage(
            "El registro se eliminará de tu historial."),
        "fastingDeleteTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar este ayuno?"),
        "fastingEditStart": MessageLookupByLibrary.simpleMessage(
            "Editar hora de inicio"),
        "fastingElapsedLabel": MessageLookupByLibrary.simpleMessage(
            "Transcurrido"),
        "fastingEndNow": MessageLookupByLibrary.simpleMessage(
            "Ahora mismo"),
        "fastingEndPick": MessageLookupByLibrary.simpleMessage(
            "Elegir la hora"),
        "fastingEndTitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuándo comiste?"),
        "fastingEndedSummary": m13,
        "fastingErrorEndBeforeStart": MessageLookupByLibrary.simpleMessage(
            "El fin debe ser posterior al inicio."),
        "fastingErrorEndInFuture": MessageLookupByLibrary.simpleMessage(
            "El fin no puede estar en el futuro."),
        "fastingErrorOverlaps": MessageLookupByLibrary.simpleMessage(
            "Se solapa con otro ayuno de tu historial."),
        "fastingErrorStartInFuture": MessageLookupByLibrary.simpleMessage(
            "El inicio no puede estar en el futuro."),
        "fastingErrorTarget": m14,
        "fastingErrorTooLong": MessageLookupByLibrary.simpleMessage(
            "Un registro no puede durar más de 7 días."),
        "fastingExtendedAccept": MessageLookupByLibrary.simpleMessage(
            "Un médico me está supervisando"),
        "fastingExtendedBody": MessageLookupByLibrary.simpleMessage(
            "Los ayunos de más de 24 horas conllevan más riesgos: bajadas de azúcar, deshidratación, desequilibrios de sales y problemas al volver a comer. Hazlos solo bajo supervisión médica."),
        "fastingExtendedTitle": MessageLookupByLibrary.simpleMessage(
            "Ayunos de más de 24 horas"),
        "fastingHistoryEmpty": MessageLookupByLibrary.simpleMessage(
            "Aún no hay ayunos registrados."),
        "fastingHistorySummary": m15,
        "fastingHistoryTitle": MessageLookupByLibrary.simpleMessage(
            "Historial"),
        "fastingHomeChipBody": m16,
        "fastingHomeChipReached": m17,
        "fastingLinkBastyr": MessageLookupByLibrary.simpleMessage(
            "Bastyr University: cuándo evitar el ayuno intermitente"),
        "fastingLinkBeat": MessageLookupByLibrary.simpleMessage(
            "BEAT (Reino Unido)"),
        "fastingLinkNeda": MessageLookupByLibrary.simpleMessage(
            "NEDA (EE. UU.)"),
        "fastingLinkWashU": MessageLookupByLibrary.simpleMessage(
            "WashU Physicians: guía sobre el ayuno intermitente"),
        "fastingNotMedicalAdvice": MessageLookupByLibrary.simpleMessage(
            "Este temporizador no es consejo médico. Fuentes:"),
        "fastingNotificationChannelDescription": MessageLookupByLibrary.simpleMessage(
            "Avisos puntuales cuando una sesión de ayuno alcanza su objetivo."),
        "fastingNotificationChannelName": MessageLookupByLibrary.simpleMessage(
            "Temporizador de ayuno"),
        "fastingNotificationCompleteBody": MessageLookupByLibrary.simpleMessage(
            "Has alcanzado el tiempo objetivo."),
        "fastingNotificationCompleteTitle": MessageLookupByLibrary.simpleMessage(
            "Sesión de ayuno completada"),
        "fastingOver24Notice": MessageLookupByLibrary.simpleMessage(
            "Llevas más de 24 horas en ayuno. Los ayunos tan largos deben estar supervisados por un médico. Bebe agua y termina el ayuno si te encuentras mal."),
        "fastingOver72Notice": MessageLookupByLibrary.simpleMessage(
            "Esta sesión lleva abierta más de 3 días. Si ya has comido, termínala e indica la hora a la que comiste."),
        "fastingPastTarget": m18,
        "fastingPresetCustom": MessageLookupByLibrary.simpleMessage(
            "Personalizado"),
        "fastingRecordAddTitle": MessageLookupByLibrary.simpleMessage(
            "Añadir ayuno"),
        "fastingRecordEditTitle": MessageLookupByLibrary.simpleMessage(
            "Editar ayuno"),
        "fastingRecordEnd": MessageLookupByLibrary.simpleMessage(
            "Fin"),
        "fastingRecordStart": MessageLookupByLibrary.simpleMessage(
            "Inicio"),
        "fastingRecordTarget": MessageLookupByLibrary.simpleMessage(
            "Objetivo (horas)"),
        "fastingRemainingValue": m19,
        "fastingSafetyTitle": MessageLookupByLibrary.simpleMessage(
            "Ayunar con seguridad"),
        "fastingSafetyTooltip": MessageLookupByLibrary.simpleMessage(
            "Seguridad del ayuno"),
        "fastingStart": MessageLookupByLibrary.simpleMessage(
            "Iniciar temporizador"),
        "fastingStartedAt": m20,
        "fastingStopIfUnwell": MessageLookupByLibrary.simpleMessage(
            "Para y come si notas mareo, debilidad, temblores, confusión o malestar. Busca ayuda médica si no se te pasa."),
        "fastingSubtitle": MessageLookupByLibrary.simpleMessage(
            "Un temporizador para el tiempo entre comidas, con tu propio historial. Sin rachas ni puntuaciones."),
        "fastingTargetReached": MessageLookupByLibrary.simpleMessage(
            "Objetivo alcanzado"),
        "fastingTargetValue": m21,
        "fastingTitle": MessageLookupByLibrary.simpleMessage(
            "Temporizador de ayuno"),
        "fastingWarningAccept": MessageLookupByLibrary.simpleMessage(
            "Lo entiendo, activar el temporizador"),
        "fastingWarningBody": MessageLookupByLibrary.simpleMessage(
            "Controlar el tiempo de ayuno puede ayudar a algunas personas y perjudicar a otras, sobre todo a quienes tienen antecedentes de trastornos de la conducta alimentaria. Si es tu caso, cuídate primero. Puedes encontrar apoyo en BEAT (Reino Unido) y NEDA (EE. UU.)."),
        "fastingWarningDecline": MessageLookupByLibrary.simpleMessage(
            "No es para mí"),
        "fastingWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Antes de empezar"),
        "fastingWarningWhoList": MessageLookupByLibrary.simpleMessage(
            "• eres menor de 18 años\n• estás embarazada o dando el pecho\n• tienes diabetes o tomas medicamentos que bajan el azúcar en sangre\n• tienes o has tenido un trastorno de la conducta alimentaria\n• tienes bajo peso\n• tienes otra enfermedad o tomas medicación de forma habitual"),
        "fastingWarningWhoTitle": MessageLookupByLibrary.simpleMessage(
            "Habla con un médico antes de ayunar si:"),
        "fatLabel": MessageLookupByLibrary.simpleMessage(
            "grasas"),
        "fatLabelShort": MessageLookupByLibrary.simpleMessage(
            "g"),
        "fiberLabel": MessageLookupByLibrary.simpleMessage(
            "fibra"),
        "flOzUnit": MessageLookupByLibrary.simpleMessage(
            "fl.oz"),
        "ftLabel": MessageLookupByLibrary.simpleMessage(
            "ft"),
        "genderFemaleLabel": MessageLookupByLibrary.simpleMessage(
            "mujer"),
        "genderLabel": MessageLookupByLibrary.simpleMessage(
            "Sexo"),
        "genderMaleLabel": MessageLookupByLibrary.simpleMessage(
            "hombre"),
        "genderNonBinaryLabel": MessageLookupByLibrary.simpleMessage(
            "no binario"),
        "goalGainWeight": MessageLookupByLibrary.simpleMessage(
            "Ganar peso"),
        "goalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo"),
        "goalLoseWeight": MessageLookupByLibrary.simpleMessage(
            "Perder peso"),
        "goalMaintainWeight": MessageLookupByLibrary.simpleMessage(
            "Mantener peso"),
        "gramMilliliterUnit": MessageLookupByLibrary.simpleMessage(
            "g/ml"),
        "gramUnit": MessageLookupByLibrary.simpleMessage(
            "g"),
        "heightLabel": MessageLookupByLibrary.simpleMessage(
            "Altura"),
        "homeBodyMetricsCardTitle": MessageLookupByLibrary.simpleMessage(
            "Medidas corporales"),
        "homeBodyMetricsInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra una medida corporal en Perfil para ver tus proporciones."),
        "homeEnergyBalanceLabel": MessageLookupByLibrary.simpleMessage(
            "Balance energético"),
        "homeExpenditureCardTitle": MessageLookupByLibrary.simpleMessage(
            "Últimos 7 días"),
        "homeExpenditureInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra al menos una semana de pesajes y comidas para ver tu gasto semanal."),
        "homeExpenditureLabel": MessageLookupByLibrary.simpleMessage(
            "Gasto"),
        "homeGoalProgressCardTitle": MessageLookupByLibrary.simpleMessage(
            "Progreso del objetivo"),
        "homeGoalProgressInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra al menos una semana de pesajes para ver el progreso de tu objetivo."),
        "homeLabel": MessageLookupByLibrary.simpleMessage(
            "Inicio"),
        "homeLoggingHabitCardTitle": MessageLookupByLibrary.simpleMessage(
            "Hábito de registro"),
        "homeWeighInHabitCardTitle": MessageLookupByLibrary.simpleMessage(
            "Hábito de pesaje"),
        "homeWeightTrendLabel": MessageLookupByLibrary.simpleMessage(
            "Peso de tendencia"),
        "homeWeightTrendNoRecentData": MessageLookupByLibrary.simpleMessage(
            "Sin pesajes en los últimos 20 días"),
        "homeWeightTrendRate": m22,
        "homeWeightTrendStable": MessageLookupByLibrary.simpleMessage(
            "Estable"),
        "hoursLabel": MessageLookupByLibrary.simpleMessage(
            "horas"),
        "importAction": MessageLookupByLibrary.simpleMessage(
            "Importar"),
        "importActivityConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Estas actividades se añadirán a hoy."),
        "importActivityConfirmTitle": m23,
        "importActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Importar entrenamiento compartido"),
        "importActivitySuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Entrenamiento importado"),
        "importCustomFoodDataDescription": MessageLookupByLibrary.simpleMessage(
            "Importa tus propios alimentos desde un archivo CSV o pegando JSON. Descarga un ejemplo para ver la estructura esperada y los campos obligatorios."),
        "importCustomFoodDataLabel": MessageLookupByLibrary.simpleMessage(
            "Importar alimentos personalizados"),
        "importMealConfirmContent": m24,
        "importMealConfirmTitle": m25,
        "importMealErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Código QR no válido"),
        "importMealLabel": MessageLookupByLibrary.simpleMessage(
            "Importar comida compartida"),
        "importMealSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Comida importada"),
        "importMealsCsvAction": MessageLookupByLibrary.simpleMessage(
            "Importar comidas (csv)"),
        "importMealsJsonAction": MessageLookupByLibrary.simpleMessage(
            "Importar comidas (json)"),
        "importOffFetchFailedLabel": m26,
        "importRecipeConfirmContent": m27,
        "importRecipeErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No se ha podido leer el código de la receta"),
        "importRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Importar receta"),
        "importRecipeSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Receta importada"),
        "importRecipesCsvAction": MessageLookupByLibrary.simpleMessage(
            "Importar recetas (csv)"),
        "importRecipesJsonAction": MessageLookupByLibrary.simpleMessage(
            "Importar recetas (json)"),
        "inLabel": MessageLookupByLibrary.simpleMessage(
            "in"),
        "inconsistentNutritionWarningBody": MessageLookupByLibrary.simpleMessage(
            "Estos valores no acaban de cuadrar: las calorías que has introducido no coinciden con la energía de los carbohidratos, grasas y proteínas de abajo. ¿Guardar de todos modos o echar otro vistazo?"),
        "inconsistentNutritionWarningEdit": MessageLookupByLibrary.simpleMessage(
            "Echar otro vistazo"),
        "inconsistentNutritionWarningSaveAnyway": MessageLookupByLibrary.simpleMessage(
            "Guardar de todos modos"),
        "inconsistentNutritionWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Los números no acaban de cuadrar"),
        "infoAddedActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Actividad añadida"),
        "infoAddedIntakeLabel": MessageLookupByLibrary.simpleMessage(
            "Ingesta añadida"),
        "ironLabel": MessageLookupByLibrary.simpleMessage(
            "hierro"),
        "itemDeletedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Elemento eliminado"),
        "itemMovedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Elemento movido"),
        "itemUpdatedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Elemento actualizado"),
        "kcalLabel": MessageLookupByLibrary.simpleMessage(
            "kcal"),
        "kcalLeftLabel": MessageLookupByLibrary.simpleMessage(
            "kcal restantes"),
        "kcalTooMuchLabel": MessageLookupByLibrary.simpleMessage(
            "kcal de más"),
        "kgLabel": MessageLookupByLibrary.simpleMessage(
            "kg"),
        "kjLabel": MessageLookupByLibrary.simpleMessage(
            "kJ"),
        "lbsLabel": MessageLookupByLibrary.simpleMessage(
            "lbs"),
        "logWaterAmountLabel": m28,
        "logWaterDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Registrar agua"),
        "logWaterNothingToUndoLabel": MessageLookupByLibrary.simpleMessage(
            "No hay nada que deshacer"),
        "logWaterUndoLabel": MessageLookupByLibrary.simpleMessage(
            "Deshacer el último"),
        "lowKcalWarningBody": m29,
        "lowKcalWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Este objetivo diario es bastante bajo"),
        "lowKcalWarningViewDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Ver aviso legal"),
        "lunchExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., pizza, ensalada, arroz..."),
        "lunchLabel": MessageLookupByLibrary.simpleMessage(
            "Comida"),
        "macroDistributionLabel": MessageLookupByLibrary.simpleMessage(
            "Distribución de macronutrientes:"),
        "magicAddToDiaryButton": MessageLookupByLibrary.simpleMessage(
            "Añadir al diario"),
        "magicAddedToDiarySnackbar": MessageLookupByLibrary.simpleMessage(
            "Añadido al diario"),
        "magicAnalysisFailedError": MessageLookupByLibrary.simpleMessage(
            "No se ha podido analizar; inténtalo de nuevo"),
        "magicAnalyzeButton": MessageLookupByLibrary.simpleMessage(
            "Analizar"),
        "magicAnalyzingLabel": MessageLookupByLibrary.simpleMessage(
            "Analizando..."),
        "magicCameraButton": MessageLookupByLibrary.simpleMessage(
            "Cámara"),
        "magicDescribeFoodHint": MessageLookupByLibrary.simpleMessage(
            "Describe tu comida (opcional si hay foto)..."),
        "magicEmptyResultError": MessageLookupByLibrary.simpleMessage(
            "No se ha identificado ningún alimento"),
        "magicGalleryButton": MessageLookupByLibrary.simpleMessage(
            "Galería"),
        "magicMealBreakdownLabel": MessageLookupByLibrary.simpleMessage(
            "Desglose de la comida"),
        "magicModelLabel": MessageLookupByLibrary.simpleMessage(
            "Modelo"),
        "magicNoApiKeyError": MessageLookupByLibrary.simpleMessage(
            "Primero configura tu clave de API de OpenRouter en Ajustes"),
        "magicNoInputError": MessageLookupByLibrary.simpleMessage(
            "Primero añade una foto o describe tu comida"),
        "magicNoModelError": MessageLookupByLibrary.simpleMessage(
            "Primero elige un modelo"),
        "magicProviderLabel": MessageLookupByLibrary.simpleMessage(
            "Proveedor"),
        "magicResultsTitle": MessageLookupByLibrary.simpleMessage(
            "Resultados"),
        "magicScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Magia"),
        "magicSingleItemLabel": MessageLookupByLibrary.simpleMessage(
            "Un solo alimento"),
        "magnesiumLabel": MessageLookupByLibrary.simpleMessage(
            "magnesio"),
        "mealBrandsLabel": MessageLookupByLibrary.simpleMessage(
            "Marcas"),
        "mealCarbsLabel": MessageLookupByLibrary.simpleMessage(
            "Carbohidratos"),
        "mealDetailCurrentSelectionLabel": m30,
        "mealDetailDayTotalLabel": m31,
        "mealEnergyLabel": MessageLookupByLibrary.simpleMessage(
            "Energía"),
        "mealFatLabel": MessageLookupByLibrary.simpleMessage(
            "Grasas"),
        "mealImageLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir una foto"),
        "mealImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Elegir de la galería"),
        "mealImageRemove": MessageLookupByLibrary.simpleMessage(
            "Quitar foto"),
        "mealImageReplace": MessageLookupByLibrary.simpleMessage(
            "Cambiar foto"),
        "mealImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Hacer foto"),
        "mealKcalLabel": MessageLookupByLibrary.simpleMessage(
            "kcal"),
        "mealNameLabel": MessageLookupByLibrary.simpleMessage(
            "Nombre del alimento"),
        "mealNameValidationError": MessageLookupByLibrary.simpleMessage(
            "El nombre del alimento debe contener al menos una letra"),
        "mealNutrientsPerQtyLabel": m32,
        "mealNutrientsTotalLabel": MessageLookupByLibrary.simpleMessage(
            "Cantidad total"),
        "mealPatternFiveSmall": MessageLookupByLibrary.simpleMessage(
            "Cinco pequeñas"),
        "mealPatternMediterranean": MessageLookupByLibrary.simpleMessage(
            "Mediterráneo"),
        "mealPatternOmad": MessageLookupByLibrary.simpleMessage(
            "OMAD"),
        "mealPatternPresetsLabel": MessageLookupByLibrary.simpleMessage(
            "Opciones rápidas"),
        "mealPatternStandard": MessageLookupByLibrary.simpleMessage(
            "Estándar"),
        "mealPatternTwoMeal": MessageLookupByLibrary.simpleMessage(
            "Dos comidas"),
        "mealProteinLabel": MessageLookupByLibrary.simpleMessage(
            "Proteínas"),
        "mealSizeLabel": MessageLookupByLibrary.simpleMessage(
            "Tamaño de la ración (g/ml)"),
        "mealSizeLabelImperial": MessageLookupByLibrary.simpleMessage(
            "Tamaño de la ración (oz/fl oz)"),
        "mealUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unidad"),
        "micronutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Micronutrientes"),
        "milliliterUnit": MessageLookupByLibrary.simpleMessage(
            "ml"),
        "missingProductInfo": MessageLookupByLibrary.simpleMessage(
            "Al producto le faltan las kcal o los macronutrientes obligatorios"),
        "mlLabel": MessageLookupByLibrary.simpleMessage(
            "ml"),
        "monounsaturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "grasas monoinsaturadas"),
        "moveActionLabel": MessageLookupByLibrary.simpleMessage(
            "Mover"),
        "newCustomMealLabel": MessageLookupByLibrary.simpleMessage(
            "Nuevo alimento personalizado"),
        "niacinLabel": MessageLookupByLibrary.simpleMessage(
            "niacina (B3)"),
        "noActivityRecentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hay actividades añadidas recientemente"),
        "noMealsRecentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hay comidas añadidas recientemente"),
        "noResultsFound": MessageLookupByLibrary.simpleMessage(
            "No se han encontrado resultados"),
        "notAvailableLabel": MessageLookupByLibrary.simpleMessage(
            "N/D"),
        "nothingAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hay nada añadido"),
        "notificationsDailyReminderBody": MessageLookupByLibrary.simpleMessage(
            "¡No olvides registrar tus comidas de hoy!"),
        "notificationsDailyReminderChannelDescription": MessageLookupByLibrary.simpleMessage(
            "Recordatorio diario para registrar comidas"),
        "notificationsDailyReminderChannelName": MessageLookupByLibrary.simpleMessage(
            "Recordatorios diarios"),
        "notificationsDailyReminderTitle": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker"),
        "notificationsPermissionDeniedSnack": MessageLookupByLibrary.simpleMessage(
            "Permiso de notificaciones denegado."),
        "nutrientPanelAllHiddenLabel": MessageLookupByLibrary.simpleMessage(
            "Todos los nutrientes están ocultos: activa alguno en Ajustes → Nutrientes."),
        "nutrientPanelDayLabel": MessageLookupByLibrary.simpleMessage(
            "Día"),
        "nutrientPanelLimitLabel": MessageLookupByLibrary.simpleMessage(
            "límite"),
        "nutrientPanelWeekLabel": MessageLookupByLibrary.simpleMessage(
            "Semana"),
        "nutritionInfoLabel": MessageLookupByLibrary.simpleMessage(
            "Información nutricional"),
        "nutritionalStatusNormalWeight": MessageLookupByLibrary.simpleMessage(
            "Peso normal"),
        "nutritionalStatusObeseClassI": MessageLookupByLibrary.simpleMessage(
            "Obesidad de clase I"),
        "nutritionalStatusObeseClassII": MessageLookupByLibrary.simpleMessage(
            "Obesidad de clase II"),
        "nutritionalStatusObeseClassIII": MessageLookupByLibrary.simpleMessage(
            "Obesidad de clase III"),
        "nutritionalStatusPreObesity": MessageLookupByLibrary.simpleMessage(
            "Preobesidad"),
        "nutritionalStatusRiskAverage": MessageLookupByLibrary.simpleMessage(
            "Medio"),
        "nutritionalStatusRiskIncreased": MessageLookupByLibrary.simpleMessage(
            "Aumentado"),
        "nutritionalStatusRiskLabel": m33,
        "nutritionalStatusRiskLow": MessageLookupByLibrary.simpleMessage(
            "Bajo \n(pero con mayor riesgo de otros \nproblemas clínicos)"),
        "nutritionalStatusRiskModerate": MessageLookupByLibrary.simpleMessage(
            "Moderado"),
        "nutritionalStatusRiskSevere": MessageLookupByLibrary.simpleMessage(
            "Grave"),
        "nutritionalStatusRiskVerySevere": MessageLookupByLibrary.simpleMessage(
            "Muy grave"),
        "nutritionalStatusUnderweight": MessageLookupByLibrary.simpleMessage(
            "Bajo peso"),
        "offAccountCreateLink": MessageLookupByLibrary.simpleMessage(
            "Crear una cuenta gratuita"),
        "offAccountExplanation": MessageLookupByLibrary.simpleMessage(
            "Usa tu nombre de usuario de Open Food Facts (no tu correo) y tu contraseña. Se guardan cifrados en este dispositivo y solo se envían a Open Food Facts cuando envías un producto."),
        "offAccountLabel": MessageLookupByLibrary.simpleMessage(
            "Cuenta de Open Food Facts"),
        "offAccountPasswordLabel": MessageLookupByLibrary.simpleMessage(
            "Contraseña"),
        "offAccountSignOut": MessageLookupByLibrary.simpleMessage(
            "Cerrar sesión"),
        "offAccountSignedInAs": MessageLookupByLibrary.simpleMessage(
            "Sesión iniciada como"),
        "offAccountSignedOutSubtitle": MessageLookupByLibrary.simpleMessage(
            "Inicia sesión para enviar a Open Food Facts los productos que añadas"),
        "offAccountUsernameLabel": MessageLookupByLibrary.simpleMessage(
            "Nombre de usuario"),
        "offContributeAlreadyOnOff": MessageLookupByLibrary.simpleMessage(
            "Open Food Facts ya tiene este producto, así que no se ha enviado nada."),
        "offContributeButton": MessageLookupByLibrary.simpleMessage(
            "Enviar a Open Food Facts"),
        "offContributeConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Esto crea un producto público nuevo en Open Food Facts con este código de barras, nombre, marca y los valores nutricionales por 100 g. Envía solo valores copiados de la etiqueta del envase. Las contribuciones se publican bajo la Open Database License (ODbL), así que cualquiera puede reutilizarlas."),
        "offContributeConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Enviar a Open Food Facts?"),
        "offContributeFailed": MessageLookupByLibrary.simpleMessage(
            "No se ha podido enviar el producto a Open Food Facts. Inténtalo de nuevo más tarde."),
        "offContributeMissingData": MessageLookupByLibrary.simpleMessage(
            "Para enviar un producto se necesita código de barras, nombre y energía."),
        "offContributeNeedsAccount": MessageLookupByLibrary.simpleMessage(
            "Primero inicia sesión con tu cuenta de Open Food Facts."),
        "offContributeSend": MessageLookupByLibrary.simpleMessage(
            "Enviar"),
        "offContributeSent": MessageLookupByLibrary.simpleMessage(
            "¡Gracias! El producto ya está en Open Food Facts."),
        "offContributeWrongCredentials": MessageLookupByLibrary.simpleMessage(
            "Open Food Facts ha rechazado tu nombre de usuario o tu contraseña."),
        "offDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Los datos que te ofrece esta app proceden de la base de datos de Open Food Facts. No se puede garantizar la exactitud, integridad ni fiabilidad de la información proporcionada. Los datos se ofrecen \"tal cual\" y la fuente de origen de los datos (Open Food Facts) no se hace responsable de ningún daño derivado de su uso."),
        "onboardingActivityQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuánto te mueves? (sin contar entrenamientos)"),
        "onboardingBirthdayHint": MessageLookupByLibrary.simpleMessage(
            "Introduce la fecha"),
        "onboardingBirthdayQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuándo es tu cumpleaños?"),
        "onboardingEnterBirthdayLabel": MessageLookupByLibrary.simpleMessage(
            "Fecha de nacimiento"),
        "onboardingGenderQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuál es tu sexo?"),
        "onboardingGoalQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuál es tu objetivo de peso actual?"),
        "onboardingHeightExampleHintCm": MessageLookupByLibrary.simpleMessage(
            "p. ej., 170"),
        "onboardingHeightExampleHintFt": MessageLookupByLibrary.simpleMessage(
            "p. ej., 5.8"),
        "onboardingHeightQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuánto mides?"),
        "onboardingIntroDescription": MessageLookupByLibrary.simpleMessage(
            "Para empezar, la app necesita algunos datos sobre ti para calcular tu objetivo diario de calorías.\nToda tu información se guarda de forma segura en tu dispositivo."),
        "onboardingIntroSourcesLinkLabel": MessageLookupByLibrary.simpleMessage(
            "Consulta nuestras fuentes para los cálculos médicos"),
        "onboardingKcalPerDayLabel": MessageLookupByLibrary.simpleMessage(
            "kcal al día"),
        "onboardingKjPerDayLabel": MessageLookupByLibrary.simpleMessage(
            "kJ al día"),
        "onboardingNonBinaryDisclaimer": MessageLookupByLibrary.simpleMessage(
            "No existe una referencia calórica publicada para personas no binarias, así que por defecto usamos la media de las fórmulas masculina y femenina: un punto de partida, no una estimación precisa. Puedes afinarlo cuando quieras en Ajustes → Cálculos."),
        "onboardingOverviewLabel": MessageLookupByLibrary.simpleMessage(
            "Resumen"),
        "onboardingRestoreFromCloudLabel": MessageLookupByLibrary.simpleMessage(
            "¿Ya tienes una copia en la nube? Restáurala"),
        "onboardingSaveUserError": MessageLookupByLibrary.simpleMessage(
            "Datos incorrectos, inténtalo de nuevo"),
        "onboardingTargetWeightHintOptional": MessageLookupByLibrary.simpleMessage(
            "Opcional"),
        "onboardingTargetWeightSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Tienes un peso objetivo? Puedes dejarlo en blanco o cambiarlo más tarde en Perfil."),
        "onboardingWeightExampleHintKg": MessageLookupByLibrary.simpleMessage(
            "p. ej., 60"),
        "onboardingWeightExampleHintLbs": MessageLookupByLibrary.simpleMessage(
            "p. ej., 132"),
        "onboardingWeightQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "¿Cuánto pesas ahora?"),
        "onboardingWelcomeLabel": MessageLookupByLibrary.simpleMessage(
            "Te damos la bienvenida a"),
        "onboardingWrongHeightLabel": MessageLookupByLibrary.simpleMessage(
            "Introduce una altura correcta"),
        "onboardingWrongWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Introduce un peso correcto"),
        "onboardingYourGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Tu objetivo de calorías:"),
        "onboardingYourMacrosGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Tus objetivos de macronutrientes:"),
        "openRouterApiKeyHint": MessageLookupByLibrary.simpleMessage(
            "sk-or-..."),
        "openRouterApiKeyLabel": MessageLookupByLibrary.simpleMessage(
            "Clave de API"),
        "openRouterApiKeySavedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Clave de API guardada"),
        "openRouterModelSearchHint": MessageLookupByLibrary.simpleMessage(
            "Buscar modelos"),
        "openRouterModelSectionTitle": MessageLookupByLibrary.simpleMessage(
            "Modelo"),
        "openRouterModelsEmptyState": MessageLookupByLibrary.simpleMessage(
            "Ningún modelo coincide con tu búsqueda"),
        "openRouterModelsLoadError": MessageLookupByLibrary.simpleMessage(
            "No se ha podido cargar el catálogo de modelos"),
        "openRouterSettingsTitle": MessageLookupByLibrary.simpleMessage(
            "OpenRouter"),
        "openRouterVisionBadgeTooltip": MessageLookupByLibrary.simpleMessage(
            "Admite imágenes"),
        "ozUnit": MessageLookupByLibrary.simpleMessage(
            "oz"),
        "paActiveVideoGames": MessageLookupByLibrary.simpleMessage(
            "videojuegos activos"),
        "paActiveVideoGamesDesc": MessageLookupByLibrary.simpleMessage(
            "Wii Sports, Dance Dance Revolution, general"),
        "paAmericanFootballGeneral": MessageLookupByLibrary.simpleMessage(
            "fútbol americano"),
        "paAmericanFootballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "touch, flag, general"),
        "paArcheryGeneral": MessageLookupByLibrary.simpleMessage(
            "tiro con arco"),
        "paArcheryGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sin caza"),
        "paAutoRacing": MessageLookupByLibrary.simpleMessage(
            "carreras de coches"),
        "paAutoRacingDesc": MessageLookupByLibrary.simpleMessage(
            "monoplaza"),
        "paBackpackingGeneral": MessageLookupByLibrary.simpleMessage(
            "senderismo con mochila"),
        "paBackpackingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBadmintonGeneral": MessageLookupByLibrary.simpleMessage(
            "bádminton"),
        "paBadmintonGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "individual y dobles recreativo, general"),
        "paBasketballGeneral": MessageLookupByLibrary.simpleMessage(
            "baloncesto"),
        "paBasketballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingGeneral": MessageLookupByLibrary.simpleMessage(
            "ciclismo"),
        "paBicyclingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingMountainGeneral": MessageLookupByLibrary.simpleMessage(
            "ciclismo de montaña"),
        "paBicyclingMountainGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingStationaryGeneral": MessageLookupByLibrary.simpleMessage(
            "bicicleta estática"),
        "paBicyclingStationaryGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBilliardsGeneral": MessageLookupByLibrary.simpleMessage(
            "billar"),
        "paBilliardsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBowlingGeneral": MessageLookupByLibrary.simpleMessage(
            "bolos"),
        "paBowlingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBoxingBag": MessageLookupByLibrary.simpleMessage(
            "boxeo"),
        "paBoxingBagDesc": MessageLookupByLibrary.simpleMessage(
            "saco de boxeo"),
        "paBoxingGeneral": MessageLookupByLibrary.simpleMessage(
            "boxeo"),
        "paBoxingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "en ring, general"),
        "paBroomball": MessageLookupByLibrary.simpleMessage(
            "broomball"),
        "paBroomballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paCalisthenicsGeneral": MessageLookupByLibrary.simpleMessage(
            "calistenia"),
        "paCalisthenicsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "esfuerzo ligero o moderado, general (p. ej., ejercicios de espalda)"),
        "paCanoeingGeneral": MessageLookupByLibrary.simpleMessage(
            "piragüismo"),
        "paCanoeingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "remo recreativo, general"),
        "paCatch": MessageLookupByLibrary.simpleMessage(
            "fútbol americano o béisbol"),
        "paCatchDesc": MessageLookupByLibrary.simpleMessage(
            "pasarse la pelota"),
        "paCheerleading": MessageLookupByLibrary.simpleMessage(
            "cheerleading"),
        "paCheerleadingDesc": MessageLookupByLibrary.simpleMessage(
            "movimientos gimnásticos, de competición"),
        "paChildrenGame": MessageLookupByLibrary.simpleMessage(
            "juegos infantiles"),
        "paChildrenGameDesc": MessageLookupByLibrary.simpleMessage(
            "(p. ej., rayuela, cuatro cuadros, balón prisionero, columpios y toboganes, t-ball, tetherball, canicas, máquinas recreativas), esfuerzo moderado"),
        "paClimbingHillsNoLoadGeneral": MessageLookupByLibrary.simpleMessage(
            "subir cuestas, sin carga"),
        "paClimbingHillsNoLoadGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sin carga"),
        "paCricket": MessageLookupByLibrary.simpleMessage(
            "críquet"),
        "paCricketDesc": MessageLookupByLibrary.simpleMessage(
            "batear, lanzar, defender"),
        "paCroquet": MessageLookupByLibrary.simpleMessage(
            "cróquet"),
        "paCroquetDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paCrossCountrySkiing": MessageLookupByLibrary.simpleMessage(
            "esquí de fondo"),
        "paCrossCountrySkiingDesc": MessageLookupByLibrary.simpleMessage(
            "de fondo, general"),
        "paCurling": MessageLookupByLibrary.simpleMessage(
            "curling"),
        "paCurlingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paDancingAerobicGeneral": MessageLookupByLibrary.simpleMessage(
            "aeróbic"),
        "paDancingAerobicGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paDancingGeneral": MessageLookupByLibrary.simpleMessage(
            "baile en general"),
        "paDancingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "p. ej., disco, folclórico, claqué irlandés, baile en línea, polca, contradanza, country"),
        "paDartsWall": MessageLookupByLibrary.simpleMessage(
            "dardos"),
        "paDartsWallDesc": MessageLookupByLibrary.simpleMessage(
            "de pared o de césped"),
        "paDivingGeneral": MessageLookupByLibrary.simpleMessage(
            "buceo"),
        "paDivingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "buceo a pulmón, submarinismo, general"),
        "paDivingSpringboardPlatform": MessageLookupByLibrary.simpleMessage(
            "saltos"),
        "paDivingSpringboardPlatformDesc": MessageLookupByLibrary.simpleMessage(
            "trampolín o plataforma"),
        "paFencing": MessageLookupByLibrary.simpleMessage(
            "esgrima"),
        "paFencingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paFrisbee": MessageLookupByLibrary.simpleMessage(
            "frisbi"),
        "paFrisbeeDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paGolfGeneral": MessageLookupByLibrary.simpleMessage(
            "golf"),
        "paGolfGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paGymnasticsGeneral": MessageLookupByLibrary.simpleMessage(
            "gimnasia"),
        "paGymnasticsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHackySack": MessageLookupByLibrary.simpleMessage(
            "hacky sack"),
        "paHackySackDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHandballGeneral": MessageLookupByLibrary.simpleMessage(
            "balonmano"),
        "paHandballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHangGliding": MessageLookupByLibrary.simpleMessage(
            "ala delta"),
        "paHangGlidingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHeadingBicycling": MessageLookupByLibrary.simpleMessage(
            "ciclismo"),
        "paHeadingConditionalExercise": MessageLookupByLibrary.simpleMessage(
            "ejercicio de acondicionamiento"),
        "paHeadingDancing": MessageLookupByLibrary.simpleMessage(
            "baile"),
        "paHeadingRunning": MessageLookupByLibrary.simpleMessage(
            "correr"),
        "paHeadingSports": MessageLookupByLibrary.simpleMessage(
            "deportes"),
        "paHeadingWalking": MessageLookupByLibrary.simpleMessage(
            "caminar"),
        "paHeadingWaterActivities": MessageLookupByLibrary.simpleMessage(
            "actividades acuáticas"),
        "paHeadingWinterActivities": MessageLookupByLibrary.simpleMessage(
            "actividades de invierno"),
        "paHighIntensityIntervalExercise": MessageLookupByLibrary.simpleMessage(
            "ejercicio interválico de alta intensidad"),
        "paHighIntensityIntervalExerciseDesc": MessageLookupByLibrary.simpleMessage(
            "esfuerzo moderado"),
        "paHighIntensityIntervalExerciseVigorous": MessageLookupByLibrary.simpleMessage(
            "ejercicio interválico de alta intensidad"),
        "paHighIntensityIntervalExerciseVigorousDesc": MessageLookupByLibrary.simpleMessage(
            "burpees, escaladores, sentadillas con salto, Tabata, esfuerzo intenso"),
        "paHikingCrossCountry": MessageLookupByLibrary.simpleMessage(
            "senderismo"),
        "paHikingCrossCountryDesc": MessageLookupByLibrary.simpleMessage(
            "campo a través"),
        "paHockeyField": MessageLookupByLibrary.simpleMessage(
            "hockey sobre hierba"),
        "paHockeyFieldDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHorseRidingGeneral": MessageLookupByLibrary.simpleMessage(
            "equitación"),
        "paHorseRidingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paIceHockeyGeneral": MessageLookupByLibrary.simpleMessage(
            "hockey sobre hielo"),
        "paIceHockeyGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paIceSkatingGeneral": MessageLookupByLibrary.simpleMessage(
            "patinaje sobre hielo"),
        "paIceSkatingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJaiAlai": MessageLookupByLibrary.simpleMessage(
            "pelota vasca"),
        "paJaiAlaiDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJoggingGeneral": MessageLookupByLibrary.simpleMessage(
            "footing"),
        "paJoggingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJuggling": MessageLookupByLibrary.simpleMessage(
            "malabares"),
        "paJugglingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paKayakingModerate": MessageLookupByLibrary.simpleMessage(
            "kayak"),
        "paKayakingModerateDesc": MessageLookupByLibrary.simpleMessage(
            "esfuerzo moderado"),
        "paKickball": MessageLookupByLibrary.simpleMessage(
            "kickball"),
        "paKickballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paLacrosse": MessageLookupByLibrary.simpleMessage(
            "lacrosse"),
        "paLacrosseDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paLawnBowling": MessageLookupByLibrary.simpleMessage(
            "bochas"),
        "paLawnBowlingDesc": MessageLookupByLibrary.simpleMessage(
            "petanca, al aire libre"),
        "paMartialArtsModerate": MessageLookupByLibrary.simpleMessage(
            "artes marciales"),
        "paMartialArtsModerateDesc": MessageLookupByLibrary.simpleMessage(
            "distintos tipos, ritmo moderado (p. ej., judo, jiu-jitsu, kárate, kickboxing, taekwondo, tae bo, boxeo tailandés)"),
        "paMartialArtsSlower": MessageLookupByLibrary.simpleMessage(
            "artes marciales"),
        "paMartialArtsSlowerDesc": MessageLookupByLibrary.simpleMessage(
            "distintos tipos, ritmo más lento, principiantes, práctica"),
        "paMotoCross": MessageLookupByLibrary.simpleMessage(
            "motocross"),
        "paMotoCrossDesc": MessageLookupByLibrary.simpleMessage(
            "deportes de motor todoterreno, quad, general"),
        "paMountainClimbing": MessageLookupByLibrary.simpleMessage(
            "escalada"),
        "paMountainClimbingDesc": MessageLookupByLibrary.simpleMessage(
            "escalada en roca o alpinismo"),
        "paNordicWalking": MessageLookupByLibrary.simpleMessage(
            "marcha nórdica"),
        "paOrienteering": MessageLookupByLibrary.simpleMessage(
            "orientación"),
        "paOrienteeringDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paPaddleBoarding": MessageLookupByLibrary.simpleMessage(
            "paddle surf"),
        "paPaddleBoardingDesc": MessageLookupByLibrary.simpleMessage(
            "de pie"),
        "paPaddleBoat": MessageLookupByLibrary.simpleMessage(
            "barca a pedales"),
        "paPaddleBoatDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paPaddleball": MessageLookupByLibrary.simpleMessage(
            "paddleball"),
        "paPaddleballDesc": MessageLookupByLibrary.simpleMessage(
            "informal, general"),
        "paPickleball": MessageLookupByLibrary.simpleMessage(
            "pickleball"),
        "paPilates": MessageLookupByLibrary.simpleMessage(
            "pilates"),
        "paPoloHorse": MessageLookupByLibrary.simpleMessage(
            "polo"),
        "paPoloHorseDesc": MessageLookupByLibrary.simpleMessage(
            "a caballo"),
        "paRacquetball": MessageLookupByLibrary.simpleMessage(
            "ráquetbol"),
        "paRacquetballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paResistanceTraining": MessageLookupByLibrary.simpleMessage(
            "entrenamiento de fuerza"),
        "paResistanceTrainingDesc": MessageLookupByLibrary.simpleMessage(
            "levantamiento de pesas, peso libre, máquinas"),
        "paResistanceTrainingVigorous": MessageLookupByLibrary.simpleMessage(
            "entrenamiento de fuerza (intenso)"),
        "paResistanceTrainingVigorousDesc": MessageLookupByLibrary.simpleMessage(
            "esfuerzo intenso, powerlifting o culturismo"),
        "paRodeoSportGeneralModerate": MessageLookupByLibrary.simpleMessage(
            "deportes de rodeo"),
        "paRodeoSportGeneralModerateDesc": MessageLookupByLibrary.simpleMessage(
            "general, esfuerzo moderado"),
        "paRollerbladingLight": MessageLookupByLibrary.simpleMessage(
            "patines en línea"),
        "paRollerbladingLightDesc": MessageLookupByLibrary.simpleMessage(
            "patinaje en línea"),
        "paRopeJumpingGeneral": MessageLookupByLibrary.simpleMessage(
            "saltar a la comba"),
        "paRopeJumpingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "ritmo moderado, 100-120 saltos/min, general, salto con los dos pies, salto básico"),
        "paRopeSkippingGeneral": MessageLookupByLibrary.simpleMessage(
            "saltar a la comba"),
        "paRopeSkippingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paRugbyCompetitive": MessageLookupByLibrary.simpleMessage(
            "rugby"),
        "paRugbyCompetitiveDesc": MessageLookupByLibrary.simpleMessage(
            "union, en equipo, de competición"),
        "paRugbyNonCompetitive": MessageLookupByLibrary.simpleMessage(
            "rugby"),
        "paRugbyNonCompetitiveDesc": MessageLookupByLibrary.simpleMessage(
            "touch, sin competición"),
        "paRunningGeneral": MessageLookupByLibrary.simpleMessage(
            "correr"),
        "paRunningGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSailingGeneral": MessageLookupByLibrary.simpleMessage(
            "vela"),
        "paSailingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "vela en barco y tabla, windsurf, vela sobre hielo, general"),
        "paShuffleboard": MessageLookupByLibrary.simpleMessage(
            "shuffleboard"),
        "paShuffleboardDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkateboardingGeneral": MessageLookupByLibrary.simpleMessage(
            "monopatín"),
        "paSkateboardingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general, esfuerzo moderado"),
        "paSkatingRoller": MessageLookupByLibrary.simpleMessage(
            "patinaje sobre ruedas"),
        "paSkatingRollerDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkiingGeneral": MessageLookupByLibrary.simpleMessage(
            "esquí"),
        "paSkiingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkiingWaterWakeboarding": MessageLookupByLibrary.simpleMessage(
            "esquí acuático"),
        "paSkiingWaterWakeboardingDesc": MessageLookupByLibrary.simpleMessage(
            "esquí acuático o wakeboard"),
        "paSkydiving": MessageLookupByLibrary.simpleMessage(
            "paracaidismo"),
        "paSkydivingDesc": MessageLookupByLibrary.simpleMessage(
            "paracaidismo, salto BASE, puenting"),
        "paSnorkeling": MessageLookupByLibrary.simpleMessage(
            "esnórquel"),
        "paSnorkelingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSnowShovingModerate": MessageLookupByLibrary.simpleMessage(
            "quitar nieve con pala"),
        "paSnowShovingModerateDesc": MessageLookupByLibrary.simpleMessage(
            "a mano, esfuerzo moderado"),
        "paSnowshoeing": MessageLookupByLibrary.simpleMessage(
            "raquetas de nieve"),
        "paSoccerGeneral": MessageLookupByLibrary.simpleMessage(
            "fútbol"),
        "paSoccerGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "informal, general"),
        "paSoftballBaseballGeneral": MessageLookupByLibrary.simpleMessage(
            "sóftbol / béisbol"),
        "paSoftballBaseballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "lanzamiento rápido o lento, general"),
        "paSquashGeneral": MessageLookupByLibrary.simpleMessage(
            "squash"),
        "paSquashGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paStretching": MessageLookupByLibrary.simpleMessage(
            "estiramientos"),
        "paStretchingDesc": MessageLookupByLibrary.simpleMessage(
            "suaves, general"),
        "paSurfing": MessageLookupByLibrary.simpleMessage(
            "surf"),
        "paSurfingDesc": MessageLookupByLibrary.simpleMessage(
            "bodyboard o tabla, general"),
        "paSwimmingGeneral": MessageLookupByLibrary.simpleMessage(
            "natación"),
        "paSwimmingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "mantenerse a flote, esfuerzo moderado, general"),
        "paTableTennisGeneral": MessageLookupByLibrary.simpleMessage(
            "tenis de mesa"),
        "paTableTennisGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "tenis de mesa, ping-pong"),
        "paTaiChiQiGongGeneral": MessageLookupByLibrary.simpleMessage(
            "taichí, qigong"),
        "paTaiChiQiGongGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paTennisGeneral": MessageLookupByLibrary.simpleMessage(
            "tenis"),
        "paTennisGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paTrackField": MessageLookupByLibrary.simpleMessage(
            "atletismo"),
        "paTrackField1Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ej., peso, disco, martillo)"),
        "paTrackField2Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ej., salto de altura, salto de longitud, triple salto, jabalina, salto con pértiga)"),
        "paTrackField3Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ej., carrera de obstáculos, vallas)"),
        "paTrampolineLight": MessageLookupByLibrary.simpleMessage(
            "cama elástica"),
        "paTrampolineLightDesc": MessageLookupByLibrary.simpleMessage(
            "recreativo"),
        "paTreadmillRunning": MessageLookupByLibrary.simpleMessage(
            "correr en cinta"),
        "paTreadmillRunningDesc": MessageLookupByLibrary.simpleMessage(
            "en cinta, general"),
        "paUnicyclingGeneral": MessageLookupByLibrary.simpleMessage(
            "monociclo"),
        "paUnicyclingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paVolleyballGeneral": MessageLookupByLibrary.simpleMessage(
            "voleibol"),
        "paVolleyballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sin competición, equipo de 6 a 9 personas, general"),
        "paWalkingForPleasure": MessageLookupByLibrary.simpleMessage(
            "caminar"),
        "paWalkingForPleasureDesc": MessageLookupByLibrary.simpleMessage(
            "por placer"),
        "paWalkingTheDog": MessageLookupByLibrary.simpleMessage(
            "pasear al perro"),
        "paWalkingTheDogDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWallyball": MessageLookupByLibrary.simpleMessage(
            "wallyball"),
        "paWallyballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWaterAerobics": MessageLookupByLibrary.simpleMessage(
            "ejercicio en el agua"),
        "paWaterAerobicsDesc": MessageLookupByLibrary.simpleMessage(
            "aquaeróbic, calistenia acuática"),
        "paWaterPolo": MessageLookupByLibrary.simpleMessage(
            "waterpolo"),
        "paWaterPoloDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWaterVolleyball": MessageLookupByLibrary.simpleMessage(
            "voleibol acuático"),
        "paWaterVolleyballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWateraerobicsCalisthenics": MessageLookupByLibrary.simpleMessage(
            "aquaeróbic"),
        "paWateraerobicsCalisthenicsDesc": MessageLookupByLibrary.simpleMessage(
            "aquaeróbic, calistenia acuática"),
        "paWrestling": MessageLookupByLibrary.simpleMessage(
            "lucha libre"),
        "paWrestlingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "palActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Pasas la mayor parte del trabajo de pie o caminando y tu tiempo libre es activo"),
        "palActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Activo"),
        "palLowActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "p. ej., trabajo sentado o de pie y tiempo libre con actividad ligera"),
        "palLowLActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Poco activo"),
        "palSedentaryDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "p. ej., trabajo de oficina y tiempo libre mayormente sentado"),
        "palSedentaryLabel": MessageLookupByLibrary.simpleMessage(
            "Sedentario"),
        "palVeryActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Pasas la mayor parte del trabajo caminando, corriendo o cargando peso y tu tiempo libre es activo"),
        "palVeryActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Muy activo"),
        "pasteCodeHint": MessageLookupByLibrary.simpleMessage(
            "Pega aquí el código de la comida compartida"),
        "pasteCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Pegar código"),
        "per100gmlLabel": MessageLookupByLibrary.simpleMessage(
            "Por 100 g/ml"),
        "perServingLabel": MessageLookupByLibrary.simpleMessage(
            "Por ración"),
        "phosphorusLabel": MessageLookupByLibrary.simpleMessage(
            "fósforo"),
        "polyunsaturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "grasas poliinsaturadas"),
        "potassiumLabel": MessageLookupByLibrary.simpleMessage(
            "potasio"),
        "privacyPolicyLabel": MessageLookupByLibrary.simpleMessage(
            "Política de privacidad"),
        "profileBodyMeasurementsTitle": MessageLookupByLibrary.simpleMessage(
            "Medidas corporales"),
        "profileFastingEntry": MessageLookupByLibrary.simpleMessage(
            "Temporizador de ayuno"),
        "profileLabel": MessageLookupByLibrary.simpleMessage(
            "Perfil"),
        "profileTargetWeightClearAction": MessageLookupByLibrary.simpleMessage(
            "Borrar"),
        "profileTargetWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Peso objetivo"),
        "profileTargetWeightNotSetLabel": MessageLookupByLibrary.simpleMessage(
            "Sin definir"),
        "profileTargetWeightReached": MessageLookupByLibrary.simpleMessage(
            "Has alcanzado tu objetivo"),
        "profileTargetWeightToGo": m34,
        "profileWeeklyRateLabel": MessageLookupByLibrary.simpleMessage(
            "Ritmo semanal"),
        "profileWeeklyRateValue": m35,
        "profileWeightHistoryTitle": MessageLookupByLibrary.simpleMessage(
            "Historial de peso"),
        "progressPhotoImageLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir una foto"),
        "progressPhotoImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Elegir de la galería"),
        "progressPhotoImageRemove": MessageLookupByLibrary.simpleMessage(
            "Quitar foto"),
        "progressPhotoImageReplace": MessageLookupByLibrary.simpleMessage(
            "Cambiar foto"),
        "progressPhotoImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Hacer foto"),
        "proteinLabel": MessageLookupByLibrary.simpleMessage(
            "proteínas"),
        "proteinLabelShort": MessageLookupByLibrary.simpleMessage(
            "p"),
        "quantityLabel": MessageLookupByLibrary.simpleMessage(
            "Cantidad"),
        "quickAddAddedSnack": m36,
        "quickAddBottomSheetTitle": MessageLookupByLibrary.simpleMessage(
            "Entrada rápida"),
        "quickAddCarbsHint": MessageLookupByLibrary.simpleMessage(
            "Carbohidratos (g, opcional)"),
        "quickAddCardLabel": MessageLookupByLibrary.simpleMessage(
            "Entrada rápida"),
        "quickAddDefaultName": MessageLookupByLibrary.simpleMessage(
            "Entrada rápida"),
        "quickAddEnergyLabelKcal": MessageLookupByLibrary.simpleMessage(
            "Energía (kcal)"),
        "quickAddEnergyLabelKj": MessageLookupByLibrary.simpleMessage(
            "Energía (kJ)"),
        "quickAddFatHint": MessageLookupByLibrary.simpleMessage(
            "Grasas (g, opcional)"),
        "quickAddProteinHint": MessageLookupByLibrary.simpleMessage(
            "Proteínas (g, opcional)"),
        "quickAddSubmitLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir"),
        "quickAddTitleHint": MessageLookupByLibrary.simpleMessage(
            "Título"),
        "readLabel": MessageLookupByLibrary.simpleMessage(
            "He leído y acepto la política de privacidad."),
        "recentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "Recientes"),
        "recipeAddIngredientLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir ingrediente"),
        "recipeDeleteConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Se conservarán las entradas del diario ya registradas con esta receta."),
        "recipeDeleteConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar receta?"),
        "recipeDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Descripción (opcional)"),
        "recipeImageLabel": MessageLookupByLibrary.simpleMessage(
            "Añadir una foto"),
        "recipeImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Elegir de la galería"),
        "recipeImageRemove": MessageLookupByLibrary.simpleMessage(
            "Quitar foto"),
        "recipeImageReplace": MessageLookupByLibrary.simpleMessage(
            "Cambiar foto"),
        "recipeImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Hacer foto"),
        "recipeIngredientAmountLabel": MessageLookupByLibrary.simpleMessage(
            "Cantidad"),
        "recipeIngredientCountLabel": m37,
        "recipeIngredientUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unidad"),
        "recipeIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Ingredientes"),
        "recipeInvalidTotalWeightLabel": MessageLookupByLibrary.simpleMessage(
            "El peso total debe ser mayor que cero"),
        "recipeLogCtaLabel": MessageLookupByLibrary.simpleMessage(
            "Registrar esta receta"),
        "recipeNameLabel": MessageLookupByLibrary.simpleMessage(
            "Nombre de la receta"),
        "recipeNameRequiredLabel": MessageLookupByLibrary.simpleMessage(
            "La receta necesita un nombre"),
        "recipeNeedsIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Añade al menos un ingrediente"),
        "recipeNoIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Aún no hay ingredientes"),
        "recipeNutritionPer100Label": MessageLookupByLibrary.simpleMessage(
            "Por 100 g"),
        "recipeNutritionPreviewLabel": MessageLookupByLibrary.simpleMessage(
            "Nutrición (total)"),
        "recipeSaveErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No se ha podido guardar la receta."),
        "recipeSaveForLaterDescription": MessageLookupByLibrary.simpleMessage(
            "Actívalo para conservar esta comida en tu lista de guardadas para la próxima vez. Déjalo desactivado si es algo puntual que no volverás a comer."),
        "recipeSaveForLaterLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar para la próxima vez"),
        "recipeSaveLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar receta"),
        "recipeServingsCountHelper": MessageLookupByLibrary.simpleMessage(
            "Te permite registrar esta receta por raciones en lugar de por gramos."),
        "recipeServingsCountLabel": MessageLookupByLibrary.simpleMessage(
            "Raciones (opcional)"),
        "recipeTagsHelper": MessageLookupByLibrary.simpleMessage(
            "Separadas por comas, p. ej., \"desayuno, vegano\""),
        "recipeTagsLabel": MessageLookupByLibrary.simpleMessage(
            "Etiquetas"),
        "recipeTotalWeightHelper": MessageLookupByLibrary.simpleMessage(
            "Pesa la olla con el plato terminado para que, al registrar una parte (por ejemplo, 350 g), se cuenten las calorías correctas. Por defecto se usa el peso de los ingredientes crudos; los líquidos cuentan como 1 ml ≈ 1 g."),
        "recipeTotalWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Peso del plato entero cocinado (g)"),
        "recipesEmptyHint": MessageLookupByLibrary.simpleMessage(
            "Crea una comida con varios ingredientes y reutilízala como cualquier otro alimento."),
        "recipesEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Aún no hay recetas"),
        "recipesFilterAllLabel": MessageLookupByLibrary.simpleMessage(
            "Todas"),
        "recipesLabel": MessageLookupByLibrary.simpleMessage(
            "Recetas"),
        "recipesLoadErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No se han podido cargar las recetas. Inténtalo de nuevo más tarde."),
        "repeatDayActionLabel": MessageLookupByLibrary.simpleMessage(
            "Repetir día"),
        "reportErrorDialogText": MessageLookupByLibrary.simpleMessage(
            "¿Quieres informar de un error al desarrollador?"),
        "retryLabel": MessageLookupByLibrary.simpleMessage(
            "Reintentar"),
        "reviewMealAddAllButton": m38,
        "reviewMealConfidenceHigh": MessageLookupByLibrary.simpleMessage(
            "alta"),
        "reviewMealConfidenceLow": MessageLookupByLibrary.simpleMessage(
            "baja"),
        "reviewMealConfidenceMedium": MessageLookupByLibrary.simpleMessage(
            "media"),
        "reviewMealGramsUnit": MessageLookupByLibrary.simpleMessage(
            "g"),
        "reviewMealPresetSaveFailedError": MessageLookupByLibrary.simpleMessage(
            "No se ha podido guardar esta plantilla; inténtalo de nuevo"),
        "reviewMealPresetSavedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Guardada como plantilla"),
        "reviewMealSaveAsPresetButton": MessageLookupByLibrary.simpleMessage(
            "Guardar como plantilla"),
        "reviewMealSavePresetNameHint": MessageLookupByLibrary.simpleMessage(
            "Nombre de la plantilla"),
        "reviewMealScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Revisar comida"),
        "reviewMealTotalKcalLabel": m39,
        "saturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "grasas saturadas"),
        "scanLabelAnalysisFailedError": MessageLookupByLibrary.simpleMessage(
            "No se ha podido leer esta etiqueta; inténtalo de nuevo"),
        "scanLabelAnalyzeButton": MessageLookupByLibrary.simpleMessage(
            "Leer etiqueta"),
        "scanLabelExplanation": MessageLookupByLibrary.simpleMessage(
            "Haz una foto de la etiqueta de información nutricional y rellenaremos los datos para que los revises."),
        "scanLabelPhotoPlaceholder": MessageLookupByLibrary.simpleMessage(
            "Foto de la etiqueta nutricional"),
        "scanLabelScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Escanear etiqueta"),
        "scanProductLabel": MessageLookupByLibrary.simpleMessage(
            "Escanear producto"),
        "scannerCameraPermissionDeniedExplanation": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker necesita acceso a la cámara para escanear códigos de barras. Actívalo en los ajustes del dispositivo, vuelve e inténtalo de nuevo."),
        "scannerCameraPermissionDeniedTitle": MessageLookupByLibrary.simpleMessage(
            "Se necesita acceso a la cámara"),
        "scannerManualEntryButton": MessageLookupByLibrary.simpleMessage(
            "Escribir el código a mano"),
        "scannerManualEntryCancel": MessageLookupByLibrary.simpleMessage(
            "Cancelar"),
        "scannerManualEntryDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Introduce el código de barras"),
        "scannerManualEntryFieldHint": MessageLookupByLibrary.simpleMessage(
            "De 8 a 14 dígitos"),
        "scannerManualEntryInvalid": MessageLookupByLibrary.simpleMessage(
            "Ese código de barras no parece válido. Revisa los dígitos e inténtalo de nuevo."),
        "scannerManualEntrySubmit": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "scannerOpenSettingsButton": MessageLookupByLibrary.simpleMessage(
            "Abrir ajustes"),
        "scannerPhotographLabelButton": MessageLookupByLibrary.simpleMessage(
            "Fotografiar etiqueta"),
        "scannerPhotographLabelExplanation": MessageLookupByLibrary.simpleMessage(
            "No encontramos este producto en la base de datos. Haz una foto de la etiqueta nutricional y la leeremos para que la revises."),
        "scannerScanAgainButton": MessageLookupByLibrary.simpleMessage(
            "Volver a escanear"),
        "scannerSwitchLensButton": MessageLookupByLibrary.simpleMessage(
            "Cambiar de lente (ayuda con códigos de barras de cerca)"),
        "searchDefaultLabel": MessageLookupByLibrary.simpleMessage(
            "Introduce un término de búsqueda"),
        "searchFoodPage": MessageLookupByLibrary.simpleMessage(
            "Alimentos"),
        "searchLabel": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "searchProductsPage": MessageLookupByLibrary.simpleMessage(
            "Productos"),
        "searchResultsLabel": MessageLookupByLibrary.simpleMessage(
            "Resultados de búsqueda"),
        "selectGenderDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el sexo"),
        "selectHeightDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona la altura"),
        "selectPalCategoryLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el nivel de actividad"),
        "selectWeightDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el peso"),
        "selectionCountLabel": m40,
        "sendAnonymousUserData": MessageLookupByLibrary.simpleMessage(
            "Enviar datos de uso anónimos"),
        "servingLabel": MessageLookupByLibrary.simpleMessage(
            "Ración"),
        "servingSizeLabelImperial": MessageLookupByLibrary.simpleMessage(
            "Tamaño de ración (oz/fl oz)"),
        "servingSizeLabelMetric": MessageLookupByLibrary.simpleMessage(
            "Tamaño de ración (g/ml)"),
        "settingAboutLabel": MessageLookupByLibrary.simpleMessage(
            "Acerca de"),
        "settingFeedbackLabel": MessageLookupByLibrary.simpleMessage(
            "Comentarios"),
        "settingsAccentColourTitle": MessageLookupByLibrary.simpleMessage(
            "Color de acento"),
        "settingsAccentCustomColour": MessageLookupByLibrary.simpleMessage(
            "Color personalizado…"),
        "settingsAccentCustomSubtitle": MessageLookupByLibrary.simpleMessage(
            "Abre el selector de tono para elegir con precisión"),
        "settingsAccentHexInvalid": MessageLookupByLibrary.simpleMessage(
            "Ese código hexadecimal no parece correcto: seis dígitos, 0-9 y A-F."),
        "settingsAccentHexLabel": MessageLookupByLibrary.simpleMessage(
            "Código hexadecimal"),
        "settingsAccentHueDisabledHint": MessageLookupByLibrary.simpleMessage(
            "Desactiva los colores del sistema para elegir un acento personalizado."),
        "settingsAccentHueReset": MessageLookupByLibrary.simpleMessage(
            "Restablecer"),
        "settingsAccentHueTitle": MessageLookupByLibrary.simpleMessage(
            "Color de acento"),
        "settingsAccentPresetsHeader": MessageLookupByLibrary.simpleMessage(
            "Elige un color"),
        "settingsAccentSubtitleCustom": MessageLookupByLibrary.simpleMessage(
            "Personalizado"),
        "settingsAccentSubtitleDefault": MessageLookupByLibrary.simpleMessage(
            "Predeterminado"),
        "settingsAccentSubtitleMaterialYou": MessageLookupByLibrary.simpleMessage(
            "Material You"),
        "settingsCalciumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de calcio en miligramos. La referencia por defecto es 1000 mg."),
        "settingsCalciumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de calcio"),
        "settingsCaloriesTaperDescription": MessageLookupByLibrary.simpleMessage(
            "Reduce el déficit diario de forma gradual para que los últimos kilos no se hagan cuesta arriba."),
        "settingsCaloriesTaperLabel": MessageLookupByLibrary.simpleMessage(
            "Ajustar el objetivo de calorías al acercarte a tu meta"),
        "settingsCloudBackupActivateLabel": MessageLookupByLibrary.simpleMessage(
            "Activar copia en la nube"),
        "settingsCloudBackupActivateSubtitle": MessageLookupByLibrary.simpleMessage(
            "Genera un código de vinculación para ver tus datos en otro dispositivo"),
        "settingsCloudBackupLinkDeviceLabel": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositivo"),
        "settingsCloudBackupLinkDeviceSubtitle": MessageLookupByLibrary.simpleMessage(
            "Escanea o pega un código de vinculación de otro dispositivo"),
        "settingsCloudBackupNotPairedError": MessageLookupByLibrary.simpleMessage(
            "Primero configura la copia en la nube"),
        "settingsCloudBackupRestoreConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Restaurar"),
        "settingsCloudBackupRestoreConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Esto sustituye todo lo que hay en este dispositivo (diario, perfil, ajustes, recetas y más) por la última copia en la nube. Esta acción no se puede deshacer."),
        "settingsCloudBackupRestoreConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Restaurar desde la nube?"),
        "settingsCloudBackupRestoreErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error al restaurar"),
        "settingsCloudBackupRestoreLabel": MessageLookupByLibrary.simpleMessage(
            "Restaurar desde la nube"),
        "settingsCloudBackupRestoreSubtitle": MessageLookupByLibrary.simpleMessage(
            "Descarga la copia de la nube y sobrescribe los datos de este dispositivo"),
        "settingsCloudBackupRestoreSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Datos restaurados. Reinicia la app para ver todos los cambios."),
        "settingsCloudBackupSyncErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error en la copia de seguridad"),
        "settingsCloudBackupSyncLabel": MessageLookupByLibrary.simpleMessage(
            "Hacer copia ahora"),
        "settingsCloudBackupSyncSubtitle": MessageLookupByLibrary.simpleMessage(
            "Sube a la nube los datos de este dispositivo"),
        "settingsCloudBackupSyncSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Copia subida"),
        "settingsCloudBackupViewCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Ver código de vinculación"),
        "settingsCustomMealsLabel": MessageLookupByLibrary.simpleMessage(
            "Alimentos personalizados"),
        "settingsDayStartDescription": MessageLookupByLibrary.simpleMessage(
            "Elige la hora a la que empieza tu día. Las comidas y actividades registradas antes de esa hora cuentan para el día anterior; útil si trabajas de noche o cenas tarde."),
        "settingsDayStartHourLabel": m41,
        "settingsDayStartHoursPickerLabel": MessageLookupByLibrary.simpleMessage(
            "Horas"),
        "settingsDayStartLabel": MessageLookupByLibrary.simpleMessage(
            "El día empieza a las"),
        "settingsDayStartMinutesPickerLabel": MessageLookupByLibrary.simpleMessage(
            "Minutos"),
        "settingsDayStartTimeLabel": m42,
        "settingsDeleteAllDataConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Eliminar todo"),
        "settingsDeleteAllDataConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Esto elimina de forma permanente de este dispositivo tu perfil, comidas, actividades, historial de peso y recetas personalizadas. Los catálogos de Open Food Facts y USDA Food Data Central no se ven afectados. Esta acción no se puede deshacer."),
        "settingsDeleteAllDataConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Eliminar todos tus datos?"),
        "settingsDeleteAllDataLabel": MessageLookupByLibrary.simpleMessage(
            "Eliminar todos mis datos"),
        "settingsDeleteAllDataSubtitle": MessageLookupByLibrary.simpleMessage(
            "Perfil, comidas, actividades e historial de peso"),
        "settingsDisclaimerLabel": MessageLookupByLibrary.simpleMessage(
            "Aviso legal"),
        "settingsDistanceLabel": MessageLookupByLibrary.simpleMessage(
            "Distancia"),
        "settingsEnergyUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unidad de energía"),
        "settingsFibreGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de fibra en gramos. La referencia por defecto es 30 g."),
        "settingsFibreGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de fibra"),
        "settingsImperialLabel": MessageLookupByLibrary.simpleMessage(
            "Imperial (lbs, ft, oz)"),
        "settingsIronGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de hierro en miligramos. El valor por defecto depende del sexo (8 mg hombres, 18 mg mujeres, 14 mg en otros casos)."),
        "settingsIronGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de hierro"),
        "settingsKcalAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajuste diario de kcal"),
        "settingsLabel": MessageLookupByLibrary.simpleMessage(
            "Ajustes"),
        "settingsLanguageLabel": MessageLookupByLibrary.simpleMessage(
            "Idioma"),
        "settingsLicensesLabel": MessageLookupByLibrary.simpleMessage(
            "Licencias"),
        "settingsMacroSplitLabel": MessageLookupByLibrary.simpleMessage(
            "Reparto de macros"),
        "settingsMagnesiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de magnesio en miligramos. El valor por defecto depende del sexo (400 mg hombres, 310 mg mujeres, 355 mg en otros casos)."),
        "settingsMagnesiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de magnesio"),
        "settingsMassLabel": MessageLookupByLibrary.simpleMessage(
            "Masa"),
        "settingsMaterialYouSubtitle": MessageLookupByLibrary.simpleMessage(
            "Usa el color de acento de tu fondo de pantalla en Android 12 y versiones posteriores."),
        "settingsMaterialYouTitle": MessageLookupByLibrary.simpleMessage(
            "Usar colores del sistema"),
        "settingsMetricLabel": MessageLookupByLibrary.simpleMessage(
            "Métrico (kg, cm, ml)"),
        "settingsNotificationsLabel": MessageLookupByLibrary.simpleMessage(
            "Recordatorio diario"),
        "settingsNotificationsTimeLabel": m43,
        "settingsNotificationsUnavailableWebLabel": MessageLookupByLibrary.simpleMessage(
            "No disponible en la versión web"),
        "settingsNutrientGoalsHint": MessageLookupByLibrary.simpleMessage(
            "Objetivos personales para cada nutriente del panel diario. Cuando defines uno, el diario lo usa en lugar de la referencia diaria por defecto."),
        "settingsNutrientGoalsLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivos de nutrientes"),
        "settingsNutrientsHelp": MessageLookupByLibrary.simpleMessage(
            "Elige qué nutrientes se ven en el panel diario. Puedes volver a activar los ocultos en cualquier momento."),
        "settingsNutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Nutrientes"),
        "settingsNutrientsSubtitle": MessageLookupByLibrary.simpleMessage(
            "Elige qué nutrientes aparecen en el panel del diario"),
        "settingsOpenRouterLabel": MessageLookupByLibrary.simpleMessage(
            "Proveedor de IA"),
        "settingsOpenRouterSubtitle": MessageLookupByLibrary.simpleMessage(
            "Configura OpenRouter para las funciones con IA"),
        "settingsPerMealKcalShareBreakfast": MessageLookupByLibrary.simpleMessage(
            "Desayuno"),
        "settingsPerMealKcalShareDescription": MessageLookupByLibrary.simpleMessage(
            "Reparte tu objetivo diario de kcal entre desayuno, comida, cena y tentempiés. Los porcentajes deben sumar 100%."),
        "settingsPerMealKcalShareDinner": MessageLookupByLibrary.simpleMessage(
            "Cena"),
        "settingsPerMealKcalShareLabel": MessageLookupByLibrary.simpleMessage(
            "Reparto de kcal por comida"),
        "settingsPerMealKcalShareLunch": MessageLookupByLibrary.simpleMessage(
            "Comida"),
        "settingsPerMealKcalShareSnack": MessageLookupByLibrary.simpleMessage(
            "Tentempié"),
        "settingsPotassiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de potasio en miligramos. La referencia por defecto es 3500 mg."),
        "settingsPotassiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de potasio"),
        "settingsPrivacySettings": MessageLookupByLibrary.simpleMessage(
            "Ajustes de privacidad"),
        "settingsReportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Informar de un error"),
        "settingsSaturatedFatGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límite diario de grasas saturadas en gramos. La referencia por defecto es 20 g."),
        "settingsSaturatedFatGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de grasas saturadas"),
        "settingsShowActivityTracking": MessageLookupByLibrary.simpleMessage(
            "Mostrar registro de actividad"),
        "settingsShowMealMacros": MessageLookupByLibrary.simpleMessage(
            "Mostrar macros de las comidas"),
        "settingsShowMicronutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Mostrar micronutrientes"),
        "settingsSodiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límite diario de sodio en miligramos. La referencia por defecto es 2300 mg."),
        "settingsSodiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de sodio"),
        "settingsSourceCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Código fuente"),
        "settingsSourcesLabel": MessageLookupByLibrary.simpleMessage(
            "Fuentes y referencias"),
        "settingsSugarsGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límite diario de azúcares en gramos. La referencia por defecto es 50 g."),
        "settingsSugarsGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de azúcares"),
        "settingsSystemLabel": MessageLookupByLibrary.simpleMessage(
            "Sistema"),
        "settingsThemeDarkLabel": MessageLookupByLibrary.simpleMessage(
            "Oscuro"),
        "settingsThemeLabel": MessageLookupByLibrary.simpleMessage(
            "Tema"),
        "settingsThemeLightLabel": MessageLookupByLibrary.simpleMessage(
            "Claro"),
        "settingsThemeSystemDefaultLabel": MessageLookupByLibrary.simpleMessage(
            "Predeterminado del sistema"),
        "settingsUnitsLabel": MessageLookupByLibrary.simpleMessage(
            "Unidades"),
        "settingsVitaminB12GoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de vitamina B12 en microgramos. La referencia por defecto es 2,4 µg."),
        "settingsVitaminB12GoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de vitamina B12"),
        "settingsVitaminDGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de vitamina D en microgramos. La referencia por defecto es 15 µg."),
        "settingsVitaminDGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de vitamina D"),
        "settingsVolumeLabel": MessageLookupByLibrary.simpleMessage(
            "Volumen"),
        "settingsWaterGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Lo usa el indicador de agua de la pantalla de inicio."),
        "settingsWaterGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo diario de agua"),
        "shareActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir entrenamiento"),
        "shareCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir código"),
        "shareMealLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir comida"),
        "shareRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir receta"),
        "snackExample": MessageLookupByLibrary.simpleMessage(
            "p. ej., manzana, helado, chocolate..."),
        "snackLabel": MessageLookupByLibrary.simpleMessage(
            "Tentempié"),
        "sodiumLabel": MessageLookupByLibrary.simpleMessage(
            "sodio"),
        "sourcesActivityDescription": MessageLookupByLibrary.simpleMessage(
            "Las calorías quemadas durante una actividad se estiman como MET × peso corporal (kg) × duración (horas), con valores del Adult Compendium of Physical Activities."),
        "sourcesActivityTitle": MessageLookupByLibrary.simpleMessage(
            "Calorías de la actividad (valores MET)"),
        "sourcesBmiDescription": MessageLookupByLibrary.simpleMessage(
            "El IMC se calcula como el peso (kg) dividido por la altura al cuadrado (m²). Las categorías de salud (bajo peso, normal, preobesidad, obesidad de clase I–III) siguen la clasificación del IMC para adultos de la Organización Mundial de la Salud."),
        "sourcesBmiTitle": MessageLookupByLibrary.simpleMessage(
            "Índice de masa corporal (IMC)"),
        "sourcesEnergyDescription": MessageLookupByLibrary.simpleMessage(
            "Los objetivos diarios de calorías, la tasa metabólica basal y los coeficientes de actividad física usan las ecuaciones del Institute of Medicine. Fuente: Institute of Medicine (2005). Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids, capítulo 5 y tabla 5-5."),
        "sourcesEnergyTitle": MessageLookupByLibrary.simpleMessage(
            "Necesidades energéticas (TDEE, TMB y nivel de actividad)"),
        "sourcesFoodDataDescription": MessageLookupByLibrary.simpleMessage(
            "Los valores nutricionales de productos y alimentos genéricos proceden de estas bases de datos. Los datos de BEDCA se usan con fines personales y no comerciales, con la atribución que exigen sus condiciones."),
        "sourcesFoodDataTitle": MessageLookupByLibrary.simpleMessage(
            "Bases de datos de alimentos"),
        "sourcesIconTooltip": MessageLookupByLibrary.simpleMessage(
            "Ver fuentes"),
        "sourcesMacrosDescription": MessageLookupByLibrary.simpleMessage(
            "El reparto por defecto de 60% carbohidratos, 25% grasas y 15% proteínas está dentro de los rangos de ingesta de nutrientes para la población publicados por la OMS. Puedes ajustarlo en Ajustes → Cálculos. Fuente: WHO Technical Report Series 916 (2003), Diet, Nutrition and the Prevention of Chronic Diseases."),
        "sourcesMacrosTitle": MessageLookupByLibrary.simpleMessage(
            "Distribución de macronutrientes"),
        "sourcesNonBinaryDescription": MessageLookupByLibrary.simpleMessage(
            "La investigación sobre el gasto energético ha usado históricamente categorías de sexo binarias, así que no existe una única fórmula de TDEE validada para personas no binarias. Por eso OpenNutriTracker te deja elegir en Ajustes → Cálculos entre una referencia promedio, una de perfil estrogénico o una de perfil testosterónico. Si un número preciso es realmente importante para tu atención sanitaria, habla con un profesional que conozca tu situación hormonal."),
        "sourcesNonBinaryTitle": MessageLookupByLibrary.simpleMessage(
            "Estimación calórica para personas no binarias"),
        "sourcesNutrientReferenceDescription": MessageLookupByLibrary.simpleMessage(
            "Las cantidades diarias de referencia del panel de nutrientes del diario proceden del resumen de las Dietary Reference Intakes del Institute of Medicine, que recoge objetivos por nutriente para adultos."),
        "sourcesNutrientReferenceTitle": MessageLookupByLibrary.simpleMessage(
            "Ingestas de referencia de nutrientes"),
        "sourcesOpenSourceLabel": MessageLookupByLibrary.simpleMessage(
            "Ver fuente"),
        "sourcesScreenIntro": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker usa metodologías consolidadas y revisadas por pares para cada cálculo que muestra. Las citas de abajo enlazan a las fuentes originales para que puedas comprobar cualquier número tú mismo."),
        "strategyCheckInApply": MessageLookupByLibrary.simpleMessage(
            "Actualizar objetivo"),
        "strategyCheckInDayLabel": MessageLookupByLibrary.simpleMessage(
            "Día de revisión"),
        "strategyCheckInDue": m44,
        "strategyCheckInKeep": MessageLookupByLibrary.simpleMessage(
            "Mantener el actual"),
        "strategyCheckInNext": m45,
        "strategyCheckInTitle": MessageLookupByLibrary.simpleMessage(
            "Revisión semanal"),
        "strategyEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra al menos dos pesajes para ver tu panel de estrategia."),
        "strategyEstimatedTdeeLabel": MessageLookupByLibrary.simpleMessage(
            "TDEE estimado"),
        "strategyEstimatorStatusActiveDescription": MessageLookupByLibrary.simpleMessage(
            "Se actualiza con tus datos"),
        "strategyEstimatorStatusActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Activo"),
        "strategyEstimatorStatusCalibratingDescription": MessageLookupByLibrary.simpleMessage(
            "Se va ajustando hacia tu estimación dinámica a medida que llegan más datos; suele estabilizarse en un par de semanas"),
        "strategyEstimatorStatusCalibratingLabel": MessageLookupByLibrary.simpleMessage(
            "Calibrando"),
        "strategyEstimatorStatusInsufficientDescription": MessageLookupByLibrary.simpleMessage(
            "Registra tu peso y tus comidas con más regularidad para obtener una estimación"),
        "strategyEstimatorStatusInsufficientLabel": MessageLookupByLibrary.simpleMessage(
            "Datos insuficientes"),
        "strategyEstimatorStatusPausedDescription": MessageLookupByLibrary.simpleMessage(
            "Menos de 4 de los últimos 7 días tienen comidas registradas, así que tu estimación se mantiene en su último valor"),
        "strategyEstimatorStatusPausedLabel": MessageLookupByLibrary.simpleMessage(
            "En pausa"),
        "strategyExplanationCorrecting": m46,
        "strategyExplanationMaintaining": MessageLookupByLibrary.simpleMessage(
            "Mantenimiento: coincide con tu TDEE observado"),
        "strategyExplanationRate": m47,
        "strategyExplanationWithinBand": m48,
        "strategyKcalFloorNote": m49,
        "strategyLabel": MessageLookupByLibrary.simpleMessage(
            "Estrategia"),
        "strategyMacroDistributionTitle": MessageLookupByLibrary.simpleMessage(
            "Distribución de macros"),
        "strategyRangeAllTime": MessageLookupByLibrary.simpleMessage(
            "Todo"),
        "strategyRangeOneMonth": MessageLookupByLibrary.simpleMessage(
            "1 M"),
        "strategyRangeOneYear": MessageLookupByLibrary.simpleMessage(
            "1 A"),
        "strategyRangeSixMonths": MessageLookupByLibrary.simpleMessage(
            "6 M"),
        "strategyRangeThreeMonths": MessageLookupByLibrary.simpleMessage(
            "3 M"),
        "strategyTodayTargetLabel": MessageLookupByLibrary.simpleMessage(
            "Objetivo de hoy"),
        "strategyTrendWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Peso de tendencia"),
        "sugarLabel": MessageLookupByLibrary.simpleMessage(
            "azúcar"),
        "suppliedLabel": MessageLookupByLibrary.simpleMessage(
            "aportado"),
        "transFatLabel": MessageLookupByLibrary.simpleMessage(
            "grasas trans"),
        "unitLabel": MessageLookupByLibrary.simpleMessage(
            "Unidad"),
        "vitaminALabel": MessageLookupByLibrary.simpleMessage(
            "vitamina A"),
        "vitaminB12Label": MessageLookupByLibrary.simpleMessage(
            "vitamina B12"),
        "vitaminB6Label": MessageLookupByLibrary.simpleMessage(
            "vitamina B6"),
        "vitaminCLabel": MessageLookupByLibrary.simpleMessage(
            "vitamina C"),
        "vitaminDLabel": MessageLookupByLibrary.simpleMessage(
            "vitamina D"),
        "warningLabel": MessageLookupByLibrary.simpleMessage(
            "Advertencia"),
        "waterChipLabel": m50,
        "weeklyRateDialogDescription": MessageLookupByLibrary.simpleMessage(
            "Se define como un porcentaje del peso corporal por semana. Hasta que tu peso de tendencia llegue al objetivo, tu meta será tu TDEE observado menos (o más) las calorías correspondientes. Un ritmo nuevo se aplica en tu próxima revisión semanal."),
        "weightHistoryAddEntry": MessageLookupByLibrary.simpleMessage(
            "Añadir registro"),
        "weightHistoryChartEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra al menos dos días para ver tu tendencia."),
        "weightHistoryDateLabel": MessageLookupByLibrary.simpleMessage(
            "Fecha"),
        "weightHistoryNoEntries": MessageLookupByLibrary.simpleMessage(
            "Aún no hay registros de peso. Añade el primero para empezar a seguir tu tendencia."),
        "weightHistoryNoteLabel": MessageLookupByLibrary.simpleMessage(
            "Nota (opcional)"),
        "weightHistoryScaleLabel": MessageLookupByLibrary.simpleMessage(
            "Báscula"),
        "weightHistoryTrendLabel": MessageLookupByLibrary.simpleMessage(
            "Tendencia"),
        "weightHistoryWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Peso"),
        "weightLabel": MessageLookupByLibrary.simpleMessage(
            "Peso"),
        "yearsLabel": m51,
        "zincLabel": MessageLookupByLibrary.simpleMessage(
            "zinc"),
        "syncTitle": MessageLookupByLibrary.simpleMessage(
            "Sincronización entre dispositivos"),
        "syncStatusOff": MessageLookupByLibrary.simpleMessage(
            "Desactivada en este dispositivo"),
        "syncStatusWaiting": MessageLookupByLibrary.simpleMessage(
            "Activada, a la espera de la primera sincronización"),
        "syncStatusSyncing": MessageLookupByLibrary.simpleMessage(
            "Sincronizando…"),
        "syncStatusError": MessageLookupByLibrary.simpleMessage(
            "La última sincronización falló. Se volverá a intentar sola."),
        "syncStatusIdle": mSyncStatusIdle,
        "syncExplanation": MessageLookupByLibrary.simpleMessage(
            "Mantiene igual en el móvil y en la web de escritorio tu diario, peso, recetas, ayunos, objetivos y ajustes. Todo se cifra en este dispositivo antes de subirse, así que el servidor no puede leerlo. Las fotos no se sincronizan; van en la copia en la nube."),
        "syncEnableTitle": MessageLookupByLibrary.simpleMessage(
            "Activar con los datos de este dispositivo"),
        "syncEnableSubtitle": MessageLookupByLibrary.simpleMessage(
            "Hazlo en el móvil que tiene tus datos y luego vincula los demás dispositivos con su código."),
        "syncLinkTitle": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositivo"),
        "syncLinkSubtitle": MessageLookupByLibrary.simpleMessage(
            "Pega o escanea el código de un dispositivo con la sincronización activada."),
        "syncLinkConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "¿Vincular este dispositivo?"),
        "syncLinkConfirmBody": MessageLookupByLibrary.simpleMessage(
            "Cuando los dos dispositivos tengan el mismo registro, como el perfil o los ajustes, la copia sincronizada sustituye a la de este dispositivo. Las entradas que solo existen aquí se conservan y se suben."),
        "syncLinkAction": MessageLookupByLibrary.simpleMessage(
            "Vincular"),
        "syncLinkInvalid": MessageLookupByLibrary.simpleMessage(
            "Eso no es un código de sincronización. Cópialo desde Ajustes > Sincronización entre dispositivos en el otro dispositivo."),
        "syncLinked": MessageLookupByLibrary.simpleMessage(
            "Dispositivo vinculado. Descargando tus datos…"),
        "syncNowLabel": MessageLookupByLibrary.simpleMessage(
            "Sincronizar ahora"),
        "syncShowCodeTitle": MessageLookupByLibrary.simpleMessage(
            "Mostrar el código para otro dispositivo"),
        "syncShowCodeWarning": MessageLookupByLibrary.simpleMessage(
            "Quien tenga este código puede leer y cambiar tus datos sincronizados. Úsalo solo en tus propios dispositivos."),
        "syncCodeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Código de sincronización"),
        "syncDisableTitle": MessageLookupByLibrary.simpleMessage(
            "Desactivar en este dispositivo"),
        "syncDisableBody": MessageLookupByLibrary.simpleMessage(
            "Este dispositivo deja de sincronizar y conserva sus datos. Tus otros dispositivos siguen sincronizando."),
        "syncDisableAction": MessageLookupByLibrary.simpleMessage(
            "Desactivar"),
        "syncScanLabel": MessageLookupByLibrary.simpleMessage(
            "Escanear QR"),
        "syncPasteHint": MessageLookupByLibrary.simpleMessage(
            "ontsync1:…"),
        "syncDoneSnackbar": mSyncDoneSnackbar,
        "reviewTitle": MessageLookupByLibrary.simpleMessage(
            "Análisis"),
        "reviewTabWeight": MessageLookupByLibrary.simpleMessage(
            "Peso"),
        "reviewTabExpenditure": MessageLookupByLibrary.simpleMessage(
            "Gasto"),
        "reviewTabAdherence": MessageLookupByLibrary.simpleMessage(
            "Adherencia"),
        "reviewTabDiary": MessageLookupByLibrary.simpleMessage(
            "Diario"),
        "reviewRange7": MessageLookupByLibrary.simpleMessage(
            "7 d"),
        "reviewRange30": MessageLookupByLibrary.simpleMessage(
            "30 d"),
        "reviewRange90": MessageLookupByLibrary.simpleMessage(
            "90 d"),
        "reviewRangeYear": MessageLookupByLibrary.simpleMessage(
            "1 año"),
        "reviewRangeAll": MessageLookupByLibrary.simpleMessage(
            "Todo"),
        "reviewRefresh": MessageLookupByLibrary.simpleMessage(
            "Actualizar"),
        "reviewExportCsv": MessageLookupByLibrary.simpleMessage(
            "Exportar CSV"),
        "reviewExported": MessageLookupByLibrary.simpleMessage(
            "CSV guardado"),
        "reviewEmpty": MessageLookupByLibrary.simpleMessage(
            "No hay nada registrado en este periodo."),
        "reviewChartScale": MessageLookupByLibrary.simpleMessage(
            "Báscula"),
        "reviewChartTrend": MessageLookupByLibrary.simpleMessage(
            "Tendencia"),
        "reviewChartIntake": MessageLookupByLibrary.simpleMessage(
            "Consumido"),
        "reviewChartExpenditure": MessageLookupByLibrary.simpleMessage(
            "Gasto"),
        "reviewColDate": MessageLookupByLibrary.simpleMessage(
            "Fecha"),
        "reviewColScale": MessageLookupByLibrary.simpleMessage(
            "Báscula"),
        "reviewColTrend": MessageLookupByLibrary.simpleMessage(
            "Tendencia"),
        "reviewColWeekChange": MessageLookupByLibrary.simpleMessage(
            "Cambio en 7 días"),
        "reviewColIntake": MessageLookupByLibrary.simpleMessage(
            "Consumido (kcal)"),
        "reviewColGoal": MessageLookupByLibrary.simpleMessage(
            "Objetivo (kcal)"),
        "reviewColExpenditure": MessageLookupByLibrary.simpleMessage(
            "Gasto (kcal)"),
        "reviewColBalance": MessageLookupByLibrary.simpleMessage(
            "Balance (kcal)"),
        "reviewColPeriod": MessageLookupByLibrary.simpleMessage(
            "Periodo"),
        "reviewColDays": MessageLookupByLibrary.simpleMessage(
            "Días registrados"),
        "reviewColOfGoal": MessageLookupByLibrary.simpleMessage(
            "Del objetivo"),
        "reviewColProtein": MessageLookupByLibrary.simpleMessage(
            "Proteína (g)"),
        "reviewColCarbs": MessageLookupByLibrary.simpleMessage(
            "Carbohidratos (g)"),
        "reviewColFat": MessageLookupByLibrary.simpleMessage(
            "Grasa (g)"),
        "reviewColTime": MessageLookupByLibrary.simpleMessage(
            "Hora"),
        "reviewColMeal": MessageLookupByLibrary.simpleMessage(
            "Comida"),
        "reviewColFood": MessageLookupByLibrary.simpleMessage(
            "Alimento"),
        "reviewColAmount": MessageLookupByLibrary.simpleMessage(
            "Cantidad"),
        "reviewPeriodDay": MessageLookupByLibrary.simpleMessage(
            "Día"),
        "reviewPeriodWeek": MessageLookupByLibrary.simpleMessage(
            "Semana"),
        "reviewPeriodMonth": MessageLookupByLibrary.simpleMessage(
            "Mes"),
        "reviewDeleteIntakeBody": MessageLookupByLibrary.simpleMessage(
            "¿Borrar esta entrada del diario?"),
        "planTitle": MessageLookupByLibrary.simpleMessage(
            "Plan de comidas"),
        "planWeekOf": mPlanWeekOf,
        "planThisWeek": MessageLookupByLibrary.simpleMessage(
            "Esta semana"),
        "planShoppingList": MessageLookupByLibrary.simpleMessage(
            "Lista de la compra"),
        "planShoppingEmpty": MessageLookupByLibrary.simpleMessage(
            "No hay nada planificado esta semana."),
        "planAdd": MessageLookupByLibrary.simpleMessage(
            "Añadir al plan"),
        "planSearchHint": MessageLookupByLibrary.simpleMessage(
            "Busca en tus recetas, alimentos y comidas recientes"),
        "planNoCandidates": MessageLookupByLibrary.simpleMessage(
            "Sin resultados. Crea una receta o un alimento personalizado, o registra un alimento una vez, y aparecerá aquí."),
        "planAmountLabel": MessageLookupByLibrary.simpleMessage(
            "Cantidad"),
        "planAddAction": MessageLookupByLibrary.simpleMessage(
            "Añadir"),
        "planLogDay": MessageLookupByLibrary.simpleMessage(
            "Registrar plan"),
        "planLogged": mPlanLogged,
        "planGoalValue": mPlanGoalValue,
        "planTodayTitle": MessageLookupByLibrary.simpleMessage(
            "Plan de hoy"),
        "planTodaySummary": mPlanTodaySummary,
        "planCopy": MessageLookupByLibrary.simpleMessage(
            "Copiar"),
        "planCopied": MessageLookupByLibrary.simpleMessage(
            "Lista copiada"),
      };
}
