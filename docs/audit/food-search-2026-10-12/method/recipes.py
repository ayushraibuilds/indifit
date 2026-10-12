"""Recipe calculations for the staples draft from IFCT 2017 ingredients.

Each recipe lists raw ingredients for one batch (grams), the cooked weight of
the batch, and any frying oil absorbed. Values per serving = batch totals x
serving weight / cooked weight. Energy for IFCT ingredients is IFCT's own
(kJ / 4.184); for the oils and ghee, which IFCT gives as fat only, 9 kcal/g.
"""
import csv, json, re, sys

HERE = sys.argv[1]
IFCT = {r['code']: r for r in csv.DictReader(open(f'{HERE}/comp.csv'))}
USDA = json.load(open(f'{HERE}/usda.json'))
LABELS = json.load(open(f'{HERE}/labels.json'))
KEYS = ['kcal', 'protein_g', 'carbs_g', 'fat_g', 'fibre_g']


def ifct(code):
    r = IFCT[code]
    f = lambda k: float(r[k] or 0)
    p, fat, c, fib = f('protcnt'), f('fatce'), f('choavldf'), f('fibtg')
    kcal = f('enerc') / 4.184 if f('enerc') > 0 else 4 * p + 9 * fat + 4 * c + 2 * fib
    return {'kcal': kcal, 'protein_g': p, 'carbs_g': c, 'fat_g': fat, 'fibre_g': fib}


def ref(name):
    """Per-100 g values for an ingredient reference."""
    if name in IFCT:
        return ifct(name)
    if name.startswith('_') or name in USDA:
        return {k: float(USDA[name][k]) for k in KEYS}
    if name.startswith('lbl:'):
        return {k: float(LABELS[name[4:]]['per100'][k]) for k in KEYS}
    if name == 'curd':  # whole cow-milk curd: composition of the milk it sets from
        return ifct('L002')
    if name == 'chhena':  # chhena / fresh paneer
        return ifct('L003')
    if name == 'hung_curd':  # 200 g curd strained to 100 g; whey ~93% water, 4.8% lactose, 0.9% protein, 0.3% fat
        c = ifct('L002')
        whey = {'kcal': 4 * 0.9 + 4 * 4.8 + 9 * 0.3, 'protein_g': 0.9, 'carbs_g': 4.8, 'fat_g': 0.3, 'fibre_g': 0}
        return {k: 2 * c[k] - whey[k] for k in KEYS}
    raise KeyError(name)


OIL, GHEE, MUSTARD_OIL = 'T005', 'T013', 'T006'
RICE, ATTA, MAIDA, SUJI = 'A015', 'A019', 'A018', 'A022'
MILK, KHOA = 'L002', 'L004'
SUGAR = '_sugar'

