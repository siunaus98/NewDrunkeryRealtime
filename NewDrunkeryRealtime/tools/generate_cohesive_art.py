"""Rebuild flat, outlined game SVGs. Recipes remain owned by TestItemDefs.gd.

Run from any directory with Python 3; no external graphics packages required.
"""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "ArtResource"
OUTLINE = "#513420"


def path(d, fill, stroke=OUTLINE, width=4):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'


def ellipse(x, y, rx, ry, fill, stroke=OUTLINE, width=4):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def rect(x, y, w, h, fill, stroke=OUTLINE, width=4, radius=2):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def svg(filename, body, size=(128, 128), view=(128, 128)):
    target = ART / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size[0]}" height="{size[1]}" viewBox="0 0 {view[0]} {view[1]}">\n{body}\n</svg>\n', encoding="utf-8")
    from finish_art_direction import finish
    finish(target)


def group(body, x=0, y=0, scale=1, rotate=0):
    return f'<g transform="translate({x} {y}) scale({scale}) rotate({rotate} 64 64)">{body}</g>'


def meat(color, light, shape="steak"):
    if shape == "leg":
        return (path("M80 76l18 15 8-3 9 8-8 10-10-1-2-8-23-17z", "#fff0cf")
                + path("M34 24C13 35 17 70 40 87c15 11 38 1 46-18 9-23-8-50-28-49z", color)
                + path("M36 34c-10 12-7 30 5 37 9 5 22 1 27-9", light, "none")
                + path("M56 28l5 10m-30 7l12 6", "none", light, 5))
    return (path("M30 29C10 44 17 90 42 99c26 9 62-6 69-30 6-24-14-34-31-40-21-9-34-12-50 0z", color)
            + path("M34 39c-13 12-11 37 8 48 20 9 48-4 55-20 6-15-9-24-24-29-18-6-29-7-39 1z", light, "none")
            + ellipse(61, 61, 15, 13, "#f9dfb7", "none")
            + path("M31 57l12 3m36 18l10-8m-19-31l4 9", "none", color, 5))


