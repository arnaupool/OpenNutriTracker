"""Builds assets/bedca/bedca_foods.json from BEDCA query-service responses.

BEDCA (Base de Datos Espanola de Composicion de Alimentos) is published by
AESAN for personal, non-commercial use, with attribution and without
modifying the data. This script only selects components and converts units
(kJ to kcal, g/mg/ug to the unit each app field uses); values stay as BEDCA
publishes them, per 100 g of edible portion.

Fetching (one food per request, politely spaced):
  POST https://www.bedca.net/bdpub/procquery.php, Content-Type: text/xml
  - food list: <type level="1"/> with condition f_origen EQUAL BEDCA
  - one food: <type level="2"/>, conditions f_id EQUAL <id> and publico
    EQUAL 1, selecting f_id, f_ori_name, f_eng_name, c_id, eur_name,
    best_location, v_unit (see fetch_food_query below)

Usage:
  python tool/bedca/build_bedca_asset.py <dir with list.xml and foods/<id>.xml> assets/bedca/bedca_foods.json
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

# BEDCA/EuroFIR component code -> (asset key, unit the app expects).
COMPONENTS = {
    'ENERC': ('kcal', 'kcal'),
    'CHO': ('carb', 'g'),
    'FAT': ('fat', 'g'),
    'PROT': ('prot', 'g'),
    'SUGAR': ('sug', 'g'),
    'FASAT': ('sat', 'g'),
    'FIBT': ('fib', 'g'),
    'FAMS': ('mufa', 'g'),
    'FAPU': ('pufa', 'g'),
    'FATRS': ('trans', 'g'),
    'CHORL': ('chol', 'mg'),
    'NA': ('na', 'mg'),
    'K': ('k', 'mg'),
    'MG': ('mg', 'mg'),
    'CA': ('ca', 'mg'),
    'FE': ('fe', 'mg'),
    'ZN': ('zn', 'mg'),
    'P': ('p', 'mg'),
    'VITA': ('vitA', 'ug'),
    'VITC': ('vitC', 'mg'),
    'VITD': ('vitD', 'ug'),
    'VITB6': ('vitB6', 'mg'),
    'VITB12': ('vitB12', 'ug'),
    'NIAEQ': ('nia', 'mg'),
}

# Read only to validate an entry, not shipped.
CHECK_ONLY = ('WATER', 'ALC')

MASS_IN_UG = {'g': 1e6, 'mg': 1e3, 'ug': 1.0}
KJ_PER_KCAL = 4.184

ATTRIBUTION = ('AESAN/BEDCA Base de Datos Española de Composición de '
               'Alimentos v1.0 (2010). https://www.bedca.net')


def fetch_food_query(food_id):
    fields = ['f_id', 'f_ori_name', 'f_eng_name', 'edible_portion', 'f_origen', 'c_id',
              'c_ori_name', 'c_eng_name', 'eur_name', 'componentgroup_id', 'best_location',
              'v_unit', 'u_descripcion', 'value_type']
    sel = ''.join('<atribute name="%s"/>' % f for f in fields)
    return ('<?xml version="1.0" encoding="utf-8"?><foodquery><type level="2"/>'
            '<selection>%s</selection>'
            '<condition><cond1><atribute1 name="f_id"/></cond1><relation type="EQUAL"/><cond3>%s</cond3></condition>'
            '<condition><cond1><atribute1 name="publico"/></cond1><relation type="EQUAL"/><cond3>1</cond3></condition>'
            '<order ordtype="ASC"><atribute3 name="componentgroup_id"/></order></foodquery>') % (sel, food_id)


def convert(value, unit, target):
    unit = unit.strip()
    if target == 'kcal':
        if unit == 'kcal':
            return value
        if unit == 'kJ':
            return value / KJ_PER_KCAL
        raise ValueError('energy unit ' + unit)
    if unit not in MASS_IN_UG:
        raise ValueError('mass unit ' + unit)
    return value * MASS_IN_UG[unit] / MASS_IN_UG[target]


def tidy(x, key):
    return round(x, 1) if key == 'kcal' else round(x, 3)


def parse_food(path):
    """(food, values used only for checks), or None."""
    root = ET.parse(path).getroot()
    food = root.find('food')
    # Foods BEDCA does not publish come back as an empty <food/>.
    if food is None or food.findtext('f_id') is None:
        return None
    nutrients, checks = {}, {}
    for fv in food.findall('foodvalue'):
        code = (fv.findtext('eur_name') or '').strip()
        raw = (fv.findtext('best_location') or '').strip()
        if raw == '':
            continue
        unit = fv.findtext('v_unit') or ''
        if code in CHECK_ONLY:
            checks[code] = convert(float(raw), unit, 'g')
        if code not in COMPONENTS:
            continue
        key, target = COMPONENTS[code]
        nutrients[key] = tidy(convert(float(raw), unit, target), key)
    return {
        'id': int(food.findtext('f_id')),
        'es': (food.findtext('f_ori_name') or '').strip(),
        'en': (food.findtext('f_eng_name') or '').strip() or None,
        'n': nutrients,
    }, checks


def inconsistency(food, checks):
    """Why a food's published values contradict themselves, or None.

    BEDCA has a few entries whose values cannot be right, and a health app
    must not offer them: energy that the macronutrients (Atwater factors,
    alcohol 7 kcal/g, fibre 2 kcal/g) do not explain, and foods boiled in
    water that carry the composition of the dry product (e.g. "Arroz,
    hervido" with 4 % water and 392 kcal). Leaving an entry out does not
    alter BEDCA's data.
    """
    n = food['n']
    name = food['es'].lower()
    water = checks.get('WATER')
    if water is not None and water < 40 and re.search(r'hervid|cocid', name):
        return 'boiled with %.1f %% water' % water
    if all(k in n for k in ('carb', 'fat', 'prot')):
        estimate = (4 * n['carb'] + 9 * n['fat'] + 4 * n['prot'] + 2 * n.get('fib', 0)
                    + 7 * checks.get('ALC', 0))
        if abs(estimate - n['kcal']) > max(0.2 * n['kcal'], 25):
            return 'energy %.0f kcal vs %.0f kcal from macros' % (n['kcal'], estimate)
    return None


def main(src, out):
    ids = re.findall(r'<f_id>(\d+)</f_id>', open(os.path.join(src, 'list.xml'), encoding='utf-8').read())
    foods, skipped, rejected = [], [], []
    for fid in ids:
        parsed = parse_food(os.path.join(src, 'foods', fid + '.xml'))
        # Without energy the food would log as 0 kcal, which is worse than
        # not offering it.
        if parsed is None or not parsed[0]['es'] or 'kcal' not in parsed[0]['n']:
            skipped.append(fid)
            continue
        food, checks = parsed
        reason = inconsistency(food, checks)
        if reason:
            rejected.append('%s (%s): %s' % (food['es'], food['id'], reason))
            continue
        foods.append(food)
    foods.sort(key=lambda f: f['id'])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'source': ATTRIBUTION, 'foods': foods}, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print('foods', len(foods), 'skipped (no energy or no data)', len(skipped))
    print('rejected as inconsistent', len(rejected))
    for line in rejected:
        print('  ' + line)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