# name: (ingredients [(ref, raw grams)], cooked batch grams or None for sum, note)
R = {
    'Gulab Jamun': ([(KHOA, 200), (MAIDA, 30), (GHEE, 40), (SUGAR, 130)], 400, '10 pieces; 40 g ghee absorbed in frying; syrup sugar absorbed'),
    'Jalebi': ([(MAIDA, 100), ('curd', 20), (OIL, 35), (SUGAR, 120)], 300, 'fried in oil (35 g absorbed), soaked in sugar syrup'),
    'Rasgulla': ([('chhena', 100), (SUGAR, 60)], 160, '4 pieces with syrup'),
    'Rasmalai': ([('chhena', 100), (SUGAR, 55), (MILK, 300)], 240, 'chhena balls in rabri (300 g milk reduced by half)'),
    'Besan Ladoo': ([('B001', 100), (GHEE, 50), (SUGAR, 80)], 230, 'roasted besan (Bengal gram dal flour), ghee, powdered sugar'),
    'Motichoor Ladoo': ([('B001', 100), (OIL, 40), (SUGAR, 110)], 260, 'fried boondi (40 g oil absorbed) in syrup'),
    'Kaju Katli': ([('H005', 100), (SUGAR, 70), (GHEE, 5)], 180, 'cashew and sugar paste'),
    'Milk Barfi': ([(KHOA, 200), (SUGAR, 60), (GHEE, 5)], 265, 'khoa barfi'),
    'Kheer': ([(MILK, 1000), (RICE, 50), (SUGAR, 70)], 600, 'milk reduced to 600 g with rice'),
    'Gajar Halwa': ([('F002', 500), (MILK, 500), (SUGAR, 100), (GHEE, 40), (KHOA, 50)], 600, 'carrot cooked down in milk'),
    'Suji Halwa': ([(SUJI, 100), (GHEE, 60), (SUGAR, 100)], 450, 'cooked with 300 g water'),
    'Peda': ([(KHOA, 200), (SUGAR, 70)], 260, 'khoa peda'),
    'Sandesh': ([('chhena', 200), (SUGAR, 50)], 240, 'chhena and sugar'),
    'Shrikhand': ([('hung_curd', 250), (SUGAR, 80)], 330, 'hung curd (from 500 g curd) and sugar'),
    'Mysore Pak': ([('B001', 100), (GHEE, 120), (SUGAR, 200)], 400, 'besan, ghee, sugar syrup cooked down'),
    'Puri': ([(ATTA, 100), (OIL, 30)], 130, '5 g oil in dough, 25 g absorbed in frying; water cooked off'),
    'Thepla': ([(ATTA, 100), ('B001', 15), ('C020', 30), ('curd', 30), (OIL, 15)], 200, 'methi thepla, cooked on tawa'),
    'Luchi': ([(MAIDA, 100), (GHEE, 10), (OIL, 25)], 130, '25 g oil absorbed in frying'),
    'Litti': ([(ATTA, 150), ('B002', 60), ('G017', 20), (GHEE, 35)], 330, 'sattu-stuffed, baked, dipped in ghee; 4 pieces'),
    'Appam': ([(RICE, 100), ('H007', 30), (SUGAR, 5), (OIL, 3)], 250, 'fermented rice-coconut batter'),
    'Uttapam': ([('A014', 75), ('B003', 25), ('G017', 30), ('D075', 20), (OIL, 8)], 300, '2 uttapams from 100 g dry rice and urad'),
    'Puttu': ([(RICE, 100), ('H007', 25)], 180, 'steamed rice flour and coconut'),
    'Khichdi': ([(RICE, 60), ('B010', 40), (GHEE, 10)], 400, 'moong dal khichdi'),
    'Curd Rice': ([(RICE, 50), ('curd', 150), (OIL, 5)], 305, 'rice cooked to 150 g, curd, tempering'),
    'Lemon Rice': ([(RICE, 60), (OIL, 10), ('H012', 10), ('E033', 15)], 215, 'tempered with peanuts'),
    'Veg Fried Rice': ([(RICE, 80), (OIL, 15), ('F002', 30), ('C015', 30), ('D033', 20), ('D061', 20)], 355, 'rice cooked to 240 g, stir-fried with vegetables'),
    'Chicken Fried Rice': ([(RICE, 80), ('N003', 60), ('M001', 25), (OIL, 15), ('C015', 20), ('F002', 20)], 400, ''),
    'Ven Pongal': ([(RICE, 60), ('B010', 30), (GHEE, 15), ('H005', 5)], 400, ''),
    'Bisi Bele Bath': ([(RICE, 50), ('B021', 30), ('F002', 20), ('D061', 20), ('F006', 20), ('E064', 5), (GHEE, 12)], 400, ''),
    'Sabudana Khichdi': ([('_sago', 60), ('H012', 20), ('F006', 40), (OIL, 10)], 170, 'soaked sago, peanuts, potato'),
    'Rajma Chawal': ([('B020', 40), ('G017', 30), ('D075', 40), (OIL, 8), (RICE, 50)], 300, 'one plate: rajma curry and rice'),
    'Dal Chawal': ([('B021', 30), (OIL, 5), (RICE, 50)], 300, 'one plate: toor dal and rice'),
    'Chicken Breast (Cooked)': ([('N003', 133)], 100, 'grilled, no oil; 25% cooking loss; IFCT raw Indian broiler breast'),
    'Chicken Thigh (Cooked)': ([('N002', 133)], 100, 'grilled, no oil; 25% cooking loss'),
    'Fish Fillet (Cooked)': ([('S006', 125), (OIL, 3)], 100, 'rohu, pan-cooked; 20% cooking loss'),
    'Machher Jhol': ([('S006', 100), ('F006', 40), (MUSTARD_OIL, 15), ('G017', 20), ('D075', 20)], 250, 'Bengali fish curry'),
    'Prawns (Cooked)': ([('S008', 125)], 100, 'boiled; 20% cooking loss'),
    'Mutton Curry': ([('O003', 150), ('G017', 60), ('D075', 50), (OIL, 20), ('curd', 30)], 330, 'goat leg meat'),
    'Chicken Shawarma Roll': ([('N002', 130), (MAIDA, 70), ('_mayonnaise', 20), ('G017', 20), ('C015', 20), (OIL, 5)], 250, 'flatbread from 70 g maida'),
    'Chicken Momos': ([(MAIDA, 50), ('N002', 90), ('G017', 20), ('C015', 15), (OIL, 5)], 200, '6 steamed pieces; about 8 g flour per wrapper'),
    'Veg Momos': ([(MAIDA, 50), ('C015', 50), ('F002', 25), ('G017', 20), (OIL, 6)], 180, '6 steamed pieces; about 8 g flour per wrapper'),
    'Moong Sprouts': ([('B011', 40)], 104, '40 g dry whole moong sprouted to 104 g'),
    'Sattu': ([('B002', 30)], 30, 'roasted whole Bengal gram flour; roasting losses ignored'),
    'Tea with Milk and Sugar': ([(MILK, 50), (SUGAR, 8)], 150, '150 ml cup'),
    'Coffee with Milk and Sugar': ([(MILK, 100), (SUGAR, 8)], 150, '150 ml cup'),
    'Cold Coffee': ([(MILK, 200), (SUGAR, 20)], 250, '250 ml with ice'),
    'Badam Milk': ([(MILK, 200), ('H001', 10), (SUGAR, 15)], 200, '200 ml'),
    'Orange Juice (Fresh)': ([('E047', 200)], 200, 'juice taken as orange pulp with 20% of its fibre (the rest stays in the strainer)'),
    'Pizza (Margherita)': ([(MAIDA, 45), (OIL, 6), ('Mozzarella Cheese', 30), ('D075', 30)], 107, 'one slice of a 4-slice 12-inch pizza'),
    'Veg Burger': ([('lbl:Pav', 55), ('F006', 55), ('D061', 8), (MAIDA, 8), (OIL, 8), ('_mayonnaise', 8), ('D075', 10), ('G017', 5)], 150, 'aloo tikki patty, shallow fried'),
    'Chicken Burger': ([('lbl:Pav', 60), ('N002', 80), (MAIDA, 10), (OIL, 10), ('_mayonnaise', 12), ('D075', 10), ('C015', 10)], 170, 'fried chicken patty'),
    'French Fries': ([('F006', 234), (OIL, 17.5)], 117, 'medium portion; fries weigh about half the raw potato; 15% oil by fried weight'),
    'Pasta (Red Sauce)': ([(SUJI, 80), ('D075', 60), ('G017', 15), (OIL, 10), ('Mozzarella Cheese', 5)], 290, 'durum semolina pasta'),
    'Pasta (White Sauce)': ([(SUJI, 80), (MILK, 100), ('Butter', 10), (MAIDA, 8), ('Mozzarella Cheese', 15), ('D033', 20)], 330, ''),
    'Veg Spring Roll': ([(MAIDA, 15), ('C015', 20), ('F002', 10), (OIL, 9)], 60, 'deep fried'),
    'Veg Frankie': ([(MAIDA, 60), ('F006', 80), ('G017', 20), (OIL, 10), ('_ketchup', 10)], 200, ''),
    'Kachori': ([(MAIDA, 30), ('B010', 12), (OIL, 15)], 60, 'moong dal kachori; 12 g oil absorbed'),
    'Bread Butter Toast': ([('lbl:White Bread', 25), ('Butter', 5)], 30, ''),
    'Oats Porridge with Milk': ([('lbl:Oats (Dry)', 40), (MILK, 200), (SUGAR, 8)], 250, ''),
    'Veg Sandwich': ([('lbl:White Bread', 50), ('Butter', 6), ('D075', 30), ('D043', 30), ('F006', 30)], 150, ''),
    'Cheese Sandwich': ([('lbl:White Bread', 50), ('lbl:Cheese Slice', 40), ('Butter', 8), ('D075', 20), ('D043', 12)], 130, 'grilled'),
    'Bread Omelette': ([('lbl:White Bread', 50), ('M001', 100), (OIL, 6), ('G017', 10), ('D075', 10)], 150, '2 eggs'),
}