def ingredients():
    food = {
        "meat_red": meat("#b95543", "#df8060"),
        "meat_white": meat("#dca46a", "#f3d29b", "leg"),
        "sand_hare": meat("#bc825c", "#e1b58b", "leg") + path("M45 40l8 6m-15 9l8 6", "none", "#9e6047", 4),
        "camel_meat": meat("#9e6245", "#cc8a5b") + path("M38 33l8 12m37 11l9 5", "none", "#f5d6a2", 5),
        "crisp_sprout": path("M62 99V50", "none", "#507146", 7)
            + path("M60 67C22 76 18 42 25 28c25 1 40 15 35 39z", "#73a858")
            + path("M65 79c38 4 48-23 40-43-24 1-41 17-40 43z", "#8bb96a")
            + path("M62 53C42 34 53 13 66 12c20 16 16 32-4 41z", "#a7c878")
            + path("M35 42l23 20m16 8l19-20", "none", "#d3df9a", 4),
        "sand_potato": path("M21 58c2-21 19-34 42-36 24-3 45 12 45 37 0 24-15 46-42 45-27-1-49-19-45-46z", "#c99354")
            + path("M33 51c5-12 18-17 34-16", "none", "#edc581", 8)
            + ellipse(41, 73, 4, 3, "#94623c", "none") + ellipse(82, 48, 4, 3, "#94623c", "none") + ellipse(79, 87, 4, 3, "#94623c", "none"),
        "golden_wheat": path("M44 111l36-84m-13 84l14-77", "none", "#96703c", 5),
        "dryfrost_cabbage": ellipse(64, 68, 44, 39, "#9aa66b")
            + path("M62 105C24 99 12 63 32 43c6 22 20 28 30 37M68 105c31-8 43-38 29-64-7 24-20 31-29 39", "#bbc385")
            + path("M64 104C40 80 37 39 64 20c28 19 26 58 0 84z", "#d9d6a1")
            + path("M64 95V35m0 24L51 48m13 25l16-17", "none", "#8d9b62", 4),
        "dill": path("M62 112V22m0 68L30 66m32 9l31-22M62 58L36 38m26 5l24-19", "none", "#567444", 5),
        "sun_seed": path("M66 15c29 19 42 45 30 72-12 27-42 29-57 9C17 68 37 33 66 15z", "#b9853d")
            + path("M66 25c10 24 14 50-3 76C42 80 43 49 66 25z", "#f1cf83")
            + path("M68 34l-7 52", "none", "#d8a75b", 4),
        "sunny_berry": ellipse(85, 58, 28, 29, "#c6cc72")
            + path("M86 34q-12 22-1 47", "none", "#929653", 3)
            + ellipse(48, 77, 33, 32, "#d6ca73")
            + path("M50 50q-12 23 0 52", "none", "#a39a4b", 3)
            + path("M27 67q-3 10 0 15m43-38l-3 8", "none", "#f6e7a2", 6)
            + path("M47 45l4-14m34-3l3-13", "none", "#754829", 4)
            + path("M83 27Q57 30 60 13q19-4 23 14z", "#8ca95e", width=3),
        "stone_bloom": "",
        "sandworm_core": path("M64 16l30 13 17 38-25 37H40L18 68l18-38z", "#ce9455")
            + path("M64 27l22 13 11 28-33 26-31-27 12-26z", "#f3cc7c")
            + path("M64 27v67M33 67l31-12 33 13", "none", "#a56e41", 3),
        "scorpion_claw": path("M31 87L17 61l11-34 21-12 9 30-11 18 17 12 17-13 16-38 15 30-12 38-26 17H47z", "#b56c44")
            + path("M31 35l11-8 5 17-13 21m51 17l14-26", "none", "#e5b174", 7)
            + path("M48 79l15 11 16-7", "none", "#f3d4a1", 8),
        "vulture_featherheart": path("M61 108C23 77 19 53 33 38c11-11 25-8 31 1 8-11 22-15 34-3 18 20-4 51-37 72z", "#be7559")
            + path("M63 107c-6-39 11-70 42-88-1 35-17 61-42 88z", "#e8cd91")
            + path("M64 101l29-60m-21 42l-3-17m10 3l14-3", "none", "#a98351", 4),
    }
    for x, y in [(58, 40), (66, 24), (49, 57), (76, 47), (41, 73), (72, 68)]:
        food["golden_wheat"] += path(f"M{x} {y}q-18-13-18 0t18 5q18-13 18-20t-18 15z", "#e3b35e", width=3)
    for x, y in [(30, 64), (39, 38), (88, 28), (94, 52), (49, 88)]:
        food["dill"] += path(f"M{x} {y}l-12-13m12 13l-15-1m15 1l9-13", "none", "#8ca764", 4)
    for angle in range(0, 360, 60):
        food["stone_bloom"] += group(path("M60 64C30 63 27 33 43 26c18-7 28 10 21 36z", "#e6bf71", width=3), rotate=angle)
    food["stone_bloom"] += ellipse(64, 64, 14, 14, "#b27b45") + ellipse(60, 59, 5, 5, "#f4db9b", "none")
    for name, body in food.items():
        svg(f"Generated/Ingredient/{name}.svg", body)
    return food


def recipe_catalog():
    source = (ROOT / "Scripts/Kitchen/TestItemDefs.gd").read_text(encoding="utf-8")
    ids = dict(re.findall(r'const (\w+): StringName = &"([^"]*)"', source))
    catalog = {}
    for line in source.splitlines():
        match = re.search(r'_recipe\((\w+), \[(.*)\], (\d)\)', line)
        if not match:
            continue
        name, parts, difficulty = match.groups()
        portions = []
        for m in re.finditer(r'_ingredient\((\w+), (\w+)(?:, (\d+))?', parts):
            portions += [(ids[m[1]], m[2])] * int(m[3] or 1)
        catalog[ids[name]] = (portions, int(difficulty))
    for name in ["drink_oasis_wine", "drink_gold_ale", "drink_qingmei_wine"]:
        catalog[name] = ([], 1)
    return catalog


