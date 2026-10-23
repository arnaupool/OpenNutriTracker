// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ca locale. All the
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
  String get localeName => 'ca';

  static String mSyncStatusIdle(value) =>
      "Al dia · última sincronització ${value}";

  static String mSyncDoneSnackbar(pulled, pushed) =>
      "Sincronitzat: ${pulled} rebuts, ${pushed} enviats";

  static String m0(versionNumber) =>
      "Versió ${versionNumber}";

  static String m1(pctCarbs, pctFats, pctProteins) =>
      "${pctCarbs}% carbohidrats, ${pctFats}% greixos, ${pctProteins}% proteïnes";

  static String m2(count, size) =>
      "${count} element(s) · ${size}";

  static String m3(imported, skipped) =>
      "S\'han importat ${imported} aliment(s); s\'han omés ${skipped} files per dades no vàlides.";

  static String m4(count) =>
      "S\'han importat ${count} aliment(s).";

  static String m5(unit) =>
      "${unit} en una ració";

  static String m6(loser, winner) =>
      "Totes les entrades registrades amb ${loser} passaran a mostrar ${winner}, i ${loser} s\'eliminarà dels teus aliments personalitzats. Esta acció no es pot desfer.";

  static String m7(winner) =>
      "Combinats: ${winner} té ara 1 entrada registrada.";

  static String m8(count, winner) =>
      "Combinats: ${winner} té ara ${count} entrades registrades.";

  static String m9(count) =>
      "${count} elements copiats";

  static String m10(count) =>
      "Vols eliminar ${count} receptes?";

  static String m11(consumed, target) =>
      "${consumed} / ${target} kcal";

  static String m12(value) =>
      "ref. ${value}";

  static String m13(value) =>
      "Dejuni acabat després de ${value}.";

  static String m14(max) =>
      "Introduïx entre 1 i ${max} hores.";

  static String m15(count, value) =>
      "Últims 7 dies: ${count} registrats, mitjana de ${value}";

  static String m16(remaining) =>
      "Dejuni · queden ${remaining}";

  static String m17(value) =>
      "Dejuni · ${value}";

  static String m18(value) =>
      "${value} per damunt de l\'objectiu";

  static String m19(value) =>
      "Queden ${value}";

  static String m20(value) =>
      "Inici: ${value}";

  static String m21(value) =>
      "Objectiu: ${value}";

  static String m22(rate) =>
      "${rate}/setmana";

  static String m23(count) =>
      "Vols importar ${count} activitats?";

  static String m24(mealType) =>
      "Estos elements s\'afegiran a ${mealType}.";

  static String m25(count) =>
      "Vols importar ${count} elements?";

  static String m26(count) =>
      "${count} element(s) no s\'han pogut obtindre d\'OpenFoodFacts.";

  static String m27(count) =>
      "Vols importar esta recepta amb ${count} ingredient(s)?";

  static String m28(amount) =>
      "Afegir ${amount} ml";

  static String m29(threshold) =>
      "La majoria dels adults no haurien de menjar menys de ${threshold} kcal al dia durant un temps prolongat sense supervisió mèdica. Planteja\'t parlar amb un professional sanitari abans de mantindre un objectiu tan baix.";

  static String m30(kcal) =>
      "(+${kcal} kcal amb la selecció actual)";

  static String m31(consumed, goal) =>
      "Total del dia: ${consumed} / ${goal}";

  static String m32(qty, unit) =>
      "Per ${qty} ${unit}";

  static String m33(riskValue) =>
      "Risc de comorbiditats: ${riskValue}";

  static String m34(value) =>
      "${value} per al teu objectiu";

  static String m35(ratePct) =>
      "${ratePct}% del pes corporal per setmana";

  static String m36(mealType) =>
      "Afegit a ${mealType}";

  static String m37(count) =>
      "${count} ingredient(s)";

  static String m38(count) =>
      "Afegir-ho tot (${count} elements)";

  static String m39(kcal) =>
      "${kcal} kcal en total";

  static String m40(count) =>
      "${count} seleccionats";

  static String m41(hour) =>
      "${hour}:00";

  static String m42(hour, minute) =>
      "${hour}:${minute}";

  static String m43(time) =>
      "Hora del recordatori: ${time}";

  static String m44(newTarget, currentTarget) =>
      "La teua revisió setmanal està llesta. Objectiu nou: ${newTarget} (ara ${currentTarget}).";

  static String m45(date) =>
      "Pròxima revisió: ${date}";

  static String m46(distance, correction) =>
      "A ${distance} del teu objectiu: corregint ${correction}/dia cap a la meta";

  static String m47(ratePct, adjustment) =>
      "Buscant un ${ratePct}% del pes corporal per setmana: ${adjustment}/dia respecte al teu TDEE";

  static String m48(band) =>
      "A menys de ${band} del teu objectiu: manteniment amb el teu TDEE observat";

  static String m49(floor) =>
      "Fixat en el mínim de ${floor}: el teu ritme setmanal està limitat perquè l\'objectiu no baixe mai d\'ahí.";

  static String m50(current, goal) =>
      "${current} / ${goal} ml";

  static String m51(age) =>
      "${age} anys";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "activityExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., córrer, bici, ioga..."),
        "activityLabel": MessageLookupByLibrary.simpleMessage(
            "Activitat"),
        "addItemBodyMeasurementsExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., cintura, pit, maluc"),
        "addItemLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir element:"),
        "addItemMenuMagicLabel": MessageLookupByLibrary.simpleMessage(
            "Màgia"),
        "addItemMenuMagicSubtitle": MessageLookupByLibrary.simpleMessage(
            "Foto, text o tots dos"),
        "addItemMenuPresetsLabel": MessageLookupByLibrary.simpleMessage(
            "Plantilles"),
        "addItemMenuPresetsSubtitle": MessageLookupByLibrary.simpleMessage(
            "Àpats guardats"),
        "addItemMenuRecentlyLabel": MessageLookupByLibrary.simpleMessage(
            "Recents"),
        "addItemMenuRecentlySubtitle": MessageLookupByLibrary.simpleMessage(
            "Tornar a registrar"),
        "addItemMenuScanProductLabel": MessageLookupByLibrary.simpleMessage(
            "Escanejar producte"),
        "addItemMenuScanProductSubtitle": MessageLookupByLibrary.simpleMessage(
            "Codi de barres"),
        "addItemMenuSearchLabel": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "addItemMenuSearchSubtitle": MessageLookupByLibrary.simpleMessage(
            "Base de dades d\'aliments"),
        "addItemWeightExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., la pesada d\'este matí"),
        "addLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir"),
        "additionalInfoLabelBedca": MessageLookupByLibrary.simpleMessage(
            "Més informació a\nBEDCA (AESAN)"),
        "additionalInfoLabelCompendium2011": MessageLookupByLibrary.simpleMessage(
            "Informació proporcionada\n pel \n\'2024 Compendium\n of Physical Activities\'"),
        "additionalInfoLabelCustom": MessageLookupByLibrary.simpleMessage(
            "Aliment personalitzat"),
        "additionalInfoLabelFDC": MessageLookupByLibrary.simpleMessage(
            "Més informació a\nFoodData Central"),
        "additionalInfoLabelOFF": MessageLookupByLibrary.simpleMessage(
            "Més informació a\nOpenFoodFacts"),
        "additionalInfoLabelUnknown": MessageLookupByLibrary.simpleMessage(
            "Aliment desconegut"),
        "ageLabel": MessageLookupByLibrary.simpleMessage(
            "Edat"),
        "allItemsLabel": MessageLookupByLibrary.simpleMessage(
            "Tots"),
        "alphaVersionName": MessageLookupByLibrary.simpleMessage(
            "[Alfa]"),
        "appDescription": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker és un comptador de calories i nutrients lliure i de codi obert que respecta la teua privacitat."),
        "appLicenseLabel": MessageLookupByLibrary.simpleMessage(
            "Llicència GPL-3.0"),
        "appTitle": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker"),
        "appVersionName": m0,
        "appearanceTitle": MessageLookupByLibrary.simpleMessage(
            "Aparença"),
        "barcodeInvalidEan13CheckDigit": MessageLookupByLibrary.simpleMessage(
            "Pareix que este codi de 13 dígits està mal escrit: l\'últim dígit no quadra amb la resta"),
        "baseQuantityLabel": MessageLookupByLibrary.simpleMessage(
            "Quantitat base (g/ml)"),
        "bedcaDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Font: AESAN/BEDCA Base de Datos Española de Composición de Alimentos v1.0 (2010). Els valors són per 100 g de porció comestible. Les dades s\'oferixen per a ús personal i no comercial; no es garantix que siguen exactes ni completes."),
        "betaVersionName": MessageLookupByLibrary.simpleMessage(
            "[Beta]"),
        "bmiInfo": MessageLookupByLibrary.simpleMessage(
            "L\'índex de massa corporal (IMC) és un índex per a classificar el sobrepés i l\'obesitat en adults. Es definix com el pes en quilograms dividit pel quadrat de l\'altura en metres (kg/m²).\n\nL\'IMC no distingix entre massa greixosa i massa muscular i pot ser enganyós per a algunes persones."),
        "bmiLabel": MessageLookupByLibrary.simpleMessage(
            "IMC"),
        "bodyMeasurementsAddEntry": MessageLookupByLibrary.simpleMessage(
            "Afegir un registre"),
        "bodyMeasurementsBicepsLabel": MessageLookupByLibrary.simpleMessage(
            "Bíceps"),
        "bodyMeasurementsChartEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra almenys dues entrades d\'esta mesura per a vore\'n la tendència."),
        "bodyMeasurementsChestLabel": MessageLookupByLibrary.simpleMessage(
            "Pit"),
        "bodyMeasurementsCompareAfterLabel": MessageLookupByLibrary.simpleMessage(
            "Després"),
        "bodyMeasurementsCompareBackgroundDarkLabel": MessageLookupByLibrary.simpleMessage(
            "Fosc"),
        "bodyMeasurementsCompareBackgroundLabel": MessageLookupByLibrary.simpleMessage(
            "Fons"),
        "bodyMeasurementsCompareBackgroundWhiteLabel": MessageLookupByLibrary.simpleMessage(
            "Blanc"),
        "bodyMeasurementsCompareBeforeLabel": MessageLookupByLibrary.simpleMessage(
            "Abans"),
        "bodyMeasurementsCompareEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha fotos de progrés amb este angle."),
        "bodyMeasurementsCompareSelectDateLabel": MessageLookupByLibrary.simpleMessage(
            "Seleccionar la data"),
        "bodyMeasurementsCompareShareTooltip": MessageLookupByLibrary.simpleMessage(
            "Compartir"),
        "bodyMeasurementsCompareTitle": MessageLookupByLibrary.simpleMessage(
            "Comparar fotos"),
        "bodyMeasurementsCompareTooltip": MessageLookupByLibrary.simpleMessage(
            "Comparar fotos"),
        "bodyMeasurementsDateLabel": MessageLookupByLibrary.simpleMessage(
            "Data"),
        "bodyMeasurementsHipsLabel": MessageLookupByLibrary.simpleMessage(
            "Maluc"),
        "bodyMeasurementsNeckLabel": MessageLookupByLibrary.simpleMessage(
            "Coll"),
        "bodyMeasurementsNoEntries": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha mesures. Afig la primera per a començar a fer el seguiment."),
        "bodyMeasurementsNoteLabel": MessageLookupByLibrary.simpleMessage(
            "Nota (opcional)"),
        "bodyMeasurementsPhotoBackLabel": MessageLookupByLibrary.simpleMessage(
            "Esquena"),
        "bodyMeasurementsPhotoFrontLabel": MessageLookupByLibrary.simpleMessage(
            "Davant"),
        "bodyMeasurementsPhotoSideLabel": MessageLookupByLibrary.simpleMessage(
            "Perfil"),
        "bodyMeasurementsPhotosLabel": MessageLookupByLibrary.simpleMessage(
            "Fotos"),
        "bodyMeasurementsShouldersLabel": MessageLookupByLibrary.simpleMessage(
            "Muscles"),
        "bodyMeasurementsThighLabel": MessageLookupByLibrary.simpleMessage(
            "Cuixa"),
        "bodyMeasurementsWaistLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura"),
        "bodyMeasurementsWaistToHeightRatioLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura-altura"),
        "bodyMeasurementsWaistToHipRatioLabel": MessageLookupByLibrary.simpleMessage(
            "Cintura-maluc"),
        "breakfastExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., cereals, llet, café..."),
        "breakfastLabel": MessageLookupByLibrary.simpleMessage(
            "Esmorzar"),
        "burnedLabel": MessageLookupByLibrary.simpleMessage(
            "cremades"),
        "buttonNextLabel": MessageLookupByLibrary.simpleMessage(
            "SEGÜENT"),
        "buttonResetLabel": MessageLookupByLibrary.simpleMessage(
            "Restablir"),
        "buttonSaveLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar"),
        "buttonStartLabel": MessageLookupByLibrary.simpleMessage(
            "COMENÇAR"),
        "buttonYesLabel": MessageLookupByLibrary.simpleMessage(
            "SÍ"),
        "calciumLabel": MessageLookupByLibrary.simpleMessage(
            "calci"),
        "calculationsMacronutrientsDistributionLabel": MessageLookupByLibrary.simpleMessage(
            "Distribució de macros"),
        "calculationsMacrosDistribution": m1,
        "calculationsRecommendedLabel": MessageLookupByLibrary.simpleMessage(
            "(recomanat)"),
        "calculationsTDEEIOM2006Label": MessageLookupByLibrary.simpleMessage(
            "Equació de l\'Institute of Medicine (2005)"),
        "calculationsTDEELabel": MessageLookupByLibrary.simpleMessage(
            "Equació de TDEE"),
        "caloriesLabel": MessageLookupByLibrary.simpleMessage(
            "calories"),
        "caloriesProfileAveragedLabel": MessageLookupByLibrary.simpleMessage(
            "Referència mitjana (predeterminada)"),
        "caloriesProfileEstrogenTypicalLabel": MessageLookupByLibrary.simpleMessage(
            "Referència de perfil estrogènic"),
        "caloriesProfileInfoBody": MessageLookupByLibrary.simpleMessage(
            "No hi ha cap referència calòrica publicada per a persones no binàries: les equacions de referència es basen en mostres d\'hòmens i dones. Per defecte usem la mitjana de totes dues, un punt de partida neutre que no et demana revelar res més sobre el teu cos. El control de kcal de Configuració sempre està disponible per a afinar-ho; açò és un punt de partida, no una estimació precisa."),
        "caloriesProfileInfoTitle": MessageLookupByLibrary.simpleMessage(
            "Referència calòrica"),
        "caloriesProfileTestosteroneTypicalLabel": MessageLookupByLibrary.simpleMessage(
            "Referència de perfil testosterònic"),
        "carbohydrateLabel": MessageLookupByLibrary.simpleMessage(
            "carbohidrats"),
        "carbsLabel": MessageLookupByLibrary.simpleMessage(
            "carbohidrats"),
        "carbsLabelShort": MessageLookupByLibrary.simpleMessage(
            "c"),
        "cholesterolLabel": MessageLookupByLibrary.simpleMessage(
            "colesterol"),
        "chooseWeightGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Tria el teu objectiu de pes"),
        "clearOffCacheConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Elimina els resultats de busca i escaneig d\'Open Food Facts i FDC guardats en memòria cau al dispositiu. La memòria cau es torna a crear automàticament a mesura que busques i escaneges productes. Els teus aliments personalitzats no es veuen afectats."),
        "clearOffCacheConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols esborrar els elements en memòria cau?"),
        "clearOffCacheLabel": MessageLookupByLibrary.simpleMessage(
            "Esborrar elements en memòria cau"),
        "clearOffCacheSubtitle": m2,
        "cloudBackupPairInstructionsLabel": MessageLookupByLibrary.simpleMessage(
            "Escaneja el codi QR que apareix en l\'altre dispositiu o apega el codi de vinculació a mà."),
        "cloudBackupPairInvalidTokenError": MessageLookupByLibrary.simpleMessage(
            "Això no pareix un codi de vinculació vàlid"),
        "cloudBackupPairPasteHint": MessageLookupByLibrary.simpleMessage(
            "Apega ací el codi de vinculació"),
        "cloudBackupPairScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositiu"),
        "cloudBackupPairSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Dispositiu vinculat"),
        "cloudBackupTokenDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Codi de vinculació de la còpia en el núvol"),
        "cmLabel": MessageLookupByLibrary.simpleMessage(
            "cm"),
        "codeCopiedLabel": MessageLookupByLibrary.simpleMessage(
            "Codi copiat"),
        "copyActionLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar"),
        "copyCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar el codi"),
        "copyDayDialogTitle": MessageLookupByLibrary.simpleMessage(
            "A quina data o dates copies este dia?"),
        "copyDialogDateLabel": MessageLookupByLibrary.simpleMessage(
            "Data"),
        "copyDialogTitle": MessageLookupByLibrary.simpleMessage(
            "A quin àpat i dia ho copies?"),
        "copyOrDeleteTimeDialogContent": MessageLookupByLibrary.simpleMessage(
            "Amb \"Copiar\" pots copiar l\'àpat a un altre lloc. Amb \"Eliminar\" pots eliminar-lo."),
        "copyOrDeleteTimeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Què vols fer?"),
        "createCustomDialogContent": MessageLookupByLibrary.simpleMessage(
            "Vols crear un aliment personalitzat?"),
        "createCustomDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Vols crear un aliment personalitzat?"),
        "createRecipeTitle": MessageLookupByLibrary.simpleMessage(
            "Crear recepta"),
        "csvImportContributeOffAndroidLink": MessageLookupByLibrary.simpleMessage(
            "Android"),
        "csvImportContributeOffIosLink": MessageLookupByLibrary.simpleMessage(
            "iOS"),
        "csvImportContributeOffPrefix": MessageLookupByLibrary.simpleMessage(
            "Té codi de barres? Ajuda tothom aportant el producte a Open Food Facts:"),
        "csvImportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut llegir el fitxer CSV. Revisa el format i torna-ho a provar."),
        "csvImportPartialLabel": m3,
        "csvImportSuccessLabel": m4,
        "customActivityDescription": MessageLookupByLibrary.simpleMessage(
            "Introduïx directament les calories cremades, per a entrenaments que no estan en la llista o lectures d\'una polsera d\'activitat"),
        "customActivityDescriptionKj": MessageLookupByLibrary.simpleMessage(
            "Introduïx directament els quilojoules cremats, per a entrenaments que no estan en la llista o lectures d\'una polsera d\'activitat"),
        "customActivityKcalHint": MessageLookupByLibrary.simpleMessage(
            "p. ex., 250"),
        "customActivityKcalLabel": MessageLookupByLibrary.simpleMessage(
            "Calories cremades"),
        "customActivityName": MessageLookupByLibrary.simpleMessage(
            "Activitat personalitzada"),
        "customActivityNameFieldHint": MessageLookupByLibrary.simpleMessage(
            "p. ex., tornada en bici de la faena"),
        "customActivityNameFieldLabel": MessageLookupByLibrary.simpleMessage(
            "Nom (opcional)"),
        "customActivityPickFromTemplate": MessageLookupByLibrary.simpleMessage(
            "Triar de les plantilles guardades"),
        "customActivitySaveAsTemplate": MessageLookupByLibrary.simpleMessage(
            "Guardar com a plantilla per a la pròxima vegada"),
        "customActivityTemplatesEmpty": MessageLookupByLibrary.simpleMessage(
            "Encara no has guardat cap plantilla. Marca \"Guardar com a plantilla per a la pròxima vegada\" per a recordar una activitat personalitzada més avant."),
        "customMealBarcodeHint": MessageLookupByLibrary.simpleMessage(
            "Escaneja o escriu un codi de barres per a recuperar este aliment més avant"),
        "customMealBarcodeInvalid": MessageLookupByLibrary.simpleMessage(
            "El codi de barres ha de tindre entre 8 i 14 dígits"),
        "customMealBarcodeLabel": MessageLookupByLibrary.simpleMessage(
            "Codi de barres"),
        "customMealBarcodeScanButton": MessageLookupByLibrary.simpleMessage(
            "Escanejar el codi de barres"),
        "customMealFormAdvanced": MessageLookupByLibrary.simpleMessage(
            "Avançat"),
        "customMealFormAdvancedHelp": MessageLookupByLibrary.simpleMessage(
            "Definix la quantitat base i els valors per 100 per a escalar amb precisió."),
        "customMealFormModeLabel": MessageLookupByLibrary.simpleMessage(
            "Vista del formulari"),
        "customMealFormSimple": MessageLookupByLibrary.simpleMessage(
            "Senzill"),
        "customMealFormSimpleFieldHelper": m5,
        "customMealFormSimpleHelp": MessageLookupByLibrary.simpleMessage(
            "Escriu els totals d\'una ració."),
        "customMealsDeleteConfirmContent": MessageLookupByLibrary.simpleMessage(
            "També s\'eliminaran totes les entrades del diari que usen este aliment."),
        "customMealsDeleteConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar l\'aliment personalitzat?"),
        "customMealsEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Encara no has guardat aliments personalitzats."),
        "customMealsMergeAction": MessageLookupByLibrary.simpleMessage(
            "Combinar amb un altre aliment personalitzat"),
        "customMealsMergeChooseSurvivorTitle": MessageLookupByLibrary.simpleMessage(
            "Quin es queda?"),
        "customMealsMergeConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Combinar"),
        "customMealsMergeConfirmContent": m6,
        "customMealsMergeConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols combinar els aliments personalitzats?"),
        "customMealsMergeContinueAction": MessageLookupByLibrary.simpleMessage(
            "Continuar"),
        "customMealsMergePickerTitle": MessageLookupByLibrary.simpleMessage(
            "Tria l\'aliment personalitzat amb què combinar"),
        "customMealsMergeSuccessSnackbarOne": m7,
        "customMealsMergeSuccessSnackbarOther": m8,
        "customMealsRowMoreTooltip": MessageLookupByLibrary.simpleMessage(
            "Més accions"),
        "dailyKcalAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajust diari de kcal:"),
        "dailyKjAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajust diari de kJ:"),
        "dataCollectionLabel": MessageLookupByLibrary.simpleMessage(
            "Enviar informes d\'errors anònims per a ajudar a corregir fallades. No s\'inclou el registre d\'àpats, el pes ni cap dada personal."),
        "dayCopiedSnackbar": m9,
        "deleteAllLabel": MessageLookupByLibrary.simpleMessage(
            "Eliminar-ho tot"),
        "deleteSelectedRecipesConfirmTitle": m10,
        "deleteTimeDialogContent": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar l\'element seleccionat?"),
        "deleteTimeDialogPluralContent": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar tots els elements d\'este àpat?"),
        "deleteTimeDialogPluralTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar els elements?"),
        "deleteTimeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar l\'element?"),
        "dialogCancelLabel": MessageLookupByLibrary.simpleMessage(
            "CANCEL·LAR"),
        "dialogCloseLabel": MessageLookupByLibrary.simpleMessage(
            "Tancar"),
        "dialogCopyLabel": MessageLookupByLibrary.simpleMessage(
            "Copiar a hui"),
        "dialogDeleteLabel": MessageLookupByLibrary.simpleMessage(
            "ELIMINAR"),
        "dialogOKLabel": MessageLookupByLibrary.simpleMessage(
            "D\'acord"),
        "diaryFutureDateWarning": MessageLookupByLibrary.simpleMessage(
            "Estàs editant una data futura"),
        "diaryLabel": MessageLookupByLibrary.simpleMessage(
            "Diari"),
        "diaryMealKcalConsumedOfTarget": m11,
        "diaryNutrientPanelDataDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Ací només se sumen els nutrients registrats en els àpats que has anotat. Un aliment sense un valor no aporta res a eixe nutrient, així que estos totals poden quedar-se curts."),
        "diaryNutrientPanelTitle": MessageLookupByLibrary.simpleMessage(
            "Nutrients de hui"),
        "diarySortByCarbs": MessageLookupByLibrary.simpleMessage(
            "Carbohidrats (de més a menys)"),
        "diarySortByFat": MessageLookupByLibrary.simpleMessage(
            "Greixos (de més a menys)"),
        "diarySortByKcal": MessageLookupByLibrary.simpleMessage(
            "Calories (de més a menys)"),
        "diarySortByLabel": MessageLookupByLibrary.simpleMessage(
            "Ordenar per"),
        "diarySortByProtein": MessageLookupByLibrary.simpleMessage(
            "Proteïnes (de més a menys)"),
        "diarySortByTime": MessageLookupByLibrary.simpleMessage(
            "Hora de registre"),
        "diaryWeeklyBarsTitle": MessageLookupByLibrary.simpleMessage(
            "Esta setmana"),
        "dinnerExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., sopa, pollastre, vi..."),
        "dinnerLabel": MessageLookupByLibrary.simpleMessage(
            "Sopar"),
        "discardChangesConfirmLabel": MessageLookupByLibrary.simpleMessage(
            "Descartar"),
        "discardChangesContent": MessageLookupByLibrary.simpleMessage(
            "Es perdran els canvis sense guardar."),
        "discardChangesTitle": MessageLookupByLibrary.simpleMessage(
            "Vols descartar els canvis?"),
        "disclaimerText": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker no és una aplicació mèdica. Les dades proporcionades no estan validades i s\'han d\'usar amb precaució. Mantín un estil de vida saludable i consulta un professional si tens qualsevol problema. No se\'n recomana l\'ús durant una malaltia, l\'embaràs o la lactància. Per a vore les fonts revisades per experts de cada càlcul, toca la icona d\'informació en la pantalla d\'Inici o de Perfil."),
        "downloadSampleCsvAction": MessageLookupByLibrary.simpleMessage(
            "Aliments d\'exemple (csv)"),
        "downloadSampleJsonAction": MessageLookupByLibrary.simpleMessage(
            "Aliments d\'exemple (json)"),
        "downloadSampleRecipesCsvAction": MessageLookupByLibrary.simpleMessage(
            "Receptes d\'exemple (csv)"),
        "downloadSampleRecipesJsonAction": MessageLookupByLibrary.simpleMessage(
            "Receptes d\'exemple (json)"),
        "driPanelInfoBody": MessageLookupByLibrary.simpleMessage(
            "Estes quantitats de referència provenen de les ingestes dietètiques de referència (DRI) de l\'IOM per a adults i varien segons l\'edat i el sexe. Són un punt de referència, no un objectiu: les teues necessitats poden ser diferents."),
        "driPanelInfoLinkLabel": MessageLookupByLibrary.simpleMessage(
            "Font: IOM Dietary Reference Intakes"),
        "driPanelInfoTitle": MessageLookupByLibrary.simpleMessage(
            "Ingesta de referència"),
        "driPanelReferenceLabel": m12,
        "duplicateMealDialogContent": MessageLookupByLibrary.simpleMessage(
            "Este aliment ja s\'ha afegit hui a este àpat. Vols afegir-lo una altra vegada?"),
        "duplicateRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Duplicar"),
        "duplicateRecipeNameSuffix": MessageLookupByLibrary.simpleMessage(
            "(còpia)"),
        "editItemDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Editar l\'element"),
        "editMealLabel": MessageLookupByLibrary.simpleMessage(
            "Editar l\'aliment"),
        "editRecipeTitle": MessageLookupByLibrary.simpleMessage(
            "Editar la recepta"),
        "energyLabel": MessageLookupByLibrary.simpleMessage(
            "energia"),
        "energyLeftLabel": MessageLookupByLibrary.simpleMessage(
            "restants"),
        "energyTooMuchLabel": MessageLookupByLibrary.simpleMessage(
            "de més"),
        "energyUnitKcalLabel": MessageLookupByLibrary.simpleMessage(
            "Quilocalories (kcal)"),
        "energyUnitKjLabel": MessageLookupByLibrary.simpleMessage(
            "Quilojoules (kJ)"),
        "errorFetchingProductData": MessageLookupByLibrary.simpleMessage(
            "Error en obtindre les dades del producte"),
        "errorLoadingActivities": MessageLookupByLibrary.simpleMessage(
            "Error en carregar les activitats"),
        "errorMealSave": MessageLookupByLibrary.simpleMessage(
            "Error en guardar l\'aliment. Has introduït bé la informació?"),
        "errorOpeningBrowser": MessageLookupByLibrary.simpleMessage(
            "Error en obrir el navegador"),
        "errorOpeningEmail": MessageLookupByLibrary.simpleMessage(
            "Error en obrir l\'aplicació de correu"),
        "errorProductNotFound": MessageLookupByLibrary.simpleMessage(
            "No s\'ha trobat el producte"),
        "exportAction": MessageLookupByLibrary.simpleMessage(
            "Exportar"),
        "exportImportAppDataLabel": MessageLookupByLibrary.simpleMessage(
            "Exportar / Importar dades de l\'aplicació"),
        "exportImportCsvRecipesNote": MessageLookupByLibrary.simpleMessage(
            "El CSV conserva les activitats, el registre d\'àpats i els dies registrats. Les receptes i les fotos que hages adjuntat només van en JSON; canvia a JSON si vols incloure-les en la còpia."),
        "exportImportDescription": MessageLookupByLibrary.simpleMessage(
            "Pots exportar les dades de l\'aplicació a un fitxer zip i importar-les més tard. És útil si vols fer una còpia de seguretat de les teues dades o passar-les a un altre dispositiu.\n\nL\'aplicació no usa cap servici en el núvol per a guardar les teues dades."),
        "exportImportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error en exportar / importar"),
        "exportImportIncludeProgressPhotosLabel": MessageLookupByLibrary.simpleMessage(
            "Incloure fotos de progrés"),
        "exportImportSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Exportació / importació correcta"),
        "fastingAddPast": MessageLookupByLibrary.simpleMessage(
            "Afegir un dejuni passat"),
        "fastingCancel": MessageLookupByLibrary.simpleMessage(
            "Acabar el dejuni"),
        "fastingCancelConfirmBody": MessageLookupByLibrary.simpleMessage(
            "Açò tancarà la sessió actual."),
        "fastingCancelConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols acabar el dejuni ara?"),
        "fastingComplete": MessageLookupByLibrary.simpleMessage(
            "Sessió completada"),
        "fastingDeleteBody": MessageLookupByLibrary.simpleMessage(
            "El registre s\'eliminarà del teu historial."),
        "fastingDeleteTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar este dejuni?"),
        "fastingEditStart": MessageLookupByLibrary.simpleMessage(
            "Editar l\'hora d\'inici"),
        "fastingElapsedLabel": MessageLookupByLibrary.simpleMessage(
            "Transcorregut"),
        "fastingEndNow": MessageLookupByLibrary.simpleMessage(
            "Ara mateix"),
        "fastingEndPick": MessageLookupByLibrary.simpleMessage(
            "Triar l\'hora"),
        "fastingEndTitle": MessageLookupByLibrary.simpleMessage(
            "Quan vas menjar?"),
        "fastingEndedSummary": m13,
        "fastingErrorEndBeforeStart": MessageLookupByLibrary.simpleMessage(
            "El final ha de ser posterior a l\'inici."),
        "fastingErrorEndInFuture": MessageLookupByLibrary.simpleMessage(
            "El final no pot estar en el futur."),
        "fastingErrorOverlaps": MessageLookupByLibrary.simpleMessage(
            "Se solapa amb un altre dejuni del teu historial."),
        "fastingErrorStartInFuture": MessageLookupByLibrary.simpleMessage(
            "L\'inici no pot estar en el futur."),
        "fastingErrorTarget": m14,
        "fastingErrorTooLong": MessageLookupByLibrary.simpleMessage(
            "Un registre no pot durar més de 7 dies."),
        "fastingExtendedAccept": MessageLookupByLibrary.simpleMessage(
            "Un metge m\'està supervisant"),
        "fastingExtendedBody": MessageLookupByLibrary.simpleMessage(
            "Els dejunis de més de 24 hores comporten més riscos: baixades de sucre, deshidratació, desequilibris de sals i problemes en tornar a menjar. Fes-los només amb supervisió mèdica."),
        "fastingExtendedTitle": MessageLookupByLibrary.simpleMessage(
            "Dejunis de més de 24 hores"),
        "fastingHistoryEmpty": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha dejunis registrats."),
        "fastingHistorySummary": m15,
        "fastingHistoryTitle": MessageLookupByLibrary.simpleMessage(
            "Historial"),
        "fastingHomeChipBody": m16,
        "fastingHomeChipReached": m17,
        "fastingLinkBastyr": MessageLookupByLibrary.simpleMessage(
            "Bastyr University: quan cal evitar el dejuni intermitent"),
        "fastingLinkBeat": MessageLookupByLibrary.simpleMessage(
            "BEAT (Regne Unit)"),
        "fastingLinkNeda": MessageLookupByLibrary.simpleMessage(
            "NEDA (EUA)"),
        "fastingLinkWashU": MessageLookupByLibrary.simpleMessage(
            "WashU Physicians: guia sobre el dejuni intermitent"),
        "fastingNotMedicalAdvice": MessageLookupByLibrary.simpleMessage(
            "Este temporitzador no és consell mèdic. Fonts:"),
        "fastingNotificationChannelDescription": MessageLookupByLibrary.simpleMessage(
            "Avisos puntuals quan una sessió de dejuni arriba al seu objectiu."),
        "fastingNotificationChannelName": MessageLookupByLibrary.simpleMessage(
            "Temporitzador de dejuni"),
        "fastingNotificationCompleteBody": MessageLookupByLibrary.simpleMessage(
            "Has arribat al temps objectiu."),
        "fastingNotificationCompleteTitle": MessageLookupByLibrary.simpleMessage(
            "Sessió de dejuni completada"),
        "fastingOver24Notice": MessageLookupByLibrary.simpleMessage(
            "Portes més de 24 hores en dejuni. Els dejunis tan llargs han d\'estar supervisats per un metge. Beu aigua i acaba el dejuni si et trobes malament."),
        "fastingOver72Notice": MessageLookupByLibrary.simpleMessage(
            "Esta sessió porta oberta més de 3 dies. Si ja has menjat, acaba-la i indica l\'hora en què vas menjar."),
        "fastingPastTarget": m18,
        "fastingPresetCustom": MessageLookupByLibrary.simpleMessage(
            "Personalitzat"),
        "fastingRecordAddTitle": MessageLookupByLibrary.simpleMessage(
            "Afegir un dejuni"),
        "fastingRecordEditTitle": MessageLookupByLibrary.simpleMessage(
            "Editar el dejuni"),
        "fastingRecordEnd": MessageLookupByLibrary.simpleMessage(
            "Final"),
        "fastingRecordStart": MessageLookupByLibrary.simpleMessage(
            "Inici"),
        "fastingRecordTarget": MessageLookupByLibrary.simpleMessage(
            "Objectiu (hores)"),
        "fastingRemainingValue": m19,
        "fastingSafetyTitle": MessageLookupByLibrary.simpleMessage(
            "Dejunar amb seguretat"),
        "fastingSafetyTooltip": MessageLookupByLibrary.simpleMessage(
            "Seguretat del dejuni"),
        "fastingStart": MessageLookupByLibrary.simpleMessage(
            "Iniciar el temporitzador"),
        "fastingStartedAt": m20,
        "fastingStopIfUnwell": MessageLookupByLibrary.simpleMessage(
            "Para i menja si notes mareig, debilitat, tremolors, confusió o malestar. Busca ajuda mèdica si no se\'t passa."),
        "fastingSubtitle": MessageLookupByLibrary.simpleMessage(
            "Un temporitzador per al temps entre àpats, amb el teu propi historial. Sense ratxes ni puntuacions."),
        "fastingTargetReached": MessageLookupByLibrary.simpleMessage(
            "Objectiu assolit"),
        "fastingTargetValue": m21,
        "fastingTitle": MessageLookupByLibrary.simpleMessage(
            "Temporitzador de dejuni"),
        "fastingWarningAccept": MessageLookupByLibrary.simpleMessage(
            "Ho entenc, activar el temporitzador"),
        "fastingWarningBody": MessageLookupByLibrary.simpleMessage(
            "Controlar el temps de dejuni pot ajudar algunes persones i perjudicar-ne d\'altres, sobretot les que tenen antecedents de trastorns de la conducta alimentària. Si és el teu cas, cuida\'t primer. Pots trobar suport en BEAT (Regne Unit) i NEDA (EUA)."),
        "fastingWarningDecline": MessageLookupByLibrary.simpleMessage(
            "No és per a mi"),
        "fastingWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Abans de començar"),
        "fastingWarningWhoList": MessageLookupByLibrary.simpleMessage(
            "• tens menys de 18 anys\n• estàs embarassada o dones el pit\n• tens diabetis o prens medicaments que abaixen el sucre en sang\n• tens o has tingut un trastorn de la conducta alimentària\n• tens un pes insuficient\n• tens una altra malaltia o prens medicació de manera habitual"),
        "fastingWarningWhoTitle": MessageLookupByLibrary.simpleMessage(
            "Parla amb un metge abans de dejunar si:"),
        "fatLabel": MessageLookupByLibrary.simpleMessage(
            "greixos"),
        "fatLabelShort": MessageLookupByLibrary.simpleMessage(
            "g"),
        "fiberLabel": MessageLookupByLibrary.simpleMessage(
            "fibra"),
        "flOzUnit": MessageLookupByLibrary.simpleMessage(
            "fl.oz"),
        "ftLabel": MessageLookupByLibrary.simpleMessage(
            "ft"),
        "genderFemaleLabel": MessageLookupByLibrary.simpleMessage(
            "dona"),
        "genderLabel": MessageLookupByLibrary.simpleMessage(
            "Sexe"),
        "genderMaleLabel": MessageLookupByLibrary.simpleMessage(
            "home"),
        "genderNonBinaryLabel": MessageLookupByLibrary.simpleMessage(
            "no binari"),
        "goalGainWeight": MessageLookupByLibrary.simpleMessage(
            "Guanyar pes"),
        "goalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu"),
        "goalLoseWeight": MessageLookupByLibrary.simpleMessage(
            "Perdre pes"),
        "goalMaintainWeight": MessageLookupByLibrary.simpleMessage(
            "Mantindre el pes"),
        "gramMilliliterUnit": MessageLookupByLibrary.simpleMessage(
            "g/ml"),
        "gramUnit": MessageLookupByLibrary.simpleMessage(
            "g"),
        "heightLabel": MessageLookupByLibrary.simpleMessage(
            "Altura"),
        "homeBodyMetricsCardTitle": MessageLookupByLibrary.simpleMessage(
            "Mesures corporals"),
        "homeBodyMetricsInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra una mesura corporal en Perfil per a vore les teues proporcions."),
        "homeEnergyBalanceLabel": MessageLookupByLibrary.simpleMessage(
            "Balanç energètic"),
        "homeExpenditureCardTitle": MessageLookupByLibrary.simpleMessage(
            "Últims 7 dies"),
        "homeExpenditureInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra almenys una setmana de pesades i àpats per a vore la teua despesa setmanal."),
        "homeExpenditureLabel": MessageLookupByLibrary.simpleMessage(
            "Despesa"),
        "homeGoalProgressCardTitle": MessageLookupByLibrary.simpleMessage(
            "Progrés de l\'objectiu"),
        "homeGoalProgressInsufficientData": MessageLookupByLibrary.simpleMessage(
            "Registra almenys una setmana de pesades per a vore el progrés del teu objectiu."),
        "homeLabel": MessageLookupByLibrary.simpleMessage(
            "Inici"),
        "homeLoggingHabitCardTitle": MessageLookupByLibrary.simpleMessage(
            "Hàbit de registre"),
        "homeWeighInHabitCardTitle": MessageLookupByLibrary.simpleMessage(
            "Hàbit de pesada"),
        "homeWeightTrendLabel": MessageLookupByLibrary.simpleMessage(
            "Pes de tendència"),
        "homeWeightTrendNoRecentData": MessageLookupByLibrary.simpleMessage(
            "Sense pesades en els últims 20 dies"),
        "homeWeightTrendRate": m22,
        "homeWeightTrendStable": MessageLookupByLibrary.simpleMessage(
            "Estable"),
        "hoursLabel": MessageLookupByLibrary.simpleMessage(
            "hores"),
        "importAction": MessageLookupByLibrary.simpleMessage(
            "Importar"),
        "importActivityConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Estes activitats s\'afegiran a hui."),
        "importActivityConfirmTitle": m23,
        "importActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Importar un entrenament compartit"),
        "importActivitySuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Entrenament importat"),
        "importCustomFoodDataDescription": MessageLookupByLibrary.simpleMessage(
            "Importa els teus aliments des d\'un fitxer CSV o apegant JSON. Descarrega un exemple per a vore l\'estructura esperada i els camps obligatoris."),
        "importCustomFoodDataLabel": MessageLookupByLibrary.simpleMessage(
            "Importar aliments personalitzats"),
        "importMealConfirmContent": m24,
        "importMealConfirmTitle": m25,
        "importMealErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Codi QR no vàlid"),
        "importMealLabel": MessageLookupByLibrary.simpleMessage(
            "Importar un àpat compartit"),
        "importMealSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Àpat importat"),
        "importMealsCsvAction": MessageLookupByLibrary.simpleMessage(
            "Importar aliments (csv)"),
        "importMealsJsonAction": MessageLookupByLibrary.simpleMessage(
            "Importar aliments (json)"),
        "importOffFetchFailedLabel": m26,
        "importRecipeConfirmContent": m27,
        "importRecipeErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut llegir el codi de la recepta"),
        "importRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Importar una recepta"),
        "importRecipeSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Recepta importada"),
        "importRecipesCsvAction": MessageLookupByLibrary.simpleMessage(
            "Importar receptes (csv)"),
        "importRecipesJsonAction": MessageLookupByLibrary.simpleMessage(
            "Importar receptes (json)"),
        "inLabel": MessageLookupByLibrary.simpleMessage(
            "in"),
        "inconsistentNutritionWarningBody": MessageLookupByLibrary.simpleMessage(
            "Estos valors no acaben de quadrar: les calories que has introduït no coincidixen amb l\'energia dels carbohidrats, greixos i proteïnes de baix. Vols guardar igualment o tornar-hi a mirar?"),
        "inconsistentNutritionWarningEdit": MessageLookupByLibrary.simpleMessage(
            "Tornar-hi a mirar"),
        "inconsistentNutritionWarningSaveAnyway": MessageLookupByLibrary.simpleMessage(
            "Guardar igualment"),
        "inconsistentNutritionWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Els números no acaben de quadrar"),
        "infoAddedActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Activitat afegida"),
        "infoAddedIntakeLabel": MessageLookupByLibrary.simpleMessage(
            "Ingesta afegida"),
        "ironLabel": MessageLookupByLibrary.simpleMessage(
            "ferro"),
        "itemDeletedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Element eliminat"),
        "itemMovedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Element mogut"),
        "itemUpdatedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Element actualitzat"),
        "kcalLabel": MessageLookupByLibrary.simpleMessage(
            "kcal"),
        "kcalLeftLabel": MessageLookupByLibrary.simpleMessage(
            "kcal restants"),
        "kcalTooMuchLabel": MessageLookupByLibrary.simpleMessage(
            "kcal de més"),
        "kgLabel": MessageLookupByLibrary.simpleMessage(
            "kg"),
        "kjLabel": MessageLookupByLibrary.simpleMessage(
            "kJ"),
        "lbsLabel": MessageLookupByLibrary.simpleMessage(
            "lbs"),
        "logWaterAmountLabel": m28,
        "logWaterDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Registrar aigua"),
        "logWaterNothingToUndoLabel": MessageLookupByLibrary.simpleMessage(
            "No hi ha res per desfer"),
        "logWaterUndoLabel": MessageLookupByLibrary.simpleMessage(
            "Desfer l\'últim"),
        "lowKcalWarningBody": m29,
        "lowKcalWarningTitle": MessageLookupByLibrary.simpleMessage(
            "Este objectiu diari és prou baix"),
        "lowKcalWarningViewDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Vore l\'avís legal"),
        "lunchExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., pizza, ensalada, arròs..."),
        "lunchLabel": MessageLookupByLibrary.simpleMessage(
            "Dinar"),
        "macroDistributionLabel": MessageLookupByLibrary.simpleMessage(
            "Distribució de macronutrients:"),
        "magicAddToDiaryButton": MessageLookupByLibrary.simpleMessage(
            "Afegir al diari"),
        "magicAddedToDiarySnackbar": MessageLookupByLibrary.simpleMessage(
            "Afegit al diari"),
        "magicAnalysisFailedError": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut analitzar; torna-ho a provar"),
        "magicAnalyzeButton": MessageLookupByLibrary.simpleMessage(
            "Analitzar"),
        "magicAnalyzingLabel": MessageLookupByLibrary.simpleMessage(
            "S\'està analitzant..."),
        "magicCameraButton": MessageLookupByLibrary.simpleMessage(
            "Càmera"),
        "magicDescribeFoodHint": MessageLookupByLibrary.simpleMessage(
            "Descriu el teu menjar (opcional si hi ha foto)..."),
        "magicEmptyResultError": MessageLookupByLibrary.simpleMessage(
            "No s\'ha identificat cap aliment"),
        "magicGalleryButton": MessageLookupByLibrary.simpleMessage(
            "Galeria"),
        "magicMealBreakdownLabel": MessageLookupByLibrary.simpleMessage(
            "Desglossament de l\'àpat"),
        "magicModelLabel": MessageLookupByLibrary.simpleMessage(
            "Model"),
        "magicNoApiKeyError": MessageLookupByLibrary.simpleMessage(
            "Primer configura la teua clau d\'API d\'OpenRouter en Configuració"),
        "magicNoInputError": MessageLookupByLibrary.simpleMessage(
            "Primer afig una foto o descriu el teu menjar"),
        "magicNoModelError": MessageLookupByLibrary.simpleMessage(
            "Primer tria un model"),
        "magicProviderLabel": MessageLookupByLibrary.simpleMessage(
            "Proveïdor"),
        "magicResultsTitle": MessageLookupByLibrary.simpleMessage(
            "Resultats"),
        "magicScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Màgia"),
        "magicSingleItemLabel": MessageLookupByLibrary.simpleMessage(
            "Un sol aliment"),
        "magnesiumLabel": MessageLookupByLibrary.simpleMessage(
            "magnesi"),
        "mealBrandsLabel": MessageLookupByLibrary.simpleMessage(
            "Marques"),
        "mealCarbsLabel": MessageLookupByLibrary.simpleMessage(
            "Carbohidrats"),
        "mealDetailCurrentSelectionLabel": m30,
        "mealDetailDayTotalLabel": m31,
        "mealEnergyLabel": MessageLookupByLibrary.simpleMessage(
            "Energia"),
        "mealFatLabel": MessageLookupByLibrary.simpleMessage(
            "Greixos"),
        "mealImageLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir una foto"),
        "mealImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Triar de la galeria"),
        "mealImageRemove": MessageLookupByLibrary.simpleMessage(
            "Llevar la foto"),
        "mealImageReplace": MessageLookupByLibrary.simpleMessage(
            "Canviar la foto"),
        "mealImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Fer una foto"),
        "mealKcalLabel": MessageLookupByLibrary.simpleMessage(
            "kcal"),
        "mealNameLabel": MessageLookupByLibrary.simpleMessage(
            "Nom de l\'aliment"),
        "mealNameValidationError": MessageLookupByLibrary.simpleMessage(
            "El nom de l\'aliment ha de contindre almenys una lletra"),
        "mealNutrientsPerQtyLabel": m32,
        "mealNutrientsTotalLabel": MessageLookupByLibrary.simpleMessage(
            "Quantitat total"),
        "mealPatternFiveSmall": MessageLookupByLibrary.simpleMessage(
            "Cinc menudes"),
        "mealPatternMediterranean": MessageLookupByLibrary.simpleMessage(
            "Mediterrani"),
        "mealPatternOmad": MessageLookupByLibrary.simpleMessage(
            "OMAD"),
        "mealPatternPresetsLabel": MessageLookupByLibrary.simpleMessage(
            "Opcions ràpides"),
        "mealPatternStandard": MessageLookupByLibrary.simpleMessage(
            "Estàndard"),
        "mealPatternTwoMeal": MessageLookupByLibrary.simpleMessage(
            "Dos àpats"),
        "mealProteinLabel": MessageLookupByLibrary.simpleMessage(
            "Proteïnes"),
        "mealSizeLabel": MessageLookupByLibrary.simpleMessage(
            "Grandària de la ració (g/ml)"),
        "mealSizeLabelImperial": MessageLookupByLibrary.simpleMessage(
            "Grandària de la ració (oz/fl oz)"),
        "mealUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unitat"),
        "micronutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Micronutrients"),
        "milliliterUnit": MessageLookupByLibrary.simpleMessage(
            "ml"),
        "missingProductInfo": MessageLookupByLibrary.simpleMessage(
            "Al producte li falten les kcal o els macronutrients obligatoris"),
        "mlLabel": MessageLookupByLibrary.simpleMessage(
            "ml"),
        "monounsaturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "greixos monoinsaturats"),
        "moveActionLabel": MessageLookupByLibrary.simpleMessage(
            "Moure"),
        "newCustomMealLabel": MessageLookupByLibrary.simpleMessage(
            "Aliment personalitzat nou"),
        "niacinLabel": MessageLookupByLibrary.simpleMessage(
            "niacina (B3)"),
        "noActivityRecentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hi ha activitats afegides recentment"),
        "noMealsRecentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hi ha aliments afegits recentment"),
        "noResultsFound": MessageLookupByLibrary.simpleMessage(
            "No s\'han trobat resultats"),
        "notAvailableLabel": MessageLookupByLibrary.simpleMessage(
            "N/D"),
        "nothingAddedLabel": MessageLookupByLibrary.simpleMessage(
            "No hi ha res afegit"),
        "notificationsDailyReminderBody": MessageLookupByLibrary.simpleMessage(
            "No oblides registrar els àpats de hui!"),
        "notificationsDailyReminderChannelDescription": MessageLookupByLibrary.simpleMessage(
            "Recordatori diari per a registrar àpats"),
        "notificationsDailyReminderChannelName": MessageLookupByLibrary.simpleMessage(
            "Recordatoris diaris"),
        "notificationsDailyReminderTitle": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker"),
        "notificationsPermissionDeniedSnack": MessageLookupByLibrary.simpleMessage(
            "Permís de notificacions denegat."),
        "nutrientPanelAllHiddenLabel": MessageLookupByLibrary.simpleMessage(
            "Tots els nutrients estan ocults: activa\'n algun en Configuració → Nutrients."),
        "nutrientPanelDayLabel": MessageLookupByLibrary.simpleMessage(
            "Dia"),
        "nutrientPanelLimitLabel": MessageLookupByLibrary.simpleMessage(
            "límit"),
        "nutrientPanelWeekLabel": MessageLookupByLibrary.simpleMessage(
            "Setmana"),
        "nutritionInfoLabel": MessageLookupByLibrary.simpleMessage(
            "Informació nutricional"),
        "nutritionalStatusNormalWeight": MessageLookupByLibrary.simpleMessage(
            "Pes normal"),
        "nutritionalStatusObeseClassI": MessageLookupByLibrary.simpleMessage(
            "Obesitat de classe I"),
        "nutritionalStatusObeseClassII": MessageLookupByLibrary.simpleMessage(
            "Obesitat de classe II"),
        "nutritionalStatusObeseClassIII": MessageLookupByLibrary.simpleMessage(
            "Obesitat de classe III"),
        "nutritionalStatusPreObesity": MessageLookupByLibrary.simpleMessage(
            "Preobesitat"),
        "nutritionalStatusRiskAverage": MessageLookupByLibrary.simpleMessage(
            "Mitjà"),
        "nutritionalStatusRiskIncreased": MessageLookupByLibrary.simpleMessage(
            "Augmentat"),
        "nutritionalStatusRiskLabel": m33,
        "nutritionalStatusRiskLow": MessageLookupByLibrary.simpleMessage(
            "Baix \n(però amb més risc d\'altres \nproblemes clínics)"),
        "nutritionalStatusRiskModerate": MessageLookupByLibrary.simpleMessage(
            "Moderat"),
        "nutritionalStatusRiskSevere": MessageLookupByLibrary.simpleMessage(
            "Greu"),
        "nutritionalStatusRiskVerySevere": MessageLookupByLibrary.simpleMessage(
            "Molt greu"),
        "nutritionalStatusUnderweight": MessageLookupByLibrary.simpleMessage(
            "Pes insuficient"),
        "offAccountCreateLink": MessageLookupByLibrary.simpleMessage(
            "Crear un compte gratuït"),
        "offAccountExplanation": MessageLookupByLibrary.simpleMessage(
            "Usa el teu nom d\'usuari d\'Open Food Facts (no el correu) i la contrasenya. Es guarden xifrats en este dispositiu i només s\'envien a Open Food Facts quan envies un producte."),
        "offAccountLabel": MessageLookupByLibrary.simpleMessage(
            "Compte d\'Open Food Facts"),
        "offAccountPasswordLabel": MessageLookupByLibrary.simpleMessage(
            "Contrasenya"),
        "offAccountSignOut": MessageLookupByLibrary.simpleMessage(
            "Tancar la sessió"),
        "offAccountSignedInAs": MessageLookupByLibrary.simpleMessage(
            "Sessió iniciada com a"),
        "offAccountSignedOutSubtitle": MessageLookupByLibrary.simpleMessage(
            "Inicia la sessió per a enviar a Open Food Facts els productes que afigues"),
        "offAccountUsernameLabel": MessageLookupByLibrary.simpleMessage(
            "Nom d\'usuari"),
        "offContributeAlreadyOnOff": MessageLookupByLibrary.simpleMessage(
            "Open Food Facts ja té este producte, així que no s\'ha enviat res."),
        "offContributeButton": MessageLookupByLibrary.simpleMessage(
            "Enviar a Open Food Facts"),
        "offContributeConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Açò crea un producte públic nou a Open Food Facts amb este codi de barres, nom, marca i els valors nutricionals per 100 g. Envia només valors copiats de l\'etiqueta de l\'envàs. Les contribucions es publiquen amb la llicència Open Database License (ODbL), de manera que qualsevol pot reutilitzar-les."),
        "offContributeConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols enviar-ho a Open Food Facts?"),
        "offContributeFailed": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut enviar el producte a Open Food Facts. Torna-ho a provar més tard."),
        "offContributeMissingData": MessageLookupByLibrary.simpleMessage(
            "Per a enviar un producte cal el codi de barres, el nom i l\'energia."),
        "offContributeNeedsAccount": MessageLookupByLibrary.simpleMessage(
            "Primer inicia la sessió amb el teu compte d\'Open Food Facts."),
        "offContributeSend": MessageLookupByLibrary.simpleMessage(
            "Enviar"),
        "offContributeSent": MessageLookupByLibrary.simpleMessage(
            "Gràcies! El producte ja està a Open Food Facts."),
        "offContributeWrongCredentials": MessageLookupByLibrary.simpleMessage(
            "Open Food Facts ha rebutjat el teu nom d\'usuari o la contrasenya."),
        "offDisclaimer": MessageLookupByLibrary.simpleMessage(
            "Les dades que t\'oferix esta aplicació provenen de la base de dades d\'Open Food Facts. No es pot garantir l\'exactitud, la integritat ni la fiabilitat de la informació proporcionada. Les dades s\'oferixen \"tal com estan\" i la font d\'origen de les dades (Open Food Facts) no es fa responsable de cap dany derivat del seu ús."),
        "onboardingActivityQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quant et mous? (sense comptar entrenaments)"),
        "onboardingBirthdayHint": MessageLookupByLibrary.simpleMessage(
            "Introduïx la data"),
        "onboardingBirthdayQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quan és el teu aniversari?"),
        "onboardingEnterBirthdayLabel": MessageLookupByLibrary.simpleMessage(
            "Data de naixement"),
        "onboardingGenderQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quin és el teu sexe?"),
        "onboardingGoalQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quin és el teu objectiu de pes actual?"),
        "onboardingHeightExampleHintCm": MessageLookupByLibrary.simpleMessage(
            "p. ex., 170"),
        "onboardingHeightExampleHintFt": MessageLookupByLibrary.simpleMessage(
            "p. ex., 5.8"),
        "onboardingHeightQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quant mesures?"),
        "onboardingIntroDescription": MessageLookupByLibrary.simpleMessage(
            "Per a començar, l\'aplicació necessita algunes dades sobre tu per a calcular el teu objectiu diari de calories.\nTota la teua informació es guarda de manera segura en el teu dispositiu."),
        "onboardingIntroSourcesLinkLabel": MessageLookupByLibrary.simpleMessage(
            "Consulta les nostres fonts per als càlculs mèdics"),
        "onboardingKcalPerDayLabel": MessageLookupByLibrary.simpleMessage(
            "kcal al dia"),
        "onboardingKjPerDayLabel": MessageLookupByLibrary.simpleMessage(
            "kJ al dia"),
        "onboardingNonBinaryDisclaimer": MessageLookupByLibrary.simpleMessage(
            "No hi ha cap referència calòrica publicada per a persones no binàries, així que per defecte usem la mitjana de les fórmules masculina i femenina: un punt de partida, no una estimació precisa. Pots afinar-ho quan vulgues en Configuració → Càlculs."),
        "onboardingOverviewLabel": MessageLookupByLibrary.simpleMessage(
            "Resum"),
        "onboardingRestoreFromCloudLabel": MessageLookupByLibrary.simpleMessage(
            "Ja tens una còpia en el núvol? Restaura-la"),
        "onboardingSaveUserError": MessageLookupByLibrary.simpleMessage(
            "Dades incorrectes, torna-ho a provar"),
        "onboardingTargetWeightHintOptional": MessageLookupByLibrary.simpleMessage(
            "Opcional"),
        "onboardingTargetWeightSubtitle": MessageLookupByLibrary.simpleMessage(
            "Tens un pes objectiu? Pots deixar-ho en blanc o canviar-ho més tard en Perfil."),
        "onboardingWeightExampleHintKg": MessageLookupByLibrary.simpleMessage(
            "p. ex., 60"),
        "onboardingWeightExampleHintLbs": MessageLookupByLibrary.simpleMessage(
            "p. ex., 132"),
        "onboardingWeightQuestionSubtitle": MessageLookupByLibrary.simpleMessage(
            "Quant peses ara?"),
        "onboardingWelcomeLabel": MessageLookupByLibrary.simpleMessage(
            "Et donem la benvinguda a"),
        "onboardingWrongHeightLabel": MessageLookupByLibrary.simpleMessage(
            "Introduïx una altura correcta"),
        "onboardingWrongWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Introduïx un pes correcte"),
        "onboardingYourGoalLabel": MessageLookupByLibrary.simpleMessage(
            "El teu objectiu de calories:"),
        "onboardingYourMacrosGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Els teus objectius de macronutrients:"),
        "openRouterApiKeyHint": MessageLookupByLibrary.simpleMessage(
            "sk-or-..."),
        "openRouterApiKeyLabel": MessageLookupByLibrary.simpleMessage(
            "Clau d\'API"),
        "openRouterApiKeySavedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Clau d\'API guardada"),
        "openRouterModelSearchHint": MessageLookupByLibrary.simpleMessage(
            "Buscar models"),
        "openRouterModelSectionTitle": MessageLookupByLibrary.simpleMessage(
            "Model"),
        "openRouterModelsEmptyState": MessageLookupByLibrary.simpleMessage(
            "Cap model coincidix amb la busca"),
        "openRouterModelsLoadError": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut carregar el catàleg de models"),
        "openRouterSettingsTitle": MessageLookupByLibrary.simpleMessage(
            "OpenRouter"),
        "openRouterVisionBadgeTooltip": MessageLookupByLibrary.simpleMessage(
            "Admet imatges"),
        "ozUnit": MessageLookupByLibrary.simpleMessage(
            "oz"),
        "paActiveVideoGames": MessageLookupByLibrary.simpleMessage(
            "videojocs actius"),
        "paActiveVideoGamesDesc": MessageLookupByLibrary.simpleMessage(
            "Wii Sports, Dance Dance Revolution, general"),
        "paAmericanFootballGeneral": MessageLookupByLibrary.simpleMessage(
            "futbol americà"),
        "paAmericanFootballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "touch, flag, general"),
        "paArcheryGeneral": MessageLookupByLibrary.simpleMessage(
            "tir amb arc"),
        "paArcheryGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sense caça"),
        "paAutoRacing": MessageLookupByLibrary.simpleMessage(
            "carreres de cotxes"),
        "paAutoRacingDesc": MessageLookupByLibrary.simpleMessage(
            "monoplaça"),
        "paBackpackingGeneral": MessageLookupByLibrary.simpleMessage(
            "senderisme amb motxilla"),
        "paBackpackingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBadmintonGeneral": MessageLookupByLibrary.simpleMessage(
            "bàdminton"),
        "paBadmintonGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "individual i dobles recreatiu, general"),
        "paBasketballGeneral": MessageLookupByLibrary.simpleMessage(
            "bàsquet"),
        "paBasketballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingGeneral": MessageLookupByLibrary.simpleMessage(
            "ciclisme"),
        "paBicyclingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingMountainGeneral": MessageLookupByLibrary.simpleMessage(
            "ciclisme de muntanya"),
        "paBicyclingMountainGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBicyclingStationaryGeneral": MessageLookupByLibrary.simpleMessage(
            "bicicleta estàtica"),
        "paBicyclingStationaryGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBilliardsGeneral": MessageLookupByLibrary.simpleMessage(
            "billar"),
        "paBilliardsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBowlingGeneral": MessageLookupByLibrary.simpleMessage(
            "bitlles"),
        "paBowlingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paBoxingBag": MessageLookupByLibrary.simpleMessage(
            "boxa"),
        "paBoxingBagDesc": MessageLookupByLibrary.simpleMessage(
            "sac de boxa"),
        "paBoxingGeneral": MessageLookupByLibrary.simpleMessage(
            "boxa"),
        "paBoxingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "en ring, general"),
        "paBroomball": MessageLookupByLibrary.simpleMessage(
            "broomball"),
        "paBroomballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paCalisthenicsGeneral": MessageLookupByLibrary.simpleMessage(
            "calistènia"),
        "paCalisthenicsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "esforç lleuger o moderat, general (p. ex., exercicis d\'esquena)"),
        "paCanoeingGeneral": MessageLookupByLibrary.simpleMessage(
            "piragüisme"),
        "paCanoeingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "rem recreatiu, general"),
        "paCatch": MessageLookupByLibrary.simpleMessage(
            "futbol americà o beisbol"),
        "paCatchDesc": MessageLookupByLibrary.simpleMessage(
            "passar-se la pilota"),
        "paCheerleading": MessageLookupByLibrary.simpleMessage(
            "animació esportiva"),
        "paCheerleadingDesc": MessageLookupByLibrary.simpleMessage(
            "moviments gimnàstics, de competició"),
        "paChildrenGame": MessageLookupByLibrary.simpleMessage(
            "jocs infantils"),
        "paChildrenGameDesc": MessageLookupByLibrary.simpleMessage(
            "(p. ex., xarranca, quatre quadres, pilota presonera, gronxadors i tobogans, t-ball, tetherball, bales, màquines recreatives), esforç moderat"),
        "paClimbingHillsNoLoadGeneral": MessageLookupByLibrary.simpleMessage(
            "pujar costeres, sense càrrega"),
        "paClimbingHillsNoLoadGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sense càrrega"),
        "paCricket": MessageLookupByLibrary.simpleMessage(
            "criquet"),
        "paCricketDesc": MessageLookupByLibrary.simpleMessage(
            "batejar, llançar, defendre"),
        "paCroquet": MessageLookupByLibrary.simpleMessage(
            "croquet"),
        "paCroquetDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paCrossCountrySkiing": MessageLookupByLibrary.simpleMessage(
            "esquí de fons"),
        "paCrossCountrySkiingDesc": MessageLookupByLibrary.simpleMessage(
            "de fons, general"),
        "paCurling": MessageLookupByLibrary.simpleMessage(
            "cúrling"),
        "paCurlingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paDancingAerobicGeneral": MessageLookupByLibrary.simpleMessage(
            "aeròbic"),
        "paDancingAerobicGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paDancingGeneral": MessageLookupByLibrary.simpleMessage(
            "ball en general"),
        "paDancingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "p. ex., disco, folklòric, claqué irlandés, ball en línia, polca, contradansa, country"),
        "paDartsWall": MessageLookupByLibrary.simpleMessage(
            "dards"),
        "paDartsWallDesc": MessageLookupByLibrary.simpleMessage(
            "de paret o de gespa"),
        "paDivingGeneral": MessageLookupByLibrary.simpleMessage(
            "busseig"),
        "paDivingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "busseig en apnea, submarinisme, general"),
        "paDivingSpringboardPlatform": MessageLookupByLibrary.simpleMessage(
            "salts"),
        "paDivingSpringboardPlatformDesc": MessageLookupByLibrary.simpleMessage(
            "trampolí o plataforma"),
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
            "gimnàstica"),
        "paGymnasticsGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHackySack": MessageLookupByLibrary.simpleMessage(
            "hacky sack"),
        "paHackySackDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHandballGeneral": MessageLookupByLibrary.simpleMessage(
            "handbol"),
        "paHandballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHangGliding": MessageLookupByLibrary.simpleMessage(
            "ala delta"),
        "paHangGlidingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHeadingBicycling": MessageLookupByLibrary.simpleMessage(
            "ciclisme"),
        "paHeadingConditionalExercise": MessageLookupByLibrary.simpleMessage(
            "exercici de condicionament"),
        "paHeadingDancing": MessageLookupByLibrary.simpleMessage(
            "ball"),
        "paHeadingRunning": MessageLookupByLibrary.simpleMessage(
            "córrer"),
        "paHeadingSports": MessageLookupByLibrary.simpleMessage(
            "esports"),
        "paHeadingWalking": MessageLookupByLibrary.simpleMessage(
            "caminar"),
        "paHeadingWaterActivities": MessageLookupByLibrary.simpleMessage(
            "activitats aquàtiques"),
        "paHeadingWinterActivities": MessageLookupByLibrary.simpleMessage(
            "activitats d\'hivern"),
        "paHighIntensityIntervalExercise": MessageLookupByLibrary.simpleMessage(
            "exercici d\'intervals d\'alta intensitat"),
        "paHighIntensityIntervalExerciseDesc": MessageLookupByLibrary.simpleMessage(
            "esforç moderat"),
        "paHighIntensityIntervalExerciseVigorous": MessageLookupByLibrary.simpleMessage(
            "exercici d\'intervals d\'alta intensitat"),
        "paHighIntensityIntervalExerciseVigorousDesc": MessageLookupByLibrary.simpleMessage(
            "burpees, escaladors, esquats amb salt, Tabata, esforç intens"),
        "paHikingCrossCountry": MessageLookupByLibrary.simpleMessage(
            "senderisme"),
        "paHikingCrossCountryDesc": MessageLookupByLibrary.simpleMessage(
            "camp a través"),
        "paHockeyField": MessageLookupByLibrary.simpleMessage(
            "hoquei sobre herba"),
        "paHockeyFieldDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paHorseRidingGeneral": MessageLookupByLibrary.simpleMessage(
            "equitació"),
        "paHorseRidingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paIceHockeyGeneral": MessageLookupByLibrary.simpleMessage(
            "hoquei sobre gel"),
        "paIceHockeyGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paIceSkatingGeneral": MessageLookupByLibrary.simpleMessage(
            "patinatge sobre gel"),
        "paIceSkatingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJaiAlai": MessageLookupByLibrary.simpleMessage(
            "pilota basca"),
        "paJaiAlaiDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJoggingGeneral": MessageLookupByLibrary.simpleMessage(
            "córrer a ritme suau"),
        "paJoggingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paJuggling": MessageLookupByLibrary.simpleMessage(
            "malabars"),
        "paJugglingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paKayakingModerate": MessageLookupByLibrary.simpleMessage(
            "caiac"),
        "paKayakingModerateDesc": MessageLookupByLibrary.simpleMessage(
            "esforç moderat"),
        "paKickball": MessageLookupByLibrary.simpleMessage(
            "kickball"),
        "paKickballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paLacrosse": MessageLookupByLibrary.simpleMessage(
            "lacrosse"),
        "paLacrosseDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paLawnBowling": MessageLookupByLibrary.simpleMessage(
            "bitlles sobre gespa"),
        "paLawnBowlingDesc": MessageLookupByLibrary.simpleMessage(
            "petanca, a l\'aire lliure"),
        "paMartialArtsModerate": MessageLookupByLibrary.simpleMessage(
            "arts marcials"),
        "paMartialArtsModerateDesc": MessageLookupByLibrary.simpleMessage(
            "diversos tipus, ritme moderat (p. ex., judo, jiu-jitsu, karate, kickboxing, taekwondo, tae bo, boxa tailandesa)"),
        "paMartialArtsSlower": MessageLookupByLibrary.simpleMessage(
            "arts marcials"),
        "paMartialArtsSlowerDesc": MessageLookupByLibrary.simpleMessage(
            "diversos tipus, ritme més lent, principiants, pràctica"),
        "paMotoCross": MessageLookupByLibrary.simpleMessage(
            "motocròs"),
        "paMotoCrossDesc": MessageLookupByLibrary.simpleMessage(
            "esports de motor tot terreny, quad, general"),
        "paMountainClimbing": MessageLookupByLibrary.simpleMessage(
            "escalada"),
        "paMountainClimbingDesc": MessageLookupByLibrary.simpleMessage(
            "escalada en roca o alpinisme"),
        "paNordicWalking": MessageLookupByLibrary.simpleMessage(
            "marxa nòrdica"),
        "paOrienteering": MessageLookupByLibrary.simpleMessage(
            "orientació"),
        "paOrienteeringDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paPaddleBoarding": MessageLookupByLibrary.simpleMessage(
            "pàdel surf"),
        "paPaddleBoardingDesc": MessageLookupByLibrary.simpleMessage(
            "dret"),
        "paPaddleBoat": MessageLookupByLibrary.simpleMessage(
            "barca de pedals"),
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
            "a cavall"),
        "paRacquetball": MessageLookupByLibrary.simpleMessage(
            "raquetbol"),
        "paRacquetballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paResistanceTraining": MessageLookupByLibrary.simpleMessage(
            "entrenament de força"),
        "paResistanceTrainingDesc": MessageLookupByLibrary.simpleMessage(
            "alçament de pes, pes lliure, màquines"),
        "paResistanceTrainingVigorous": MessageLookupByLibrary.simpleMessage(
            "entrenament de força (intens)"),
        "paResistanceTrainingVigorousDesc": MessageLookupByLibrary.simpleMessage(
            "esforç intens, powerlifting o culturisme"),
        "paRodeoSportGeneralModerate": MessageLookupByLibrary.simpleMessage(
            "esports de rodeo"),
        "paRodeoSportGeneralModerateDesc": MessageLookupByLibrary.simpleMessage(
            "general, esforç moderat"),
        "paRollerbladingLight": MessageLookupByLibrary.simpleMessage(
            "patins en línia"),
        "paRollerbladingLightDesc": MessageLookupByLibrary.simpleMessage(
            "patinatge en línia"),
        "paRopeJumpingGeneral": MessageLookupByLibrary.simpleMessage(
            "botar a corda"),
        "paRopeJumpingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "ritme moderat, 100-120 bots/min, general, bot amb els dos peus, bot bàsic"),
        "paRopeSkippingGeneral": MessageLookupByLibrary.simpleMessage(
            "botar a corda"),
        "paRopeSkippingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paRugbyCompetitive": MessageLookupByLibrary.simpleMessage(
            "rugbi"),
        "paRugbyCompetitiveDesc": MessageLookupByLibrary.simpleMessage(
            "union, en equip, de competició"),
        "paRugbyNonCompetitive": MessageLookupByLibrary.simpleMessage(
            "rugbi"),
        "paRugbyNonCompetitiveDesc": MessageLookupByLibrary.simpleMessage(
            "touch, sense competició"),
        "paRunningGeneral": MessageLookupByLibrary.simpleMessage(
            "córrer"),
        "paRunningGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSailingGeneral": MessageLookupByLibrary.simpleMessage(
            "vela"),
        "paSailingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "vela en barca i taula, surf de vela, vela sobre gel, general"),
        "paShuffleboard": MessageLookupByLibrary.simpleMessage(
            "shuffleboard"),
        "paShuffleboardDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkateboardingGeneral": MessageLookupByLibrary.simpleMessage(
            "monopatí"),
        "paSkateboardingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general, esforç moderat"),
        "paSkatingRoller": MessageLookupByLibrary.simpleMessage(
            "patinatge sobre rodes"),
        "paSkatingRollerDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkiingGeneral": MessageLookupByLibrary.simpleMessage(
            "esquí"),
        "paSkiingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSkiingWaterWakeboarding": MessageLookupByLibrary.simpleMessage(
            "esquí aquàtic"),
        "paSkiingWaterWakeboardingDesc": MessageLookupByLibrary.simpleMessage(
            "esquí aquàtic o wakeboard"),
        "paSkydiving": MessageLookupByLibrary.simpleMessage(
            "paracaigudisme"),
        "paSkydivingDesc": MessageLookupByLibrary.simpleMessage(
            "paracaigudisme, salt BASE, pònting"),
        "paSnorkeling": MessageLookupByLibrary.simpleMessage(
            "busseig amb tub"),
        "paSnorkelingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paSnowShovingModerate": MessageLookupByLibrary.simpleMessage(
            "llevar neu amb pala"),
        "paSnowShovingModerateDesc": MessageLookupByLibrary.simpleMessage(
            "a mà, esforç moderat"),
        "paSnowshoeing": MessageLookupByLibrary.simpleMessage(
            "raquetes de neu"),
        "paSoccerGeneral": MessageLookupByLibrary.simpleMessage(
            "futbol"),
        "paSoccerGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "informal, general"),
        "paSoftballBaseballGeneral": MessageLookupByLibrary.simpleMessage(
            "softbol / beisbol"),
        "paSoftballBaseballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "llançament ràpid o lent, general"),
        "paSquashGeneral": MessageLookupByLibrary.simpleMessage(
            "esquaix"),
        "paSquashGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paStretching": MessageLookupByLibrary.simpleMessage(
            "estiraments"),
        "paStretchingDesc": MessageLookupByLibrary.simpleMessage(
            "suaus, general"),
        "paSurfing": MessageLookupByLibrary.simpleMessage(
            "surf"),
        "paSurfingDesc": MessageLookupByLibrary.simpleMessage(
            "bodyboard o taula, general"),
        "paSwimmingGeneral": MessageLookupByLibrary.simpleMessage(
            "natació"),
        "paSwimmingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "mantindre\'s a flotació, esforç moderat, general"),
        "paTableTennisGeneral": MessageLookupByLibrary.simpleMessage(
            "tennis de taula"),
        "paTableTennisGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "tennis de taula, ping-pong"),
        "paTaiChiQiGongGeneral": MessageLookupByLibrary.simpleMessage(
            "taitxí, qigong"),
        "paTaiChiQiGongGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paTennisGeneral": MessageLookupByLibrary.simpleMessage(
            "tennis"),
        "paTennisGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paTrackField": MessageLookupByLibrary.simpleMessage(
            "atletisme"),
        "paTrackField1Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ex., pes, disc, martell)"),
        "paTrackField2Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ex., salt d\'altura, salt de longitud, triple salt, javelina, salt amb perxa)"),
        "paTrackField3Desc": MessageLookupByLibrary.simpleMessage(
            "(p. ex., carrera d\'obstacles, tanques)"),
        "paTrampolineLight": MessageLookupByLibrary.simpleMessage(
            "llit elàstic"),
        "paTrampolineLightDesc": MessageLookupByLibrary.simpleMessage(
            "recreatiu"),
        "paTreadmillRunning": MessageLookupByLibrary.simpleMessage(
            "córrer en cinta"),
        "paTreadmillRunningDesc": MessageLookupByLibrary.simpleMessage(
            "en cinta, general"),
        "paUnicyclingGeneral": MessageLookupByLibrary.simpleMessage(
            "monocicle"),
        "paUnicyclingGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paVolleyballGeneral": MessageLookupByLibrary.simpleMessage(
            "voleibol"),
        "paVolleyballGeneralDesc": MessageLookupByLibrary.simpleMessage(
            "sense competició, equip de 6 a 9 persones, general"),
        "paWalkingForPleasure": MessageLookupByLibrary.simpleMessage(
            "caminar"),
        "paWalkingForPleasureDesc": MessageLookupByLibrary.simpleMessage(
            "per plaer"),
        "paWalkingTheDog": MessageLookupByLibrary.simpleMessage(
            "passejar el gos"),
        "paWalkingTheDogDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWallyball": MessageLookupByLibrary.simpleMessage(
            "wallyball"),
        "paWallyballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWaterAerobics": MessageLookupByLibrary.simpleMessage(
            "exercici a l\'aigua"),
        "paWaterAerobicsDesc": MessageLookupByLibrary.simpleMessage(
            "aquaeròbic, calistènia aquàtica"),
        "paWaterPolo": MessageLookupByLibrary.simpleMessage(
            "waterpolo"),
        "paWaterPoloDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWaterVolleyball": MessageLookupByLibrary.simpleMessage(
            "voleibol aquàtic"),
        "paWaterVolleyballDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "paWateraerobicsCalisthenics": MessageLookupByLibrary.simpleMessage(
            "aquaeròbic"),
        "paWateraerobicsCalisthenicsDesc": MessageLookupByLibrary.simpleMessage(
            "aquaeròbic, calistènia aquàtica"),
        "paWrestling": MessageLookupByLibrary.simpleMessage(
            "lluita lliure"),
        "paWrestlingDesc": MessageLookupByLibrary.simpleMessage(
            "general"),
        "palActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Passes la major part de la faena dret o caminant i el teu temps lliure és actiu"),
        "palActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Actiu"),
        "palLowActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "p. ex., faena asseguda o dreta i temps lliure amb activitat lleugera"),
        "palLowLActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Poc actiu"),
        "palSedentaryDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "p. ex., faena d\'oficina i temps lliure majoritàriament assegut"),
        "palSedentaryLabel": MessageLookupByLibrary.simpleMessage(
            "Sedentari"),
        "palVeryActiveDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Passes la major part de la faena caminant, corrent o carregant pes i el teu temps lliure és actiu"),
        "palVeryActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Molt actiu"),
        "pasteCodeHint": MessageLookupByLibrary.simpleMessage(
            "Apega ací el codi de l\'àpat compartit"),
        "pasteCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Apegar el codi"),
        "per100gmlLabel": MessageLookupByLibrary.simpleMessage(
            "Per 100 g/ml"),
        "perServingLabel": MessageLookupByLibrary.simpleMessage(
            "Per ració"),
        "phosphorusLabel": MessageLookupByLibrary.simpleMessage(
            "fòsfor"),
        "polyunsaturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "greixos poliinsaturats"),
        "potassiumLabel": MessageLookupByLibrary.simpleMessage(
            "potassi"),
        "privacyPolicyLabel": MessageLookupByLibrary.simpleMessage(
            "Política de privacitat"),
        "profileBodyMeasurementsTitle": MessageLookupByLibrary.simpleMessage(
            "Mesures corporals"),
        "profileFastingEntry": MessageLookupByLibrary.simpleMessage(
            "Temporitzador de dejuni"),
        "profileLabel": MessageLookupByLibrary.simpleMessage(
            "Perfil"),
        "profileTargetWeightClearAction": MessageLookupByLibrary.simpleMessage(
            "Esborrar"),
        "profileTargetWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Pes objectiu"),
        "profileTargetWeightNotSetLabel": MessageLookupByLibrary.simpleMessage(
            "Sense definir"),
        "profileTargetWeightReached": MessageLookupByLibrary.simpleMessage(
            "Has arribat al teu objectiu"),
        "profileTargetWeightToGo": m34,
        "profileWeeklyRateLabel": MessageLookupByLibrary.simpleMessage(
            "Ritme setmanal"),
        "profileWeeklyRateValue": m35,
        "profileWeightHistoryTitle": MessageLookupByLibrary.simpleMessage(
            "Historial de pes"),
        "progressPhotoImageLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir una foto"),
        "progressPhotoImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Triar de la galeria"),
        "progressPhotoImageRemove": MessageLookupByLibrary.simpleMessage(
            "Llevar la foto"),
        "progressPhotoImageReplace": MessageLookupByLibrary.simpleMessage(
            "Canviar la foto"),
        "progressPhotoImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Fer una foto"),
        "proteinLabel": MessageLookupByLibrary.simpleMessage(
            "proteïnes"),
        "proteinLabelShort": MessageLookupByLibrary.simpleMessage(
            "p"),
        "quantityLabel": MessageLookupByLibrary.simpleMessage(
            "Quantitat"),
        "quickAddAddedSnack": m36,
        "quickAddBottomSheetTitle": MessageLookupByLibrary.simpleMessage(
            "Entrada ràpida"),
        "quickAddCarbsHint": MessageLookupByLibrary.simpleMessage(
            "Carbohidrats (g, opcional)"),
        "quickAddCardLabel": MessageLookupByLibrary.simpleMessage(
            "Entrada ràpida"),
        "quickAddDefaultName": MessageLookupByLibrary.simpleMessage(
            "Entrada ràpida"),
        "quickAddEnergyLabelKcal": MessageLookupByLibrary.simpleMessage(
            "Energia (kcal)"),
        "quickAddEnergyLabelKj": MessageLookupByLibrary.simpleMessage(
            "Energia (kJ)"),
        "quickAddFatHint": MessageLookupByLibrary.simpleMessage(
            "Greixos (g, opcional)"),
        "quickAddProteinHint": MessageLookupByLibrary.simpleMessage(
            "Proteïnes (g, opcional)"),
        "quickAddSubmitLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir"),
        "quickAddTitleHint": MessageLookupByLibrary.simpleMessage(
            "Títol"),
        "readLabel": MessageLookupByLibrary.simpleMessage(
            "He llegit i accepte la política de privacitat."),
        "recentlyAddedLabel": MessageLookupByLibrary.simpleMessage(
            "Recents"),
        "recipeAddIngredientLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir un ingredient"),
        "recipeDeleteConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Es conservaran les entrades del diari ja registrades amb esta recepta."),
        "recipeDeleteConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar la recepta?"),
        "recipeDescriptionLabel": MessageLookupByLibrary.simpleMessage(
            "Descripció (opcional)"),
        "recipeImageLabel": MessageLookupByLibrary.simpleMessage(
            "Afegir una foto"),
        "recipeImagePickFromGallery": MessageLookupByLibrary.simpleMessage(
            "Triar de la galeria"),
        "recipeImageRemove": MessageLookupByLibrary.simpleMessage(
            "Llevar la foto"),
        "recipeImageReplace": MessageLookupByLibrary.simpleMessage(
            "Canviar la foto"),
        "recipeImageTakePhoto": MessageLookupByLibrary.simpleMessage(
            "Fer una foto"),
        "recipeIngredientAmountLabel": MessageLookupByLibrary.simpleMessage(
            "Quantitat"),
        "recipeIngredientCountLabel": m37,
        "recipeIngredientUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unitat"),
        "recipeIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Ingredients"),
        "recipeInvalidTotalWeightLabel": MessageLookupByLibrary.simpleMessage(
            "El pes total ha de ser major que zero"),
        "recipeLogCtaLabel": MessageLookupByLibrary.simpleMessage(
            "Registrar esta recepta"),
        "recipeNameLabel": MessageLookupByLibrary.simpleMessage(
            "Nom de la recepta"),
        "recipeNameRequiredLabel": MessageLookupByLibrary.simpleMessage(
            "La recepta necessita un nom"),
        "recipeNeedsIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Afig almenys un ingredient"),
        "recipeNoIngredientsLabel": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha ingredients"),
        "recipeNutritionPer100Label": MessageLookupByLibrary.simpleMessage(
            "Per 100 g"),
        "recipeNutritionPreviewLabel": MessageLookupByLibrary.simpleMessage(
            "Nutrició (total)"),
        "recipeSaveErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut guardar la recepta."),
        "recipeSaveForLaterDescription": MessageLookupByLibrary.simpleMessage(
            "Activa-ho per a conservar este àpat en la llista de guardats per a la pròxima vegada. Deixa-ho desactivat si és una cosa puntual que no tornaràs a menjar."),
        "recipeSaveForLaterLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar per a la pròxima vegada"),
        "recipeSaveLabel": MessageLookupByLibrary.simpleMessage(
            "Guardar la recepta"),
        "recipeServingsCountHelper": MessageLookupByLibrary.simpleMessage(
            "Et permet registrar esta recepta per racions en lloc de per grams."),
        "recipeServingsCountLabel": MessageLookupByLibrary.simpleMessage(
            "Racions (opcional)"),
        "recipeTagsHelper": MessageLookupByLibrary.simpleMessage(
            "Separades per comes, p. ex., \"esmorzar, vegà\""),
        "recipeTagsLabel": MessageLookupByLibrary.simpleMessage(
            "Etiquetes"),
        "recipeTotalWeightHelper": MessageLookupByLibrary.simpleMessage(
            "Pesa l\'olla amb el plat acabat perquè, en registrar-ne una part (per exemple, 350 g), es compten les calories correctes. Per defecte s\'usa el pes dels ingredients crus; els líquids compten com 1 ml ≈ 1 g."),
        "recipeTotalWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Pes del plat sencer cuinat (g)"),
        "recipesEmptyHint": MessageLookupByLibrary.simpleMessage(
            "Crea un àpat amb diversos ingredients i reutilitza\'l com qualsevol altre aliment."),
        "recipesEmptyLabel": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha receptes"),
        "recipesFilterAllLabel": MessageLookupByLibrary.simpleMessage(
            "Totes"),
        "recipesLabel": MessageLookupByLibrary.simpleMessage(
            "Receptes"),
        "recipesLoadErrorLabel": MessageLookupByLibrary.simpleMessage(
            "No s\'han pogut carregar les receptes. Torna-ho a provar més tard."),
        "repeatDayActionLabel": MessageLookupByLibrary.simpleMessage(
            "Repetir el dia"),
        "reportErrorDialogText": MessageLookupByLibrary.simpleMessage(
            "Vols informar d\'un error al desenvolupador?"),
        "retryLabel": MessageLookupByLibrary.simpleMessage(
            "Tornar a provar"),
        "reviewMealAddAllButton": m38,
        "reviewMealConfidenceHigh": MessageLookupByLibrary.simpleMessage(
            "alta"),
        "reviewMealConfidenceLow": MessageLookupByLibrary.simpleMessage(
            "baixa"),
        "reviewMealConfidenceMedium": MessageLookupByLibrary.simpleMessage(
            "mitjana"),
        "reviewMealGramsUnit": MessageLookupByLibrary.simpleMessage(
            "g"),
        "reviewMealPresetSaveFailedError": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut guardar esta plantilla; torna-ho a provar"),
        "reviewMealPresetSavedSnackbar": MessageLookupByLibrary.simpleMessage(
            "Guardat com a plantilla"),
        "reviewMealSaveAsPresetButton": MessageLookupByLibrary.simpleMessage(
            "Guardar com a plantilla"),
        "reviewMealSavePresetNameHint": MessageLookupByLibrary.simpleMessage(
            "Nom de la plantilla"),
        "reviewMealScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Revisar l\'àpat"),
        "reviewMealTotalKcalLabel": m39,
        "saturatedFatLabel": MessageLookupByLibrary.simpleMessage(
            "greixos saturats"),
        "scanLabelAnalysisFailedError": MessageLookupByLibrary.simpleMessage(
            "No s\'ha pogut llegir esta etiqueta; torna-ho a provar"),
        "scanLabelAnalyzeButton": MessageLookupByLibrary.simpleMessage(
            "Llegir l\'etiqueta"),
        "scanLabelExplanation": MessageLookupByLibrary.simpleMessage(
            "Fes una foto de l\'etiqueta d\'informació nutricional i emplenarem les dades perquè les revises."),
        "scanLabelPhotoPlaceholder": MessageLookupByLibrary.simpleMessage(
            "Foto de l\'etiqueta nutricional"),
        "scanLabelScreenTitle": MessageLookupByLibrary.simpleMessage(
            "Escanejar l\'etiqueta"),
        "scanProductLabel": MessageLookupByLibrary.simpleMessage(
            "Escanejar producte"),
        "scannerCameraPermissionDeniedExplanation": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker necessita accés a la càmera per a escanejar codis de barres. Activa\'l en la configuració del dispositiu, torna i prova-ho de nou."),
        "scannerCameraPermissionDeniedTitle": MessageLookupByLibrary.simpleMessage(
            "Cal accés a la càmera"),
        "scannerManualEntryButton": MessageLookupByLibrary.simpleMessage(
            "Escriure el codi a mà"),
        "scannerManualEntryCancel": MessageLookupByLibrary.simpleMessage(
            "Cancel·lar"),
        "scannerManualEntryDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Introduïx el codi de barres"),
        "scannerManualEntryFieldHint": MessageLookupByLibrary.simpleMessage(
            "De 8 a 14 dígits"),
        "scannerManualEntryInvalid": MessageLookupByLibrary.simpleMessage(
            "Eixe codi de barres no pareix vàlid. Revisa els dígits i torna-ho a provar."),
        "scannerManualEntrySubmit": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "scannerOpenSettingsButton": MessageLookupByLibrary.simpleMessage(
            "Obrir la configuració"),
        "scannerPhotographLabelButton": MessageLookupByLibrary.simpleMessage(
            "Fotografiar l\'etiqueta"),
        "scannerPhotographLabelExplanation": MessageLookupByLibrary.simpleMessage(
            "No trobem este producte en la base de dades. Fes una foto de l\'etiqueta nutricional i la llegirem perquè la revises."),
        "scannerScanAgainButton": MessageLookupByLibrary.simpleMessage(
            "Tornar a escanejar"),
        "scannerSwitchLensButton": MessageLookupByLibrary.simpleMessage(
            "Canviar de lent (ajuda amb codis de barres de prop)"),
        "searchDefaultLabel": MessageLookupByLibrary.simpleMessage(
            "Introduïx un terme de busca"),
        "searchFoodPage": MessageLookupByLibrary.simpleMessage(
            "Aliments"),
        "searchLabel": MessageLookupByLibrary.simpleMessage(
            "Buscar"),
        "searchProductsPage": MessageLookupByLibrary.simpleMessage(
            "Productes"),
        "searchResultsLabel": MessageLookupByLibrary.simpleMessage(
            "Resultats de la busca"),
        "selectGenderDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el sexe"),
        "selectHeightDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona l\'altura"),
        "selectPalCategoryLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el nivell d\'activitat"),
        "selectWeightDialogLabel": MessageLookupByLibrary.simpleMessage(
            "Selecciona el pes"),
        "selectionCountLabel": m40,
        "sendAnonymousUserData": MessageLookupByLibrary.simpleMessage(
            "Enviar dades d\'ús anònimes"),
        "servingLabel": MessageLookupByLibrary.simpleMessage(
            "Ració"),
        "servingSizeLabelImperial": MessageLookupByLibrary.simpleMessage(
            "Grandària de la ració (oz/fl oz)"),
        "servingSizeLabelMetric": MessageLookupByLibrary.simpleMessage(
            "Grandària de la ració (g/ml)"),
        "settingAboutLabel": MessageLookupByLibrary.simpleMessage(
            "Quant a"),
        "settingFeedbackLabel": MessageLookupByLibrary.simpleMessage(
            "Comentaris"),
        "settingsAccentColourTitle": MessageLookupByLibrary.simpleMessage(
            "Color d\'accent"),
        "settingsAccentCustomColour": MessageLookupByLibrary.simpleMessage(
            "Color personalitzat…"),
        "settingsAccentCustomSubtitle": MessageLookupByLibrary.simpleMessage(
            "Obri el selector de to per a triar amb precisió"),
        "settingsAccentHexInvalid": MessageLookupByLibrary.simpleMessage(
            "Eixe codi hexadecimal no pareix correcte: sis dígits, 0-9 i A-F."),
        "settingsAccentHexLabel": MessageLookupByLibrary.simpleMessage(
            "Codi hexadecimal"),
        "settingsAccentHueDisabledHint": MessageLookupByLibrary.simpleMessage(
            "Desactiva els colors del sistema per a triar un accent personalitzat."),
        "settingsAccentHueReset": MessageLookupByLibrary.simpleMessage(
            "Restablir"),
        "settingsAccentHueTitle": MessageLookupByLibrary.simpleMessage(
            "Color d\'accent"),
        "settingsAccentPresetsHeader": MessageLookupByLibrary.simpleMessage(
            "Tria un color"),
        "settingsAccentSubtitleCustom": MessageLookupByLibrary.simpleMessage(
            "Personalitzat"),
        "settingsAccentSubtitleDefault": MessageLookupByLibrary.simpleMessage(
            "Predeterminat"),
        "settingsAccentSubtitleMaterialYou": MessageLookupByLibrary.simpleMessage(
            "Material You"),
        "settingsCalciumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de calci en mil·ligrams. La referència per defecte és 1000 mg."),
        "settingsCalciumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de calci"),
        "settingsCaloriesTaperDescription": MessageLookupByLibrary.simpleMessage(
            "Reduïx el dèficit diari de manera gradual perquè els últims quilos no es facen costa amunt."),
        "settingsCaloriesTaperLabel": MessageLookupByLibrary.simpleMessage(
            "Ajustar l\'objectiu de calories en acostar-te a la meta"),
        "settingsCloudBackupActivateLabel": MessageLookupByLibrary.simpleMessage(
            "Activar la còpia en el núvol"),
        "settingsCloudBackupActivateSubtitle": MessageLookupByLibrary.simpleMessage(
            "Genera un codi de vinculació per a vore les teues dades en un altre dispositiu"),
        "settingsCloudBackupLinkDeviceLabel": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositiu"),
        "settingsCloudBackupLinkDeviceSubtitle": MessageLookupByLibrary.simpleMessage(
            "Escaneja o apega un codi de vinculació d\'un altre dispositiu"),
        "settingsCloudBackupNotPairedError": MessageLookupByLibrary.simpleMessage(
            "Primer configura la còpia en el núvol"),
        "settingsCloudBackupRestoreConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Restaurar"),
        "settingsCloudBackupRestoreConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Açò substituïx tot el que hi ha en este dispositiu (diari, perfil, configuració, receptes i més) per l\'última còpia en el núvol. Esta acció no es pot desfer."),
        "settingsCloudBackupRestoreConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols restaurar des del núvol?"),
        "settingsCloudBackupRestoreErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error en restaurar"),
        "settingsCloudBackupRestoreLabel": MessageLookupByLibrary.simpleMessage(
            "Restaurar des del núvol"),
        "settingsCloudBackupRestoreSubtitle": MessageLookupByLibrary.simpleMessage(
            "Descarrega la còpia del núvol i sobreescriu les dades d\'este dispositiu"),
        "settingsCloudBackupRestoreSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Dades restaurades. Reinicia l\'aplicació per a vore tots els canvis."),
        "settingsCloudBackupSyncErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Error en la còpia de seguretat"),
        "settingsCloudBackupSyncLabel": MessageLookupByLibrary.simpleMessage(
            "Fer una còpia ara"),
        "settingsCloudBackupSyncSubtitle": MessageLookupByLibrary.simpleMessage(
            "Puja al núvol les dades d\'este dispositiu"),
        "settingsCloudBackupSyncSuccessLabel": MessageLookupByLibrary.simpleMessage(
            "Còpia pujada"),
        "settingsCloudBackupViewCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Vore el codi de vinculació"),
        "settingsCustomMealsLabel": MessageLookupByLibrary.simpleMessage(
            "Aliments personalitzats"),
        "settingsDayStartDescription": MessageLookupByLibrary.simpleMessage(
            "Tria l\'hora a la qual comença el teu dia. Els àpats i les activitats registrats abans d\'eixa hora compten per al dia anterior; útil si treballes de nit o sopes tard."),
        "settingsDayStartHourLabel": m41,
        "settingsDayStartHoursPickerLabel": MessageLookupByLibrary.simpleMessage(
            "Hores"),
        "settingsDayStartLabel": MessageLookupByLibrary.simpleMessage(
            "El dia comença a les"),
        "settingsDayStartMinutesPickerLabel": MessageLookupByLibrary.simpleMessage(
            "Minuts"),
        "settingsDayStartTimeLabel": m42,
        "settingsDeleteAllDataConfirmAction": MessageLookupByLibrary.simpleMessage(
            "Eliminar-ho tot"),
        "settingsDeleteAllDataConfirmContent": MessageLookupByLibrary.simpleMessage(
            "Açò elimina de manera permanent d\'este dispositiu el teu perfil, àpats, activitats, historial de pes i receptes personalitzades. Els catàlegs d\'Open Food Facts i USDA Food Data Central no es veuen afectats. Esta acció no es pot desfer."),
        "settingsDeleteAllDataConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols eliminar totes les teues dades?"),
        "settingsDeleteAllDataLabel": MessageLookupByLibrary.simpleMessage(
            "Eliminar totes les meues dades"),
        "settingsDeleteAllDataSubtitle": MessageLookupByLibrary.simpleMessage(
            "Perfil, àpats, activitats i historial de pes"),
        "settingsDisclaimerLabel": MessageLookupByLibrary.simpleMessage(
            "Avís legal"),
        "settingsDistanceLabel": MessageLookupByLibrary.simpleMessage(
            "Distància"),
        "settingsEnergyUnitLabel": MessageLookupByLibrary.simpleMessage(
            "Unitat d\'energia"),
        "settingsFibreGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de fibra en grams. La referència per defecte és 30 g."),
        "settingsFibreGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de fibra"),
        "settingsImperialLabel": MessageLookupByLibrary.simpleMessage(
            "Imperial (lbs, ft, oz)"),
        "settingsIronGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de ferro en mil·ligrams. El valor per defecte depén del sexe (8 mg hòmens, 18 mg dones, 14 mg en altres casos)."),
        "settingsIronGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de ferro"),
        "settingsKcalAdjustmentLabel": MessageLookupByLibrary.simpleMessage(
            "Ajust diari de kcal"),
        "settingsLabel": MessageLookupByLibrary.simpleMessage(
            "Configuració"),
        "settingsLanguageLabel": MessageLookupByLibrary.simpleMessage(
            "Idioma"),
        "settingsLicensesLabel": MessageLookupByLibrary.simpleMessage(
            "Llicències"),
        "settingsMacroSplitLabel": MessageLookupByLibrary.simpleMessage(
            "Repartiment de macros"),
        "settingsMagnesiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de magnesi en mil·ligrams. El valor per defecte depén del sexe (400 mg hòmens, 310 mg dones, 355 mg en altres casos)."),
        "settingsMagnesiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de magnesi"),
        "settingsMassLabel": MessageLookupByLibrary.simpleMessage(
            "Massa"),
        "settingsMaterialYouSubtitle": MessageLookupByLibrary.simpleMessage(
            "Usa el color d\'accent del fons de pantalla en Android 12 i versions posteriors."),
        "settingsMaterialYouTitle": MessageLookupByLibrary.simpleMessage(
            "Usar els colors del sistema"),
        "settingsMetricLabel": MessageLookupByLibrary.simpleMessage(
            "Mètric (kg, cm, ml)"),
        "settingsNotificationsLabel": MessageLookupByLibrary.simpleMessage(
            "Recordatori diari"),
        "settingsNotificationsTimeLabel": m43,
        "settingsNotificationsUnavailableWebLabel": MessageLookupByLibrary.simpleMessage(
            "No disponible en la versió web"),
        "settingsNutrientGoalsHint": MessageLookupByLibrary.simpleMessage(
            "Objectius personals per a cada nutrient del tauler diari. Quan en definixes un, el diari l\'usa en lloc de la referència diària per defecte."),
        "settingsNutrientGoalsLabel": MessageLookupByLibrary.simpleMessage(
            "Objectius de nutrients"),
        "settingsNutrientsHelp": MessageLookupByLibrary.simpleMessage(
            "Tria quins nutrients es veuen en el tauler diari. Pots tornar a activar els ocults en qualsevol moment."),
        "settingsNutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Nutrients"),
        "settingsNutrientsSubtitle": MessageLookupByLibrary.simpleMessage(
            "Tria quins nutrients apareixen en el tauler del diari"),
        "settingsOpenRouterLabel": MessageLookupByLibrary.simpleMessage(
            "Proveïdor d\'IA"),
        "settingsOpenRouterSubtitle": MessageLookupByLibrary.simpleMessage(
            "Configura OpenRouter per a les funcions amb IA"),
        "settingsPerMealKcalShareBreakfast": MessageLookupByLibrary.simpleMessage(
            "Esmorzar"),
        "settingsPerMealKcalShareDescription": MessageLookupByLibrary.simpleMessage(
            "Repartix el teu objectiu diari de kcal entre esmorzar, dinar, sopar i berenars. Els percentatges han de sumar 100%."),
        "settingsPerMealKcalShareDinner": MessageLookupByLibrary.simpleMessage(
            "Sopar"),
        "settingsPerMealKcalShareLabel": MessageLookupByLibrary.simpleMessage(
            "Repartiment de kcal per àpat"),
        "settingsPerMealKcalShareLunch": MessageLookupByLibrary.simpleMessage(
            "Dinar"),
        "settingsPerMealKcalShareSnack": MessageLookupByLibrary.simpleMessage(
            "Berenar"),
        "settingsPotassiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de potassi en mil·ligrams. La referència per defecte és 3500 mg."),
        "settingsPotassiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de potassi"),
        "settingsPrivacySettings": MessageLookupByLibrary.simpleMessage(
            "Configuració de privacitat"),
        "settingsReportErrorLabel": MessageLookupByLibrary.simpleMessage(
            "Informar d\'un error"),
        "settingsSaturatedFatGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límit diari de greixos saturats en grams. La referència per defecte és 20 g."),
        "settingsSaturatedFatGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de greixos saturats"),
        "settingsShowActivityTracking": MessageLookupByLibrary.simpleMessage(
            "Mostrar el registre d\'activitat"),
        "settingsShowMealMacros": MessageLookupByLibrary.simpleMessage(
            "Mostrar els macros dels àpats"),
        "settingsShowMicronutrientsLabel": MessageLookupByLibrary.simpleMessage(
            "Mostrar els micronutrients"),
        "settingsSodiumGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límit diari de sodi en mil·ligrams. La referència per defecte és 2300 mg."),
        "settingsSodiumGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de sodi"),
        "settingsSourceCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Codi font"),
        "settingsSourcesLabel": MessageLookupByLibrary.simpleMessage(
            "Fonts i referències"),
        "settingsSugarsGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Límit diari de sucres en grams. La referència per defecte és 50 g."),
        "settingsSugarsGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de sucres"),
        "settingsSystemLabel": MessageLookupByLibrary.simpleMessage(
            "Sistema"),
        "settingsThemeDarkLabel": MessageLookupByLibrary.simpleMessage(
            "Fosc"),
        "settingsThemeLabel": MessageLookupByLibrary.simpleMessage(
            "Tema"),
        "settingsThemeLightLabel": MessageLookupByLibrary.simpleMessage(
            "Clar"),
        "settingsThemeSystemDefaultLabel": MessageLookupByLibrary.simpleMessage(
            "Predeterminat del sistema"),
        "settingsUnitsLabel": MessageLookupByLibrary.simpleMessage(
            "Unitats"),
        "settingsVitaminB12GoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de vitamina B12 en micrograms. La referència per defecte és 2,4 µg."),
        "settingsVitaminB12GoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de vitamina B12"),
        "settingsVitaminDGoalDescription": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari de vitamina D en micrograms. La referència per defecte és 15 µg."),
        "settingsVitaminDGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de vitamina D"),
        "settingsVolumeLabel": MessageLookupByLibrary.simpleMessage(
            "Volum"),
        "settingsWaterGoalDescription": MessageLookupByLibrary.simpleMessage(
            "L\'usa l\'indicador d\'aigua de la pantalla d\'inici."),
        "settingsWaterGoalLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu diari d\'aigua"),
        "shareActivityLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir l\'entrenament"),
        "shareCodeLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir el codi"),
        "shareMealLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir l\'àpat"),
        "shareRecipeLabel": MessageLookupByLibrary.simpleMessage(
            "Compartir la recepta"),
        "snackExample": MessageLookupByLibrary.simpleMessage(
            "p. ex., poma, gelat, xocolate..."),
        "snackLabel": MessageLookupByLibrary.simpleMessage(
            "Berenar"),
        "sodiumLabel": MessageLookupByLibrary.simpleMessage(
            "sodi"),
        "sourcesActivityDescription": MessageLookupByLibrary.simpleMessage(
            "Les calories cremades durant una activitat s\'estimen com a MET × pes corporal (kg) × durada (hores), amb valors de l\'Adult Compendium of Physical Activities."),
        "sourcesActivityTitle": MessageLookupByLibrary.simpleMessage(
            "Calories de l\'activitat (valors MET)"),
        "sourcesBmiDescription": MessageLookupByLibrary.simpleMessage(
            "L\'IMC es calcula com el pes (kg) dividit per l\'altura al quadrat (m²). Les categories de salut (pes insuficient, normal, preobesitat, obesitat de classe I–III) seguixen la classificació de l\'IMC per a adults de l\'Organització Mundial de la Salut."),
        "sourcesBmiTitle": MessageLookupByLibrary.simpleMessage(
            "Índex de massa corporal (IMC)"),
        "sourcesEnergyDescription": MessageLookupByLibrary.simpleMessage(
            "Els objectius diaris de calories, la taxa metabòlica basal i els coeficients d\'activitat física usen les equacions de l\'Institute of Medicine. Font: Institute of Medicine (2005). Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids, capítol 5 i taula 5-5."),
        "sourcesEnergyTitle": MessageLookupByLibrary.simpleMessage(
            "Necessitats energètiques (TDEE, TMB i nivell d\'activitat)"),
        "sourcesFoodDataDescription": MessageLookupByLibrary.simpleMessage(
            "Els valors nutricionals de productes i aliments genèrics provenen d\'estes bases de dades. Les dades de BEDCA s\'usen amb finalitats personals i no comercials, amb l\'atribució que exigixen les seues condicions."),
        "sourcesFoodDataTitle": MessageLookupByLibrary.simpleMessage(
            "Bases de dades d\'aliments"),
        "sourcesIconTooltip": MessageLookupByLibrary.simpleMessage(
            "Vore les fonts"),
        "sourcesMacrosDescription": MessageLookupByLibrary.simpleMessage(
            "El repartiment per defecte de 60% carbohidrats, 25% greixos i 15% proteïnes està dins dels intervals d\'ingesta de nutrients per a la població publicats per l\'OMS. Pots ajustar-ho en Configuració → Càlculs. Font: WHO Technical Report Series 916 (2003), Diet, Nutrition and the Prevention of Chronic Diseases."),
        "sourcesMacrosTitle": MessageLookupByLibrary.simpleMessage(
            "Distribució de macronutrients"),
        "sourcesNonBinaryDescription": MessageLookupByLibrary.simpleMessage(
            "La investigació sobre la despesa energètica ha usat històricament categories de sexe binàries, així que no hi ha una única fórmula de TDEE validada per a persones no binàries. Per això OpenNutriTracker et permet triar en Configuració → Càlculs entre una referència mitjana, una de perfil estrogènic o una de perfil testosterònic. Si un número precís és realment important per a la teua atenció sanitària, parla amb un professional que conega la teua situació hormonal."),
        "sourcesNonBinaryTitle": MessageLookupByLibrary.simpleMessage(
            "Estimació calòrica per a persones no binàries"),
        "sourcesNutrientReferenceDescription": MessageLookupByLibrary.simpleMessage(
            "Les quantitats diàries de referència del tauler de nutrients del diari provenen del resum de les Dietary Reference Intakes de l\'Institute of Medicine, que arreplega objectius per nutrient per a adults."),
        "sourcesNutrientReferenceTitle": MessageLookupByLibrary.simpleMessage(
            "Ingestes de referència de nutrients"),
        "sourcesOpenSourceLabel": MessageLookupByLibrary.simpleMessage(
            "Vore la font"),
        "sourcesScreenIntro": MessageLookupByLibrary.simpleMessage(
            "OpenNutriTracker usa metodologies consolidades i revisades per experts per a cada càlcul que mostra. Les cites de baix enllacen amb les fonts originals perquè pugues comprovar qualsevol número tu mateix."),
        "strategyCheckInApply": MessageLookupByLibrary.simpleMessage(
            "Actualitzar l\'objectiu"),
        "strategyCheckInDayLabel": MessageLookupByLibrary.simpleMessage(
            "Dia de revisió"),
        "strategyCheckInDue": m44,
        "strategyCheckInKeep": MessageLookupByLibrary.simpleMessage(
            "Mantindre l\'actual"),
        "strategyCheckInNext": m45,
        "strategyCheckInTitle": MessageLookupByLibrary.simpleMessage(
            "Revisió setmanal"),
        "strategyEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra almenys dues pesades per a vore el teu tauler d\'estratègia."),
        "strategyEstimatedTdeeLabel": MessageLookupByLibrary.simpleMessage(
            "TDEE estimat"),
        "strategyEstimatorStatusActiveDescription": MessageLookupByLibrary.simpleMessage(
            "S\'actualitza amb les teues dades"),
        "strategyEstimatorStatusActiveLabel": MessageLookupByLibrary.simpleMessage(
            "Actiu"),
        "strategyEstimatorStatusCalibratingDescription": MessageLookupByLibrary.simpleMessage(
            "S\'ajusta progressivament cap a la teua estimació dinàmica a mesura que arriben més dades; sol estabilitzar-se en un parell de setmanes"),
        "strategyEstimatorStatusCalibratingLabel": MessageLookupByLibrary.simpleMessage(
            "S\'està calibrant"),
        "strategyEstimatorStatusInsufficientDescription": MessageLookupByLibrary.simpleMessage(
            "Registra el pes i els àpats amb més regularitat per a obtindre una estimació"),
        "strategyEstimatorStatusInsufficientLabel": MessageLookupByLibrary.simpleMessage(
            "Dades insuficients"),
        "strategyEstimatorStatusPausedDescription": MessageLookupByLibrary.simpleMessage(
            "Menys de 4 dels últims 7 dies tenen àpats registrats, així que la teua estimació es manté en l\'últim valor"),
        "strategyEstimatorStatusPausedLabel": MessageLookupByLibrary.simpleMessage(
            "En pausa"),
        "strategyExplanationCorrecting": m46,
        "strategyExplanationMaintaining": MessageLookupByLibrary.simpleMessage(
            "Manteniment: coincidix amb el teu TDEE observat"),
        "strategyExplanationRate": m47,
        "strategyExplanationWithinBand": m48,
        "strategyKcalFloorNote": m49,
        "strategyLabel": MessageLookupByLibrary.simpleMessage(
            "Estratègia"),
        "strategyMacroDistributionTitle": MessageLookupByLibrary.simpleMessage(
            "Distribució de macros"),
        "strategyRangeAllTime": MessageLookupByLibrary.simpleMessage(
            "Tot"),
        "strategyRangeOneMonth": MessageLookupByLibrary.simpleMessage(
            "1 M"),
        "strategyRangeOneYear": MessageLookupByLibrary.simpleMessage(
            "1 A"),
        "strategyRangeSixMonths": MessageLookupByLibrary.simpleMessage(
            "6 M"),
        "strategyRangeThreeMonths": MessageLookupByLibrary.simpleMessage(
            "3 M"),
        "strategyTodayTargetLabel": MessageLookupByLibrary.simpleMessage(
            "Objectiu de hui"),
        "strategyTrendWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Pes de tendència"),
        "sugarLabel": MessageLookupByLibrary.simpleMessage(
            "sucre"),
        "suppliedLabel": MessageLookupByLibrary.simpleMessage(
            "aportat"),
        "transFatLabel": MessageLookupByLibrary.simpleMessage(
            "greixos trans"),
        "unitLabel": MessageLookupByLibrary.simpleMessage(
            "Unitat"),
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
            "Advertència"),
        "waterChipLabel": m50,
        "weeklyRateDialogDescription": MessageLookupByLibrary.simpleMessage(
            "Es definix com un percentatge del pes corporal per setmana. Fins que el teu pes de tendència arribe a l\'objectiu, la teua meta serà el teu TDEE observat menys (o més) les calories corresponents. Un ritme nou s\'aplica en la pròxima revisió setmanal."),
        "weightHistoryAddEntry": MessageLookupByLibrary.simpleMessage(
            "Afegir un registre"),
        "weightHistoryChartEmptyState": MessageLookupByLibrary.simpleMessage(
            "Registra almenys dos dies per a vore la teua tendència."),
        "weightHistoryDateLabel": MessageLookupByLibrary.simpleMessage(
            "Data"),
        "weightHistoryNoEntries": MessageLookupByLibrary.simpleMessage(
            "Encara no hi ha registres de pes. Afig el primer per a començar a seguir la teua tendència."),
        "weightHistoryNoteLabel": MessageLookupByLibrary.simpleMessage(
            "Nota (opcional)"),
        "weightHistoryScaleLabel": MessageLookupByLibrary.simpleMessage(
            "Bàscula"),
        "weightHistoryTrendLabel": MessageLookupByLibrary.simpleMessage(
            "Tendència"),
        "weightHistoryWeightLabel": MessageLookupByLibrary.simpleMessage(
            "Pes"),
        "weightLabel": MessageLookupByLibrary.simpleMessage(
            "Pes"),
        "yearsLabel": m51,
        "zincLabel": MessageLookupByLibrary.simpleMessage(
            "zinc"),
        "syncTitle": MessageLookupByLibrary.simpleMessage(
            "Sincronització entre dispositius"),
        "syncStatusOff": MessageLookupByLibrary.simpleMessage(
            "Desactivada en este dispositiu"),
        "syncStatusWaiting": MessageLookupByLibrary.simpleMessage(
            "Activada, a l'espera de la primera sincronització"),
        "syncStatusSyncing": MessageLookupByLibrary.simpleMessage(
            "Sincronitzant…"),
        "syncStatusError": MessageLookupByLibrary.simpleMessage(
            "L'última sincronització ha fallat. Es tornarà a intentar sola."),
        "syncStatusIdle": mSyncStatusIdle,
        "syncExplanation": MessageLookupByLibrary.simpleMessage(
            "Manté igual en el mòbil i en la web d'escriptori el teu diari, pes, receptes, dejunis, objectius i configuració. Tot es xifra en este dispositiu abans de pujar-se, així que el servidor no ho pot llegir. Les fotos no se sincronitzen; van en la còpia en el núvol."),
        "syncEnableTitle": MessageLookupByLibrary.simpleMessage(
            "Activar amb les dades d'este dispositiu"),
        "syncEnableSubtitle": MessageLookupByLibrary.simpleMessage(
            "Fes-ho en el mòbil que té les teues dades i després vincula els altres dispositius amb el seu codi."),
        "syncLinkTitle": MessageLookupByLibrary.simpleMessage(
            "Vincular este dispositiu"),
        "syncLinkSubtitle": MessageLookupByLibrary.simpleMessage(
            "Apega o escaneja el codi d'un dispositiu amb la sincronització activada."),
        "syncLinkConfirmTitle": MessageLookupByLibrary.simpleMessage(
            "Vols vincular este dispositiu?"),
        "syncLinkConfirmBody": MessageLookupByLibrary.simpleMessage(
            "Quan els dos dispositius tinguen el mateix registre, com el perfil o la configuració, la còpia sincronitzada substituïx la d'este dispositiu. Les entrades que només existixen ací es conserven i es pugen."),
        "syncLinkAction": MessageLookupByLibrary.simpleMessage(
            "Vincular"),
        "syncLinkInvalid": MessageLookupByLibrary.simpleMessage(
            "Això no és un codi de sincronització. Copia'l des de Configuració > Sincronització entre dispositius en l'altre dispositiu."),
        "syncLinked": MessageLookupByLibrary.simpleMessage(
            "Dispositiu vinculat. Baixant les teues dades…"),
        "syncNowLabel": MessageLookupByLibrary.simpleMessage(
            "Sincronitzar ara"),
        "syncShowCodeTitle": MessageLookupByLibrary.simpleMessage(
            "Mostrar el codi per a un altre dispositiu"),
        "syncShowCodeWarning": MessageLookupByLibrary.simpleMessage(
            "Qui tinga este codi pot llegir i canviar les teues dades sincronitzades. Usa'l només en els teus propis dispositius."),
        "syncCodeDialogTitle": MessageLookupByLibrary.simpleMessage(
            "Codi de sincronització"),
        "syncDisableTitle": MessageLookupByLibrary.simpleMessage(
            "Desactivar en este dispositiu"),
        "syncDisableBody": MessageLookupByLibrary.simpleMessage(
            "Este dispositiu deixa de sincronitzar i conserva les seues dades. Els teus altres dispositius continuen sincronitzant."),
        "syncDisableAction": MessageLookupByLibrary.simpleMessage(
            "Desactivar"),
        "syncScanLabel": MessageLookupByLibrary.simpleMessage(
            "Escanejar QR"),
        "syncPasteHint": MessageLookupByLibrary.simpleMessage(
            "ontsync1:…"),
        "syncDoneSnackbar": mSyncDoneSnackbar,
      };
}