# Single-source rows: (source key, grams per serving taken from the draft).
LABEL_ROWS = ['Makhana (Roasted)', 'Peanut Butter', 'Dark Chocolate', 'Milk Chocolate', 'Vanilla Ice Cream', 'White Bread',
              'Brown Bread (Whole Wheat)', 'Pav', 'Rusk', 'Cornflakes', 'Muesli', 'Oats (Dry)', 'Granola', 'Soya Chunks (Dry)',
              'Whey Protein', 'Cheese Slice', 'Cola', 'Masala Noodles (Instant)', 'Glucose Biscuits', 'Marie Biscuits', 'Aloo Bhujia',
              'Potato Chips (Salted)', 'Corn Puffs (Masala)', 'Namkeen Mixture', 'Banana Chips', 'Peanut Chikki', 'Malted Milk Drink Powder']
USDA_ROWS = ['Kiwi', 'Chia Seeds', 'Pumpkin Seeds', 'Butter', 'Mozzarella Cheese', 'Tofu', 'Popcorn (Salted)', 'Multigrain Bread']
IFCT_ROWS = {'Jamun': 'E013'}


def grams(serving):
    m = re.search(r'\(([\d.]+) (g|ml)', serving) or re.search(r'([\d.]+) g dry', serving)
    return float(m.group(1))