def write_dish(name, body):
    """Bake separate food / service-ware layers into cached presentation variants."""
    source = ET.fromstring(f'<g>{body}</g>')
    vessels = [node for node in source if node.get("data-layer") == "vessel"]
    is_bowl = any(list(node) for node in vessels)
    for node in vessels:
        source.remove(node)
    food = ''.join(ET.tostring(node, encoding="unicode") for node in source)
    # Food coordinates remain identical across variants so plating never shrinks it.
    svg(f"Generated/Dish/{name}.svg", food)
    if name.startswith("drink_"):
        return
    if is_bowl:
        vessel = path("M14 58h100q-4 44-50 48-46-4-50-48z", "#ead9aa")
        vessel += ellipse(64, 58, 50, 26, "#fff1d0", "#ad7949", 3)
        preparation = path("M19 57H5v22h17m86-22h15v22h-17", "none", "#686e63", 6)
        preparation += path("M14 58h100v32q-6 22-50 22-44 0-50-22z", "#969c88")
        preparation += ellipse(64, 58, 50, 26, "#c7cbb2", width=3)
        svg(f"Generated/DishPrepared/{name}.svg", preparation + food)
    else:
        vessel = ellipse(64, 77, 54, 32, "#d9b778")
        vessel += ellipse(64, 69, 54, 32, "#f5dfac")
        vessel += ellipse(64, 68, 44, 23, "#fff0cf", "#bd945c", 2)
    svg(f"Generated/DishPlated/{name}.svg", vessel + food)


def dishes(food):
    from cohesive_menu_art import menu_icons
    icons = menu_icons(food, path, ellipse, rect, group)
    catalog = recipe_catalog()
    for name, (parts, difficulty) in catalog.items():
        if name in icons:
            write_dish(name, icons[name])
            continue
        if name.startswith("drink_"):
            colors = ["#b9c98a", "#e0ae54", "#c9867b"]
            color = {"drink_oasis_wine": colors[0], "drink_gold_ale": colors[1], "drink_qingmei_wine": colors[2]}.get(name, colors[sum(map(ord, name)) % 3])
            body = path("M34 28h60l-7 67-16 8H53L40 94z", "#f3dbac")
            body += path("M41 48h45l-5 41-13 8H57l-11-8z", color, "none")
            body += path("M38 28h52M45 36h38", "none", "#ad8553", 4)
            body += path("M96 44h9c15 0 14 29-8 34", "none", "#ad8553", 7)
            body += ellipse(61, 27, 29, 8, "#f8e8bf", width=3)
            body += ellipse(61, 27, 21, 4, color, "none")
            if parts:
                body += group(food.get(parts[-1][0], ""), 48, 50, .42)
        else:
            body = ""
            is_bowl = name.endswith(("_pot", "_bowl", "_cup", "_hotpot"))
            if is_bowl:
                body = path("M15 58h98c-5 37-20 49-49 49S20 94 15 58z", "#ad7449") + ellipse(64, 58, 49, 26, "#e6bd7b") + ellipse(64, 58, 40, 19, "#d19a57", width=2)
            # Finished forms are distinct from loose raw ingredients. Actual
            # composition and maturity stay in the gameplay signature/bubble.
            if "flatbread" in name or "_cake" in name or name.endswith("_crisp"):
                body += ellipse(59, 72, 32, 18, "#c88d45", width=3)
                body += ellipse(63, 61, 33, 18, "#e9bf75", width=3)
                body += path("M45 55l8 8m13-11l7 8m-21 10l8 5m18-12l7 2", "none", "#a96b3c", 3)
                garnish = next((food[item] for item,state in parts if item not in ["golden_wheat", "meat_white"]), "")
                body += group(garnish, 60, 39, .27)
            elif any(word in name for word in ["_roll", "_wrap"]):
                for x,y in [(32,58),(57,63)]:
                    body += path(f"M{x} {y}l14-19 29 18-14 24-29-14z", "#c8c68a", width=3)
                    body += path(f"M{x+3} {y+2}l22 13m-9-27l-10 20", "none", "#8c9c62", 3)
                    body += ellipse(x+34,y+7,7,11,"#bb7b50",width=2)
            elif "skewer" in name:
                for x in [36,66]:
                    body += path(f"M{x-5} 94l29-52", "none", "#96703c", 4)
                    for y in [53,69]:
                        body += rect(x+(69-y)*.45,y,17,16,"#c18b55",width=2,radius=4)
            elif any(word in name for word in ["frozen", "honey_feast", "sweet_bowl", "sunrise_banquet"]):
                for x,y in [(37,56),(65,59),(50,76)]:
                    body += path(f"M{x} {y}v-15l19 2v18z", "#eccd8d", width=2)
                    body += path(f"M{x} {y-15}l8-7 20 4-9 5z", "#fff0cf", width=2)
                sweet_garnish = "stone_bloom" if "stoneflower" in name else "sunny_berry"
                body += group(food[sweet_garnish],60,31,.3)
                body += path("M38 51q16-10 37 2", "none", "#c08b4e", 3)
            else:
                portions = list(dict.fromkeys(parts))[:3]
                if len(portions) == 1 and len(parts) > 1:
                    portions *= 2
                positions = [(18, 19), (49, 24), (34, 43)]
                for index, (item,state) in enumerate(portions):
                    cooked = food.get(item, "")
                    if item in ["meat_red", "meat_white", "camel_meat", "sand_hare"]:
                        cooked = meat("#a46e44", "#d4a466", "leg" if item in ["meat_white","sand_hare"] else "steak")
                        cooked += path("M36 49l12 18m5-26l12 20m6-22l12 17", "none", "#855437", 3)
                    elif item == "golden_wheat":
                        cooked = ellipse(63,66,39,24,"#e9bf75") + path("M44 56l12 12m13-14l12 12", "none", "#ac7945", 4)
                    elif item == "sand_potato":
                        cooked = path("M19 71l25-29 26 35zM57 81l28-40 24 34z", "#dfb372",width=3)
                    elif "GRIND" in state:
                        cooked = ellipse(64,72,34,18,"#b39b61",width=3) + path("M39 67l5-4m13 11l6-5m12 0l9-5", "none", "#e2c990", 4)
                    body += group(cooked, *positions[index], scale=.48)
        write_dish(name, body)
    # Failed food follows the same plating contract as valid recipes.
    failed = path("M22 78l11-29 26 7 12-17 24 20 10 27-25 12-40-2z", "#6f5741")
    failed += path("M36 65l9 12m14-17l12 13m6-15l12 16", "none", "#a98556", 5)
    write_dish("failed_food", failed)
    return len(catalog)


