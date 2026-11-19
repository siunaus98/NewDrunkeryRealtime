"""Offline silhouettes for menu items that must remain distinct at icon size.

This module owns presentation only; recipe data stays in TestItemDefs.gd.
"""


def menu_icons(food, path, ellipse, rect, group):
    def plate(rim="#72a99b", square=False):
        # Semantic layer, removed for the menu and unplated world presentation.
        return '<g data-layer="vessel"></g>'

    def bowl(color):
        return ('<g data-layer="vessel">'
                + path("M14 58h100q-4 44-50 48-46-4-50-48z", color)
                + ellipse(64, 58, 50, 26, "#f5dfac") + '</g>')

    def garnish(item, x, y, scale=.3):
        return group(food[item], x, y, scale)

    def plum(x, y, color="#bbc264", size=12):
        return (ellipse(x, y, size, size, color, width=2)
                + path(f"M{x+2} {y-size+3}q-5 {size-3} 0 {2*size-6}", "none", "#8c8245", 2)
                + path(f"M{x} {y-size}l3-5", "none", "#754829", 2))

    def bubbles(color):
        return "".join(ellipse(x, y, 3, 3, color, "none") for x, y in [(52, 63), (67, 78), (77, 55)])

    icons = {}
    # Every drink has a different vessel outline as well as a distinct liquid.
    body = path("M30 26h68l-6 28q-6 22-24 25v24h19v9H41v-9h19V79Q38 76 34 54z", "#d7e5ca")
    body += path("M36 41h56l-5 17q-8 20-23 16-19-2-23-16z", "#4ca99c", width=2)
    body += ellipse(64, 27, 34, 9, "#eef1d4", width=3) + ellipse(64, 27, 26, 4, "#75c1a3", "none")
    body += garnish("crisp_sprout", 74, 24, .28)
    icons["drink_oasis_wine"] = body

    body = path("M88 44h14q22 2 12 30-7 12-23 10", "none", "#c18c45", 9)
    body += rect(27, 30, 65, 74, "#efca7e", radius=9) + rect(34, 43, 51, 52, "#d58a31", "none", radius=5)
    body += path("M44 56v29m17-29v29m16-29v29", "none", "#ffe4a0", 4)
    body += path("M25 38q-6-14 8-16 5-14 18-7 14-9 24 1 16-4 20 9 2 15-9 15H36z", "#fff0cf", width=3)
    icons["drink_gold_ale"] = body

    body = path("M29 39h70l-2 20q-1 23-29 27v16h18v9H42v-9h18V86Q31 83 30 60z", "#f2d5b9")
    body += path("M35 49h58v11q-4 21-29 20-26-1-28-20z", "#d78b95", width=2)
    body += ellipse(64, 39, 35, 10, "#fce4c6", width=3) + ellipse(64, 39, 27, 5, "#bb647f", "none")
    body += plum(91, 39, "#d4cb72", 13)
    icons["drink_qingmei_wine"] = body

    body = path("M40 15h48L80 71q-3 13-12 15v18h17v8H43v-8h17V86q-10-2-13-15z", "#edf0cf")
    body += path("M46 35h36l-8 34q-3 12-10 12-8-1-11-13z", "#a2bc63", width=2) + bubbles("#f3e9b3")
    body += plum(87, 28, "#c4cc75", 11)
    icons["drink_qingmei_light_ferment"] = body

    body = path("M10 47h49l-4 39q-2 14-21 14-18 0-20-14z", "#c5d7c7")
    body += path("M16 60h37l-3 24q-3 10-16 9-13 0-15-9z", "#4eafa4", width=2)
    body += path("M59 30h58l-5 57q-3 17-25 17-21 0-23-17z", "#f0ce8c")
    body += path("M66 44h44l-4 38q-3 12-18 12-17 0-18-12z", "#d78c3c", width=2)
    body += path("M66 44q20-10 44 0", "none", "#fff0cf", 8)
    icons["drink_double_ferment"] = body

    body = path("M42 23h44l-3 21q24 33-3 47l-12 3v12h17v7H43v-7h17V94Q24 89 32 62l13-18z", "#f3d795")
    body += path("M43 54h40q21 28-19 33-35-1-21-33z", "#e6ad47", width=2)
    body += path("M47 60q6 12 3 19", "none", "#fff0cf", 5)
    body += garnish("stone_bloom", 67, 10, .36)
    icons["drink_stoneflower_honey"] = body

    body = path("M88 41h15q18 5 10 30l-17 13", "none", "#986b3f", 8)
    body += path("M32 17h57l-6 24 17 48q1 19-36 20-35-1-35-19l13-48z", "#e3b25c")
    body += path("M43 50h34l14 38q-1 13-27 13-27 0-27-13z", "#bf7737", width=2)
    body += path("M35 18l-13 8 17 5m3-1h39", "none", "#f5dfac", 4)
    body += garnish("sun_seed", 46, 52, .35) + garnish("dill", 17, 34, .32)
    icons["drink_sunwheel_infusion"] = body

    body = path("M49 15h30v24l22 17v41q-4 15-37 15-32 0-37-15V56l22-17z", "#80608e")
    body += rect(46, 9, 36, 14, "#d9b46a", radius=4) + path("M39 58h50v35H39z", "#ab879f", width=2)
    body += path("M44 69l3 17h34l4-17-13 6-8-14-9 14z", "#f1ce7c", width=3)
    body += path("M38 55l13-10m-14 51h53", "none", "#dfb677", 4)
    icons["drink_royal_aged"] = body

    body = path("M37 22h52l-5 42q-1 20-16 24v16h17v8H43v-8h17V88Q45 85 43 64z", "#c9e2df")
    body += path("M44 43h38l-4 23q-2 16-14 16-11-1-14-16z", "#77a6c9", width=2)
    body += path("M67 48q-16 2-12 17 5 12 18 5-12-1-14-10-1-7 8-12z", "#fff0cf", "none")
    body += path("M27 24v10m-5-5h10m66 12v12m-6-6h12", "none", "#89b7c6", 3)
    icons["drink_moon_dew"] = body

    body = path("M30 35H14v24q2 13 21 17m61-41h18v24q-1 13-22 17", "none", "#bd7545", 7)
    body += path("M27 24h74l-7 41q-4 17-25 22v15h19v10H40v-10h20V87Q39 83 35 65z", "#bd6245")
    body += path("M34 33h60l-7 27q-6 18-23 18-18-1-24-18z", "#eea23d", width=3)
    body += path("M51 62l12-25 13 25-13-7z", "#f9d68b", width=2)
    icons["drink_scorch_double_ferment"] = body

    # Small whole rounds / a filled triangle / a rectangular jam-layer slice.
    body = plate("#bf9259")
    for x, y in [(45, 55), (81, 57), (62, 80)]:
        body += ellipse(x, y+4, 23, 13, "#b4793d", width=3) + ellipse(x, y, 23, 13, "#eac574", width=3)
        body += path(f"M{x-10} {y-3}l4 3m6-5l4 3m-8 5l4 2", "none", "#ae7239", 3)
    icons["dish_golden_flatbread"] = body

    body = plate("#6a9eac", True)
    body += path("M27 77l68-31 3 30-58 21z", "#c88745", width=3)
    body += path("M33 79l61-27 2 17-54 22z", "#f2ddae", width=3)
    body += path("M27 68l55-37 17 33-59 22z", "#e9b958", width=3)
    body += path("M45 63l6-4m11-7l6-4m3 19l7-4m-24 9l4-3", "none", "#a26838", 3)
    body += path("M48 83l7-2m10-5l9-3m8 1l8-3", "none", "#ae8060", 4)
    icons["dish_golden_fowl_cake"] = body

    body = plate("#a27c9d", True)
    body += path("M28 55l61-13 17 32-63 21-15-15z", "#c98e48", width=3)
    body += path("M29 66l16 16 57-17v10L43 94 28 80z", "#995b83", width=3)
    body += path("M28 55l16 18 61-18-16-20z", "#f0cf81", width=3)
    body += path("M44 51l12 10m10-15l12 9m7-15l9 9", "none", "#b97d40", 3)
    body += plum(93, 86, "#c5c870", 10)
    icons["dish_golden_baked_cake"] = body

    body = plate("#829d60")
    for x, y, turn in [(26, 67, -20), (48, 57, 0), (65, 64, 18)]:
        cracker = path("M15 24l41-9 16 32-46 12z", "#dca455", width=3)
        for sx, sy in [(32, 30), (47, 28), (40, 44), (56, 41)]:
            cracker += ellipse(sx, sy, 3, 5, "#754829", "none")
        body += group(cracker, x-13, y-28, .9, turn)
    body += garnish("crisp_sprout", 10, 57, .3)
    icons["dish_sunseed_crisp"] = body

    body = plate("#9ca365")
    for x, y in [(27, 62), (62, 76)]:
        body += path(f"M{x} {y}l3-30 44 19-7 24z", "#72a66b", width=3)
        body += ellipse(x+22, y-11, 20, 11, "#bc5e59", width=3)
        body += path(f"M{x+10} {y-14}l8 6m8-4l6 5", "none", "#e7b29a", 4)
        body += path(f"M{x+5} {y+2}l28 9", "none", "#bfd28d", 3)
    icons["dish_red_roll"] = body

    body = plate("#c8885d", True)
    for x, y in [(24, 54), (61, 67)]:
        body += path(f"M{x} {y}l10-17 31 14-9 24-29-9z", "#e6ca8e", width=3)
        body += ellipse(x+30, y+9, 12, 14, "#f2e5bb", width=3)
        body += rect(x+24, y+3, 7, 10, "#ce8a45", "none")
        body += path(f"M{x+7} {y-3}l13 6m-17 3l13 6", "none", "#a87245", 3)
    icons["dish_fowl_sand_roll"] = body

    body = plate("#769e97")
    for x, y in [(35, 59), (61, 77), (87, 57)]:
        body += ellipse(x, y+4, 17, 16, "#779e6d", width=3)
        body += ellipse(x, y, 17, 14, "#d3db9e", width=3)
        body += path(f"M{x+9} {y}q-2-11-13-6-12 8 2 13 9 2 9-5-2-6-7-1", "none", "#63987c", 3)
    icons["dish_dryfrost_roll"] = body

    body = plate("#b97b67", True)
    body += path("M28 59l24-20 48 21-19 33-48-8z", "#9da96d", width=3)
    body += path("M28 59l32 9 21 25m-29-54l8 29 40-8", "none", "#dde0a5", 4)
    body += path("M64 50l22 9-9 16-20-9z", "#b97e5d", width=3)
    body += path("M41 55l40 27m-16-37L46 87", "none", "#63805b", 4)
    icons["dish_dryfrost_meat_wrap"] = body

    # Dessert identities are visible without relying on a tiny garnish.
    body = bowl("#9c738f") + ellipse(64, 58, 40, 19, "#bf6d87", width=2)
    body += plum(50, 52, "#c8c66f", 16) + plum(80, 60, "#d8cd82", 13)
    body += path("M31 64q12-7 22 4m9 5q13 4 30-3", "none", "#fce6c6", 4)
    icons["dish_qingmei_sweet_bowl"] = body

    body = plate("#7caeac")
    body += path("M28 74l9-30 26-9 23 9 14 28-12 17H42z", "#d2ad57", width=3)
    body += path("M37 48l27-9 21 9 6 24-22 13-29-10z", "#f2d178", width=3)
    body += path("M38 58q20 11 51-1v14q-26 13-49 0z", "#b681a4", width=2)
    body += path("M48 48l-4 10m26-12l9 6", "none", "#fff0cf", 4)
    body += garnish("stone_bloom", 48, 6, .34)
    icons["dish_stoneflower_frozen"] = body

    body = bowl("#a86b59") + ellipse(64, 58, 40, 19, "#8d5a6f", width=2)
    body += plum(61, 48, "#c3b563", 17)
    body += path("M49 39l5 12m4-16l5 12m4-11l6 11", "none", "#8f6338", 3)
    body += garnish("sun_seed", 69, 53, .3)
    icons["dish_qingmei_seared_cup"] = body

    body = plate("#c48663", True)
    for x, y in [(28, 63), (55, 77)]:
        body += path(f"M{x} {y}v-18l34-9 16 21-34 13z", "#b57b43", width=3)
        body += path(f"M{x} {y-18}l15 15 35-12", "none", "#e8bd6b", 6)
        body += path(f"M{x+13} {y-9}l21-6m-13 13l20-6", "none", "#8f5d36", 3)
    body += plum(88, 49, "#c0bf64", 16) + plum(66, 40, "#d5ca7c", 13)
    body += path("M31 81q25-12 41 4", "none", "#f5dbac", 5)
    icons["dish_sunrise_banquet"] = body

    body = plate("#a282ad")
    for x, y in [(38, 60), (65, 77), (88, 53)]:
        body += ellipse(x, y+3, 18, 12, "#b4844e", width=3)
        body += path(f"M{x-17} {y}q-3-22 16-22 20 1 19 22z", "#f1ce7f", width=3)
        body += path(f"M{x-12} {y-5}q10-10 23-1", "none", "#e0a13d", 4)
    body += plum(31, 82, "#b7c56e", 10) + garnish("stone_bloom", 42, 14, .33)
    icons["dish_stoneflower_honey_feast"] = body

    body = bowl("#648d85") + ellipse(64, 58, 40, 19, "#dc9f4f", width=2)
    body += garnish("stone_bloom", 38, 17, .42) + plum(89, 61, "#c0ba63", 10)
    icons["dish_stoneflower_baked_cup"] = body

    # Pots differ in silhouette and broth, rather than three brown bowls.
    body = bowl("#cfb791") + ellipse(64, 58, 40, 19, "#e8ce85", width=2)
    body += garnish("meat_white", 23, 19, .4) + garnish("dryfrost_cabbage", 61, 23, .32)
    icons["dish_fowl_pot"] = body

    body = bowl("#a75943") + ellipse(64, 58, 40, 19, "#b9643b", width=2)
    body += garnish("meat_red", 20, 19, .39) + garnish("sun_seed", 59, 19, .35)
    body += path("M38 62l15 6m14-3l16-8", "none", "#b6c785", 6)
    icons["dish_oasis_hotpot"] = body

    body = bowl("#659a88") + ellipse(64, 58, 40, 19, "#82a16c", width=2)
    body += garnish("meat_white", 24, 14, .32)
    body += path("M61 37l12-9 12 17-14 7zM70 53l12-6 9 13-14 6z", "#efcf8f", width=2)
    body += garnish("dill", 30, 5, .43)
    icons["dish_dill_fowl_pot"] = body

    body = bowl("#d0ad73")
    for x, y in [(41, 48), (59, 39), (73, 52)]:
        body += path(f"M{x} {y}l5-17 16 7-7 16z", "#d8a34e", width=2)
    body += garnish("dill", 16, 10, .48)
    icons["dish_dill_sand_potato_cup"] = body

    # Main courses use larger cooked forms and separate serving silhouettes.
    body = plate("#8d6d80", True)
    for x, y in [(30, 57), (49, 69), (68, 80)]:
        body += path(f"M{x} {y}l33-16 16 12-32 19z", "#9c5143", width=3)
        body += path(f"M{x+8} {y}l23-10m-14 16l23-10", "none", "#e4a070", 3)
    body += garnish("dill", 12, 26, .37)
    icons["dish_spiced_lamb"] = body

    body = plate("#889aab")
    body += path("M23 60q-5-25 24-24 29 5 20 30-28 18-44-6z", "#bd8551", width=3)
    body += path("M60 79q-5-25 24-24 29 5 20 30-28 18-44-6z", "#965463", width=3)
    body += path("M32 48l15 14m-2-19l13 12m14 10l15 14m-3-18l11 12", "none", "#f0c38c", 4)
    body += path("M18 81l12-10 11 16-15 3", "#a4b877", width=2)
    icons["dish_camel_double_roast"] = body

    body = plate() + ellipse(62, 65, 41, 20, "#9b6041", width=2)
    for x, y, color in [(26, 57, "#d39b62"), (50, 73, "#af6e55"), (76, 54, "#ddb47a")]:
        body += path(f"M{x} {y}l9-15 20 13-10 15z", color, width=3)
    body += path("M31 40l10 7m18 7l11 6m11 17l12-4", "none", "#a8c582", 5)
    icons["dish_royal_heat_plate"] = body

    body = plate("#8c799c", True)
    body += path("M23 67q5-26 32-21l28 24-20 20-35-5z", "#b77059", width=3)
    body += path("M34 63l13 16m-1-22l14 18m0-12l13 12", "none", "#f0be8b", 3)
    body += ellipse(49, 86, 25, 4, "#9c5c80", "none")
    body += path("M86 30h25l-3 26q-10 10-19 0z", "#d4dfbd", width=3)
    body += path("M90 42h17l-2 11q-5 5-12 0z", "#5f9d88", "none")
    body += garnish("sun_seed", 68, 52, .3)
    icons["dish_wine_platter"] = body
    return icons