def compute(name, serving_g):
    if name in R:
        ings, cooked, note = R[name]
        tot = {k: 0.0 for k in KEYS}
        for ingredient, g in ings:
            v = ref(ingredient)
            for k in KEYS:
                tot[k] += v[k] * g / 100
        cooked = cooked or sum(g for _, g in ings)
        per = {k: tot[k] * serving_g / cooked for k in KEYS}
        if name == 'Orange Juice (Fresh)':
            removed = per['fibre_g'] * 0.8
            per['fibre_g'] -= removed
            per['kcal'] -= 2 * removed
        recipe = '; '.join(f'{i} {g:g} g' for i, g in ings)
        return per, f'Recipe from IFCT 2017 ingredients ({recipe}; cooked batch {cooked:g} g){" — " + note if note else ""}', 'calculated (IFCT recipe)'
    if name in IFCT_ROWS:
        v = ifct(IFCT_ROWS[name])
        return {k: v[k] * serving_g / 100 for k in KEYS}, f'IFCT 2017 {IFCT_ROWS[name]}; edible portion', 'verified (IFCT), low confidence: IFCT names this "Black berry" (Rubus sp.) but lists jamun\'s local names'
    if name in USDA_ROWS:
        u = USDA[name]
        return {k: float(u[k]) * serving_g / 100 for k in KEYS}, f'USDA SR Legacy {u["fdc"]} "{u["desc"]}" (available carbohydrate = total minus fibre)', 'USDA (not in IFCT 2017)'
    if name in LABEL_ROWS:
        l = LABELS[name]
        return ({k: float(l['per100'][k]) * serving_g / 100 for k in KEYS},
                f'Pack label: {l["product"]} (OFF {l["code"]}), the Indian product nearest the median of {l["n"]} labels',
                'label (Indian pack)')
    return None


if __name__ == '__main__':
    path = sys.argv[2]
    rows = list(csv.DictReader(open(path)))
    missing = []
    for r in rows:
        if r['status'].startswith('verified (IFCT)') and r['name'] not in IFCT_ROWS:
            continue
        g = grams(r['serving'])
        if r['name'] == 'Masala Noodles (Instant)':
            g = 70.0
        res = compute(r['name'], g)
        if res is None:
            missing.append(r['name'])
            continue
        per, source, status = res
        r.update({'kcal': str(round(per['kcal'])), 'protein_g': f"{per['protein_g']:.1f}", 'carbs_g': f"{per['carbs_g']:.1f}",
                  'fat_g': f"{per['fat_g']:.1f}", 'fibre_g': f"{per['fibre_g']:.1f}", 'source': source, 'status': status})
    with open(path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print('missing', missing)
