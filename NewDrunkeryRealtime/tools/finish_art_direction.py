"""Offline art finish for the existing vector catalogue.

Run after any source art generator. Repeated runs replace, rather than stack,
the finish. Shapes, viewboxes, plating variants and gameplay colours stay owned
by their existing generators. No runtime filters or extra texture loads.
"""
from pathlib import Path
import colorsys
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "ArtResource"
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)


def tint(value, amount):
    rgb = [int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    h, light, sat = colorsys.rgb_to_hls(*rgb)
    light = light + (1 - light) * amount if amount > 0 else light * (1 + amount)
    return "#" + "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, light, sat))


def path(d, color, width=1.7, fill="none", opacity=1):
    return f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" opacity="{opacity}" stroke-linecap="round" stroke-linejoin="round"/>'


def dot(x, y, r, color, opacity=1):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}" opacity="{opacity}"/>'


def details(relative, view):
    name = relative.stem
    category = relative.parts[0]
    body = ""
    if relative.parts[:2] == ("Generated", "Ingredient"):
        if name in ("meat_red", "camel_meat"):
            body += path("M32 47q12-12 21-4t17 2m-38 26q11 10 19 3m24-30q14 4 17 15M73 87l10-4", "#ffe7c7", 2.3, opacity=.7)
            body += path("M37 44l5-4m-13 24 3 8", "#fff4de", 3)
        elif name == "monitor_tenderloin":
            body += path("M11 18l7 4m13-8 4 2M16 30l7 4m9-7 4-2", "#ffe2ba", 1.1, opacity=.7)
        elif name in ("sand_hare", "meat_white"):
            body += path("M30 43q-4 16 5 25m13-41 9-1m-7 54q9 2 16-5", "#fff0ce", 2.4, opacity=.75)
        elif name == "sunny_berry":
            body += path("M34 59q-5 7-4 13m45-27-2 6", "#fff3ce", 3)
            body += dot(35, 63, 1.4, "#fff8df") + dot(77, 43, 1.2, "#fff8df")
            body += path("M47 95q9 3 17-3m18-16 6-3", "#a18d4f", 1.5, opacity=.6)
        elif name in ("dryfrost_cabbage", "crisp_sprout", "dill"):
            body += path("M53 74l-10-7m19 16-10-5m22-6 10-8M62 49l-5-9", "#f2f1bc", 1.4, opacity=.65)
        elif name == "sand_potato":
            for x, y in [(39, 56), (65, 86), (83, 69), (55, 41)]:
                body += dot(x, y, 1.5, "#946c48", .7) + dot(x - 2, y - 2, 1, "#f8d69a")
        elif name == "golden_wheat":
            body += path("M35 102q18-28 25-51m4 48 9-34", "#fff1ad", 1.6)
        elif name == "sun_seed":
            body += path("M53 43q-11 20-5 34m34-20q5 18-3 29", "#ffe7ae", 2)
        elif name == "stone_bloom":
            body += path("M39 58l8-7m24-18 4 9m13 21-8 1", "#fff0d8", 2.4)
        else:
            body += path("M42 39l7-4m35 29 5-7", "#ffebbb", 2.4, opacity=.8)
    elif relative.parts[:2] == ("Generated", "Enemy"):
        # Small species-specific marks describe surfaces, rather than floating UI.
        if "scarab" in name or "beetle" in name:
            body += path("M37 59q-7 18 1 32m51-31q7 18-1 31M48 47l16 7 16-7", "#ecf2c5", 2.1, opacity=.55)
            body += dot(42, 69, 2.2, "#f5f1cd", .7) + dot(86, 69, 2.2, "#f5f1cd", .7)
        elif name == "red_lamb_enemy":
            body += path("M33 79q0-8 6-7t8 0m-13 13q3-7 9-4m34-6q9-4 12 5M44 43l3-4m27 0 3 3", "#f9c1b0", 2.1, opacity=.75)
            body += dot(46, 70, 3.5, "#e69a98", .65) + dot(82, 70, 3.5, "#e69a98", .65)
        elif name == "sand_hare_enemy":
            body += path("M49 28l3 13m20-15-2 14M40 78l-8-2m9 9-9 1m51-8 9-2m-9 9 9 1", "#fce1c4", 1.7)
        elif "bird" in name or "vulture" in name:
            body += path("M28 54l8 7m-13 0 11 8m59-15-8 7m13 0-11 8M54 84l9 8 9-8m-17 8 8 7 7-7", "#e3e5d4", 2, opacity=.65)
        elif "moth" in name:
            for x in [30, 96]:
                body += dot(x, 55, 7, "#855469", .8) + dot(x, 55, 3, "#ffe5ad")
            body += path("M34 36l10 14m50-14L84 50", "#fff0b7", 2)
        elif name == "camel_enemy":
            body += path("M29 64q7-15 15-13m8 7q6-11 12-6M83 67l3 13m-30-3 2 10", "#f0c6c7", 2, opacity=.6)
            body += path("M99 47q6 4 12 0", "#7e546e", 1.8)
        elif "scorpion" in name:
            body += path("M48 84q16 8 32 0m-30 13q14 7 28 0M14 73l5-5m89 0 6 5", "#f8c7b2", 2, opacity=.65)
        elif "sandworm" in name:
            body += path("M30 44l7-7m8-8 7-2m21 6 6 4M40 75l5-4m46 4 5 4", "#ffe0a2", 2.3)
        elif "monitor" in name:
            body += path("M47 81l5-4m42 8 5 4M57 128l5-2m24 2 5 2", "#c2dba9", 2.2)
        elif "thorn" in name:
            body += path("M40 65l7 5m33-4-7 5M49 86l7 5m22-5-7 5", "#d6e7aa", 2.1)
        else:
            body += path("M44 47l-4 10m45-10 4 10M47 88h8m19 0h8", "#f4e3ab", 2.1)
    elif category in ("Cooker", "Restaurant", "Kitchen", "Facilities"):
        w, h = view[2:]
        if name in ("prep_table", "assembly_station", "serving_counter", "cut_station", "grind_station", "roast_station"):
            if name == "prep_table":
                body += path("M58 52h139m-130 8h23m64 71h33M61 154v22m133-22v22", "#ffe4b2", 1.8, opacity=.65)
            elif name == "assembly_station":
                body += path("M25 77h33m138 0h28M27 132h22m147 0h27M29 162h198", "#fff0c8", 1.8, opacity=.6)
                for x in [27, 229]:
                    body += dot(x, 153, 2.3, "#edc888") + path(f"M{x-1} 153h2", "#805641", 1)
            elif name == "serving_counter":
                body += path("M28 68h198M25 146h204M61 84h133", "#ffdf9e", 1.8)
            elif name == "cut_station":
                body += path("M58 58h140m-139 79h138M159 59l28 7", "#fff0c7", 1.8, opacity=.8)
                body += dot(133, 55, 1.8, "#e9c47f")
            elif name == "grind_station":
                body += path("M88 104q26 14 55 0m-28-11 34-42", "#e7e5ca", 2.1)
                for x in [79, 90, 137]:
                    body += dot(x, 123, 1.6, "#d7c18d")
            else:
                body += path("M62 60h132M67 145h122", "#e7c18b", 2)
                for x in [79, 109, 139, 169]:
                    body += dot(x, 149, 2.3, "#f4ab58", .85)
        elif name == "plate_wash_station":
            body += path("M13 25h227m-225 85h219M137 42l21-1m-19 6h12", "#ffe5b7", 1.5, opacity=.6)
            body += path("M145 78q13-6 26 0m15-22q14-6 28 0", "#b8e4d3", 1.8)
            for x, y in [(148, 59), (213, 83), (220, 50)]:
                body += dot(x, y, 2, "#d4f1df", .8)
        elif name == "drink_barrel":
            body += path("M41 28q13-5 25-6m27-5 24-2M25 61q21-3 39-3m27 51 33 1M186 30l8 3", "#ffe2aa", 1.8, opacity=.7)
            for x in [73, 176]:
                for y in [35, 101]:
                    body += dot(x, y, 2.3, "#f4e0aa") + dot(x, y + .8, .8, "#79664d")
        elif name == "storage_cabinet":
            body += path("M15 27h96m-93 64h20m47 0h22M15 112h95", "#ffe3ae", 1.4)
        elif name in ("plate", "dirty_plate"):
            body += path("M24 57q8-18 31-20m-27 39q13 13 35 13", "#fff7dd", 2.6, opacity=.8)
            body += path("M92 52q11 8 10 17", "#b8cfc5", 2, opacity=.7)
        elif name == "seasoning_box":
            body += path("M25 45l24-8m42 7 9 5M28 84l14 5", "#fff0c6", 1.6, opacity=.7)
        elif category == "Facilities" and name not in ("transit_orb", "bear_trap", "magic_net", "ice_water", "shuttle_cart"):
            body += path("M28 102h71m-66 5h20M29 73l12 1", "#f6d9a1", 1.7, opacity=.65)
            for x in [30, 98]:
                body += dot(x, 96, 2, "#f1d69b") + path(f"M{x-1} 96h2", "#7a6046", 1)
        elif name == "trash_bin":
            body += path("M31 51l3 43m65-40-3 40M31 112h65", "#f3cf96", 1.8, opacity=.6)
    elif relative.parts[:2] in (("Generated", "Dish"), ("Generated", "DishPrepared"), ("Generated", "DishPlated")):
        # The authored silhouettes already distinguish courses. Fine highlights
        # are placed only on existing shapes by the material pass below.
        pass
    return body