def cabinet(x, y, w, h, open_legs=False):
    top = rect(x, y, w, h, "#edb86a", width=3)
    top += rect(x+4, y+4, w-8, h-9, "#d79550", "none")
    top += path(f"M{x+5} {y+5}h{w-10}", "none", "#ffdc94", 2)
    if open_legs:
        bottom = path(f"M{x+3} {y+h}v43h7v-37h{w-20}v37h7v-43z", "#a96638", width=3)
    else:
        bottom = rect(x+3, y+h, w-6, 19, "#a96638", width=3)
        bottom += rect(x+9, y+h+4, w-18, 10, "#ca8a50", "#754829", 2)
        bottom += rect(x+w/2-5, y+h+6, 10, 2, "#f3cc7c", "none", 0)
    return bottom + top


def facilities():
    # Retain legacy 1024 canvases so split sprites and carrying previews agree.
    svg("Restaurant/prep_table.svg", cabinet(49, 43, 158, 105, True), (1024,1024), (256,256))
    body = cabinet(12, 58, 232, 98)
    body += rect(20, 66, 216, 79, "#e9c68b", "#bd8246", 2)
    body += path("M25 71h206", "none", "#f8dcaa", 2)
    svg("Cooker/assembly_station.svg", body, (1024,1024), (256,256))
    body = cabinet(17, 60, 222, 85)
    body += rect(55, 77, 146, 48, "#e4c995", "#805c3b", 2)
    svg("Restaurant/serving_counter.svg", body, (1024,1024), (256,256))
    for kind in ["cut", "grind", "roast"]:
        body = cabinet(42, 44, 172, 112)
        if kind == "cut":
            # Keep the central food slot clear; fixed marks depict tools, not food.
            body += rect(50, 50, 158, 92, "#f1d19a", "#9f6d3f", 3, radius=7)
            body += path("M59 62h140M59 75h140M59 88h140", "none", "#e0b878", 2)
            body += path("M65 114l8-14m-2 25l12-21m-2 27l9-16", "none", "#bd9056", 2)
            body += path("M148 55l47 9-5 26-40-10-6-6z", "#d9e0d6", "#626d62", 3)
            body += path("M148 55l-24-5-3 12 24 5z", "#754829", width=3)
            body += path("M155 76l29 7", "none", "#fff7df", 3)
        elif kind == "grind":
            # Grinding station: dark stone surface and an oversized mortar/pestle
            # deliberately avoid the flat cutting-board silhouette.
            body += rect(50, 50, 158, 92, "#6f887e", "#3e514b", 3, radius=9)
            body += path("M60 62h138M60 130h138", "none", "#9db09c", 2)
            body += ellipse(117, 104, 43, 27, "#b5b8a0", "#3e514b", 4)
            body += ellipse(117, 98, 34, 18, "#626d5e", "#35483f", 3)
            body += path("M111 94l46-56 11 9-43 59z", "#c5b38c", "#654f3b", 4)
            body += path("M155 43l10-9 12 10-10 10z", "#e0c99e", "#654f3b", 3)
        else:
            body += rect(54, 54, 148, 89, "#574d3c", width=3)
            body += rect(61, 61, 134, 75, "#7c7055", "none")
            for x in range(70,197,20):
                body += path(f"M{x} 64v69", "none", "#c3b894", 3)
            body += path("M95 170l-3-11 8 5 7-12 5 15 8-5-2 8z", "#e6a357", width=2)
        svg(f"Cooker/{kind}_station.svg", body, (1024,1024), (256,256))
    body = cabinet(4, 14, 120, 94)
    body += rect(12, 24, 104, 72, "#eed2a0", "#a77845", 2)
    svg("Restaurant/storage_cabinet.svg", body, (1024,1024))
    # A deeper top plane, with the same two-cell cabinet silhouette and palette.
    body = cabinet(5, 16, 246, 101)
    body += rect(19, 30, 94, 69, "#bd9c6c", "#805c3b", 3)
    for x in range(26,111,12):
        body += rect(x, 36, 4, 56, "#e4c995", "none", 0)
    body += rect(124, 29, 112, 71, "#b2c5b3", "#634e39", 3)
    body += rect(132, 36, 96, 56, "#4d9190", "#305d62", 3)
    body += path("M142 46h30m28 33h17", "none", "#8ac6b0", 3)
    body += path("M183 29V6h-26v10", "none", "#513420", 8)
    body += path("M183 29V6h-26v10", "none", "#edc97e", 4)
    svg("Kitchen/plate_wash_station.svg", body, (256,144), (256,144))
    body = path("M18 38h92l-8 96H26z", "#a96638")
    body += path("M35 57l4 64m25-63v63m29-64l-4 64", "none", "#754829", 4)
    body += ellipse(64, 35, 51, 25, "#d2b179") + ellipse(64, 33, 39, 15, "#4a4031", width=3)
    body += rect(28, 107, 72, 10, "#ceac70", width=2)
    body += rect(48, 64, 32, 29, "#e9cd91", "none")
    body += path("M55 72h18m-15 5v10m7-10v10m6-10v10", "none", "#65513a", 3)
    svg("Kitchen/trash_bin.svg", body, (128,144), (128,144))
    # Horizontal cask: bulging staves, curved hoops, visible end and tap.
    body = path("M40 105l-8 27h34l7-24m111-3l-7 27h34l-7-25", "#a96638", width=3)
    body += path("M41 23Q126-3 211 23q32 14 33 47-1 36-33 47-85 24-170 0Q15 99 15 70q0-31 26-47z", "#c98a4c", width=4)
    body += path("M40 24q83-22 166 0l11 15q-85-18-180 1z", "#edb86a", "none")
    body += path("M31 52q94-17 190-3M29 76q93-3 193 4M34 99q87 14 182 6", "none", "#956036", 3)
    body += path("M72 16q-22 51-3 109l17 3Q66 69 89 12z", "#b3af8b", width=3)
    body += path("M161 12q23 54 3 116l17-3q21-59-3-109z", "#b3af8b", width=3)
    body += path("M78 28q-10 29-9 48m103-47q10 30 7 49", "none", "#e3d3a3", 4)
    body += ellipse(213, 70, 25, 46, "#ad7041", width=4)
    body += ellipse(213, 69, 18, 37, "#d79a57", "#805131", 3)
    body += path("M208 38v61m10-61v61", "none", "#ab7041", 2)
    body += path("M213 80v18h17v10", "none", "#513420", 10)
    body += path("M213 80v18h17v10", "none", "#f3cc7c", 5)
    body += path("M207 80h12", "none", "#513420", 5)
    # Blank plaque holds the real batch icon drawn by the barrel view.
    body += rect(91, 34, 66, 67, "#f3dfb0", "#805c3b", 3, radius=10)
    svg("Kitchen/drink_barrel.svg", body, (256,144), (256,144))


if __name__ == "__main__":
    from cohesive_enemy_art import generate
    food = ingredients()
    count = dishes(food)
    facilities()
    enemies = generate(ART, svg, path, ellipse, rect, group)
    print(f"Generated {len(food)} ingredients, {count} dishes/drinks, {enemies} enemies and 10 facility textures.")