def finish(file):
    tree = ET.parse(file)
    root = tree.getroot()
    if root.get("data-art-direction") == "character-refinement-v1":
        return  # Preserve the approved flat palette and facial shapes.
    # Composed assets (e.g. the merchant) may contain finished source groups.
    # Remove their old definitions too, then build one unique palette.
    for parent in list(root.iter()):
        for child in list(parent):
            if child.get("id") in ("art-materials", "art-details"):
                parent.remove(child)
    for node in root.iter():
        if node.get("data-base-fill"):
            node.set("fill", node.get("data-base-fill"))
    gradients = ET.Element(f"{{{NS}}}defs", {"id": "art-materials"})
    palette = {}
    relative = file.relative_to(ART)
    # Round two deliberately uses flat pigment for world props and creatures.
    # Foods and NPCs retain their previous finish until their own design pass.
    matte = relative.parts[:2] == ("Generated", "Enemy") or relative.parts[0] in ("Cooker", "Facilities", "Kitchen", "Environment") or (relative.parts[0] == "Restaurant" and relative.stem in ("prep_table", "serving_counter", "storage_cabinet"))
    if matte:
        root.set("data-art-direction", "soft-desert-v2")
        tree.write(file, encoding="unicode", xml_declaration=False)
        with file.open("a", encoding="utf-8") as out:
            out.write("\n")
        return
    food = relative.parts[0] == "Generated" and relative.parts[1] in ("Ingredient", "Dish", "DishPrepared", "DishPlated")
    for node in list(root.iter()):
        color = node.get("fill", "")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            continue
        rgb = [int(color[i:i+2], 16) for i in (1, 3, 5)]
        if max(rgb) < 82 or min(rgb) > 235:
            continue  # Ink, pupils, highlights and transparency remain crisp.
        if node.tag.endswith("circle") and float(node.get("r", 99)) < 6:
            continue
        if node.tag.endswith("ellipse") and float(node.get("rx", 99)) < 8:
            continue
        if color not in palette:
            ident = f"material-{len(palette)}"
            palette[color] = ident
            gradient = ET.SubElement(gradients, f"{{{NS}}}linearGradient", {"id": ident, "x1": "0.18", "y1": "0", "x2": "0.72", "y2": "1"})
            for offset, shade in [("0", tint(color, .22 if food else .16)), (".48", color), ("1", tint(color, -.22))]:
                ET.SubElement(gradient, f"{{{NS}}}stop", {"offset": offset, "stop-color": shade})
        node.set("data-base-fill", color)
        node.set("fill", f"url(#{palette[color]})")
    root.insert(0, gradients)
    view = [float(v) for v in root.get("viewBox", "0 0 128 128").split()]
    body = details(relative, view)
    if body:
        root.append(ET.fromstring(f'<g xmlns="{NS}" id="art-details">{body}</g>'))
    root.set("data-art-direction", "desert-atelier-v1")
    tree.write(file, encoding="unicode", xml_declaration=False)
    with file.open("a", encoding="utf-8") as out:
        out.write("\n")


def main():
    files = sorted(ART.rglob("*.svg"))
    for file in files:
        if "Process" in file.parts:
            continue  # Maturity/method colours are gameplay semantics.
        finish(file)
    print(f"Finished {len(files) - len(list((ART / 'Generated/Process').glob('*.svg')))} vector assets.")


if __name__ == "__main__":
    main()
