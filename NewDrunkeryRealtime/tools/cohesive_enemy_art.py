"""Original rounded desert cast. Standalone execution changes enemies only.

Keep species silhouettes, authored texture dimensions and monitor's UP-facing
orientation. Anatomy is reduced to a few soft shapes; no material gradients.
"""
import xml.etree.ElementTree as ET


def generate(art, svg, path, ellipse, rect, group):
    sizes = {}
    for file in (art / 'Generated/Enemy').glob('*.svg'):
        root = ET.parse(file).getroot()
        sizes[file.stem] = (int(root.get('width')), int(root.get('height')))
    ink = '#69534e'

    def p(d, fill='none', stroke=ink, width=3.2):
        return path(d, fill, stroke, width)

    def e(x, y, rx, ry, fill, stroke=ink, width=3.2):
        return ellipse(x, y, rx, ry, fill, stroke, width)

    def bead(x, y, rx=2.4, ry=2.8):
        return e(x, y, rx, ry, '#594742', 'none')

    def blush(x, y, color='#e6a09e', rx=4):
        return e(x, y, rx, 2.3, color, 'none')

    creatures = {}

    # Strawberry-milk fleece, tiny boots and a cream face nestled in the wool.
    b = p('M35 94v13q6 7 13 0V94m32 0v13q6 7 13 0V94', '#ba8181')
    b += e(23, 77, 10, 9, '#f1c4b8')
    b += p('M22 62q-8-18 10-24-1-17 19-17 12-14 27-3 20-7 27 12 17 4 16 22 8 20-7 31-1 20-23 22H47q-25-1-25-21-12-10 0-22z', '#eaa6aa')
    b += p('M64 43Q50 28 43 40q-1 10 15 16m36-12q11-17 20-8 5 11-13 18', '#edbcab')
    b += p('M58 53q1-17 23-17 25 0 26 25l-1 18q-3 22-25 22-24-1-25-23z', '#fff0d5')
    b += p('M69 36q-17-14-24-2-6 11 6 17 12 4 13-6 0-6-5-5', '#d2ae85', width=3)
    b += bead(74, 67) + bead(92, 67)
    b += p('M80 78q3 3 6 0m-3 2v4m-4-1q4 5 8 0', stroke='#916c62', width=1.8)
    b += blush(65, 76) + blush(101, 76)
    b += p('M32 56q2-4 5-2m-4 28q2-4 5-2', stroke='#cb888e', width=2)
    creatures['red_lamb_enemy'] = b

    # A round partridge with a small crest, folded wings and a sleepy wink.
    b = p('M46 103v8h8m23-8v8h8', stroke='#a58459', width=3)
    b += p('M31 81Q10 81 14 62q13 2 20 12', '#9bbdc3')
    b += p('M53 30q-11-18 0-21 12 0 13 19 5-17 14-12 7 6-3 17', '#dba9ba')
    b += p('M27 72Q25 35 61 29q35-7 43 27l4 28q0 26-37 26-42 1-44-38z', '#fff0d5')
    b += p('M39 70q-10 22 10 26 18-2 20-22-16 7-30-4z', '#a9c9ce')
    b += p('M97 61q20-2 16 7l-15 6', '#e8b471', width=2.8)
    b += bead(82, 56, 2.4, 3) + p('M64 56q-4-5-8 0', width=2.4)
    b += blush(77, 66, '#e7b2a4')
    b += e(80, 94, 2, 2.6, '#c3bab0', 'none') + e(88, 88, 1.8, 2.3, '#c3bab0', 'none')
    creatures['desert_bird_enemy'] = b

    # Broad cheeks, short forepaws and a floppy ear, rather than a pointed snout.
    b = p('M41 53Q22 14 36 10q14-2 21 40m14 1Q69 8 84 9q15 2 9 24l-6 19', '#f5ceaf')
    b += p('M38 20l10 26m35-26-3 23', stroke='#e7a4ac', width=5)
    b += e(25, 91, 10, 10, '#fff0d9')
    b += p('M29 77q-1-33 34-34 35-3 39 29 17 11 6 28-6 12-42 12-35 1-41-15-4-11 4-20z', '#f8d5b7')
    b += e(44, 104, 11, 6, '#eabb9d', width=2.5) + e(86, 104, 11, 6, '#eabb9d', width=2.5)
    b += bead(57, 72, 2.5, 3.2) + bead(79, 72, 2.5, 3.2)
    b += p('M65 81q3-3 6 0-1 4-3 4-3 0-3-4z', '#c58a8b', 'none')
    b += p('M68 85q-4 6-7 1m7-1q4 6 7 1', stroke='#a17a71', width=1.8)
    b += blush(46, 82, '#ecafb1', 5) + blush(91, 82, '#ecafb1', 5)
    b += p('M55 95v5m23-5v5', stroke='#c69984', width=2)
    creatures['sand_hare_enemy'] = b

    # Squat two-humped lavender camel: long neck retained, legs now soft nubs.
    b = p('M31 88v16q0 9 10 8l4-20m25 0 2 15q5 9 13 2l1-19', '#bda0c8')
    b += p('M26 76q-16 1-14-12', stroke='#a992b4', width=5)
    b += p('M23 70q-4-19 8-30 13-11 22 9 12-28 27-17 7 6 9 18l1-20q1-15 14-15 15 0 14 21l-1 44q-2 22-32 22H48Q21 102 23 70z', '#c8afd6')
    b += p('M92 23q-12-13-3-15 10 2 12 15m12-1q1-13 9-10 6 7-6 15', '#d6b9d8')
    b += p('M91 25q2-14 17-12 17 1 17 19-1 16-17 18-20 0-17-25z', '#d9bedb')
    b += e(113, 38, 11, 8, '#f5dfda', width=2.5)
    b += p('M99 29q4-5 8 0', width=2.2) + bead(119, 27, 2, 2.4)
    b += p('M112 40q4 4 8 0', stroke='#ac8595', width=1.8)
    b += blush(97, 37, '#e2a6b5', 3.5)
    b += p('M34 51q2-7 6-5m26-5q3-5 6 0', stroke='#e4d1e8', width=3)
    creatures['camel_enemy'] = b

    # Short pill-like insect legs. Each beetle has its own outline and expression.
    def bug_feet(color):
        result = ''
        for x, y, dx in [(34, 65, -12), (32, 84, -11), (41, 100, -8), (94, 65, 12), (96, 84, 11), (87, 100, 8)]:
            result += p(f'M{x} {y}q{dx} -3 {dx} 6', stroke=color, width=6)
        return result

    b = bug_feet('#6d977d')
    b += p('M47 42Q27 22 40 17q13 0 15 22m20 0q1-20 14-20 11 6-6 24', '#b2d1a6')
    b += e(64, 78, 37, 34, '#a0c994')
    b += p('M64 66v43m-26-29q7 9 14 10m38-10q-7 9-14 10', stroke='#7aab7d', width=2.5)
    b += p('M37 53q-2-23 27-25 29 0 27 26-3 17-27 18-25-1-27-19z', '#c5e1ad')
    b += bead(53, 51) + bead(75, 51) + p('M60 61q4 3 8 0', stroke='#7b9570', width=1.8)
    b += blush(44, 59, '#e7bea3', 3.5) + blush(84, 59, '#e7bea3', 3.5)
    for x, y in [(39, 82), (89, 82), (46, 101), (82, 101)]:
        b += p(f'M{x} {y}l-2-3m2 3 3-2', stroke='#f5e9be', width=2)
    b += e(64, 27, 6, 5, '#e8b4be', width=2)
    creatures['cactus_beetle_enemy'] = b

    b = bug_feet('#819aa8')
    b += p('M50 38Q37 19 43 13m35 24q13-20 7-24', stroke='#93b7a9', width=3)
    b += p('M44 25q-16-1-13-12 13-4 13 12m40 1q1-16 13-14 5 11-13 14', '#b7d2b4', width=2.5)
    b += e(64, 80, 38, 32, '#a6cddd')
    b += p('M64 65v42m-28-27q14 6 28 0 14 6 28 0', stroke='#7ca8be', width=2.5)
    b += e(64, 47, 27, 22, '#c1dfe8')
    b += p('M49 49q4 5 8 0m14 0q4 5 8 0', width=2.4)
    b += e(64, 57, 2.3, 2, '#7c9aac', 'none')
    b += blush(43, 55, '#d7b1ba', 3.5) + blush(85, 55, '#d7b1ba', 3.5)
    creatures['sand_scarab_enemy'] = b

    # Golden thief tucks its head into a broad shell; its eyes glance sideways.
    b = bug_feet('#b49a6c')
    b += p('M47 37q-10-11-5-17m35 17q10-11 5-17', stroke='#ad9369', width=3)
    b += e(64, 79, 38, 34, '#ebcc83')
    b += p('M64 65v43m-25-29 25 8 25-8', stroke='#c5a35f', width=2.5)
    b += p('M36 48q-2-19 18-21h20q21 1 19 22 0 22-29 22-28 0-28-23z', '#f4dba0')
    b += bead(54, 46, 2.5, 2.6) + bead(77, 46, 2.5, 2.6)
    b += p('M59 57q6 5 13-1', width=1.8)
    b += blush(44, 55, '#dfb29a', 3) + blush(85, 55, '#dfb29a', 3)
    b += p('M49 62q-7 1-6 7m35-7q7 1 6 7', stroke='#bb9762', width=3)
    creatures['stealing_scarab'] = b

    # Broad cloud-shaped wings, short fuzzy body and soft curled antennae.
    b = p('M57 59Q34 23 20 28q-17 6-8 26-12 17-1 28 4 14 22 11 13 1 26-17m12-17q23-36 37-31 17 6 8 26 12 17 1 28-4 14-22 11-13 1-26-17', '#f2d891')
    b += e(29, 68, 13, 15, '#d6aec2', 'none') + e(99, 68, 13, 15, '#d6aec2', 'none')
    b += e(29, 68, 6, 8, '#f8e7bb', 'none') + e(99, 68, 6, 8, '#f8e7bb', 'none')
    b += e(64, 83, 12, 25, '#e7bdab')
    b += p('M57 86h14m-12 11h10', stroke='#f8debf', width=3)
    b += p('M56 35q-9-21-18-14-4 6 3 8m31 6q9-21 18-14 4 6-3 8', stroke='#a18a76', width=2.5)
    b += p('M44 51q-5-12 5-18 6-7 15-2 12-6 19 4 9 10 1 20 2 12-10 13-11 5-17-3-14 0-13-14z', '#fff0ce')
    b += bead(56, 49, 2.4, 3.5) + bead(73, 49, 2.4, 3.5)
    b += p('M61 58q3 3 6 0', stroke='#ab8680', width=1.8)
    b += blush(48, 57, '#e6b3ad', 3.5) + blush(81, 57, '#e6b3ad', 3.5)
    creatures['sun_moth_enemy'] = b

    # A dozy turnip with a lopsided leaf tuft and tiny root feet.
    b = p('M51 47Q24 43 26 23q22-2 29 17Q47 9 66 12q17 7 8 30 16-24 29-14-3 19-24 21', '#a4c78b')
    b += p('M38 89q-14 4-16-5m66 5q14 4 16-5', stroke='#acb679', width=6)
    b += p('M50 100q-6 13 2 13m25-13q6 13-2 13', stroke='#afa16f', width=4)
    b += p('M28 72q-1-29 35-29 37 0 37 31-1 32-35 33-37-1-37-35z', '#dfd696')
    b += p('M45 72q4 4 8 0m21 0q4 4 8 0', width=2.4)
    b += e(64, 82, 2.5, 2.8, '#a59567', 'none')
    b += blush(38, 80, '#e2b8a0', 4) + blush(90, 80, '#e2b8a0', 4)
    b += p('M39 55l-3 4m53-3 3 4', stroke='#b9b076', width=2)
    creatures['thorn_splitter_enemy'] = b

    # Little stone guardian wearing its blossom, rather than a faceless rock.
    b = e(42, 104, 12, 7, '#8eaeb0', width=2.5) + e(84, 104, 12, 7, '#8eaeb0', width=2.5)
    b += p('M25 80q-1-30 18-43 22-13 42 1 18 12 18 42 0 30-39 31-39 0-39-31z', '#b2cecd')
    b += p('M30 84q-14 4-11 14m78-14q14 4 11 14', stroke='#8faeb0', width=6)
    b += p('M42 78h9m26 0h9', width=2.4)
    b += p('M60 87q4 3 8 0', stroke='#7c9b9b', width=1.8)
    b += blush(35, 85, '#c6b9b0', 4) + blush(94, 85, '#c6b9b0', 4)
    for x, y in [(58, 26), (78, 25), (87, 43), (68, 53), (49, 43)]:
        b += e(x, y, 11, 12, '#f4d694', width=2.3)
    b += e(68, 38, 10, 10, '#ddb376', width=2.3)
    creatures['sun_guardian_enemy'] = b

    # Big dumpling face, tiny fang and curled body: mischievous, not a dark throat.
    b = p('M30 93Q2 85 10 55 0 28 24 17q23-17 52-6 23-3 35 20 16 31-11 46L78 61q18-8 7-23-14-14-27-1-8 8-1 19z', '#e3bd8b', width=3.5)
    b += p('M20 32l13 12m7-27 8 18m20-20-1 18m25-8-11 16m23 5-19 6', stroke='#c6a270', width=2.5)
    b += p('M27 72q-4-30 36-31 41-2 44 31 16 31-17 39-36 10-61-7-13-12-2-32z', '#f5dba3')
    b += bead(50, 72, 3.1, 3.7) + bead(82, 72, 3.1, 3.7)
    b += p('M46 61q4-3 7-1m27-1 7 1', stroke='#bf9d70', width=2)
    b += blush(38, 84, '#e6b2a1', 6) + blush(94, 84, '#e6b2a1', 6)
    b += p('M56 86q11 4 23 0 0 13-12 13-11-1-11-13z', '#b98472', width=2.3)
    b += p('M70 89l1 6 5-6', '#fff1cd', 'none')
    creatures['sandworm_boss'] = b

    # Plush lobster-like mittens and a spiral tail, no long needle legs.
    b = p('M69 67Q45 51 54 25 61 5 86 10q27 3 25 26-1 15-19 15l-8-12q15 0 13-10-3-11-15-6-11 4-7 20', '#d2a3bb', width=3.5)
    b += p('M59 28l11 5m6-18 2 10m21-7-7 9', stroke='#b787a1', width=2.3)
    b += p('M90 42q5-5 12 0-1 9-8 13-8-4-4-13z', '#e6b2bf', width=2.5)
    for x, y in [(42, 80), (42, 94), (49, 105)]:
        b += p(f'M{x} {y}q-13-2-15 6M{128-x} {y}q13-2 15 6', stroke='#b18a9d', width=6)
    b += e(64, 87, 28, 27, '#ebbdcb')
    b += p('M45 93q18 8 38 0m-32 11q12 5 26 0', stroke='#d09db5', width=2.3)
    b += p('M43 80 27 70m58 10 16-10', stroke='#bf93ad', width=8)
    b += p('M31 58Q18 46 9 58 0 72 12 83q14 9 25-3l1-9-10-5-2 9-7-4 8-5', '#e0a5bd', width=3.2)
    b += p('M97 58q13-12 22 0 9 14-3 25-14 9-25-3l-1-9 10-5 2 9 7-4-8-5', '#e0a5bd', width=3.2)
    b += e(64, 65, 25, 21, '#f1ccda')
    b += bead(54, 64, 2.4, 3) + bead(74, 64, 2.4, 3)
    b += p('M61 73q3 4 6 0', stroke='#ab778c', width=1.8)
    b += blush(45, 72, '#df9cb3', 3.5) + blush(83, 72, '#df9cb3', 3.5)
    creatures['scorpion_boss'] = b

    # A fluffy little vulture with an oversized ruff and short scalloped wings.
    b = p('M48 73Q25 75 10 51q-7-12 0-14 7-2 16 12-8-24 1-24 8 1 14 27-1-18 7-15l11 23m20 13q23 2 38-22 7-12 0-14-7-2-16 12 8-24-1-24-8 1-14 27 1-18-7-15L68 60', '#b2cad9')
    b += e(64, 86, 30, 27, '#baa8ce')
    b += e(64, 93, 17, 15, '#d8cbe0', 'none')
    b += p('M48 107l-2 8h9m24-8 2 8h-9', stroke='#b39472', width=3.5)
    b += p('M54 65q-13-8-4-18 13-1 12-10-4-25 18-25 25 2 22 24-2 18-20 17l-2 13', '#f3d7bf')
    b += p('M44 63q-10-6-13 4-2 9 11 12 3 13 16 6 10 13 22 3 15 5 17-8 13-3 7-14-5-9-15-2-5-7-12-2-9-5-15 1-10-8-18 0z', '#fff0d4', width=3)
    b += p('M94 32q23 0 19 13-3 7-10 7l3-8-14-3', '#e5be84', width=2.8)
    b += bead(83, 32, 2.6, 3.2) + p('M72 27q-4-4-7 0', width=2)
    b += blush(80, 42, '#e7b3ac', 4)
    b += p('M65 16q-8-10-5-12 7 1 13 9', '#d7bda9', width=2.5)
    creatures['vulture_boss'] = b

    # Two short muzzles and a pillowy belly. Native UP facing is a gameplay
    # contract: rear weak point and rotating attacks rely on this orientation.
    b = p('M85 113q40 13 42-10 11 29-25 34l-19-10', '#a1c9ac')
    b += p('M47 81Q21 68 13 85q-3 11 15 14l22-8m49-10q26-13 34 4 3 11-15 14l-22-8M50 111q-21 3-24 18-4 12 12 9l22-18m36-9q21 3 24 18 4 12-12 9l-22-18', '#a8cdb4')
    b += p('M63 123q-8 23 11 29 19 5 28-9-17 5-20-17', '#a8cdb4')
    b += e(75, 99, 36, 33, '#c4debd')
    b += p('M53 84q11-8 22-3 12-5 22 3', stroke='#a1c79e', width=2.5)
    b += e(75, 108, 19, 18, '#e3ebc7', 'none')
    b += p('M54 87Q30 76 30 52l25-2q-3 19 12 29m28 8q24-11 25-35l-25-2q3 19-12 29', '#c4debd')
    b += p('M24 35Q20 12 44 11q26 0 27 24l-1 17q-2 23-24 22-25 0-24-22z', '#d2e5bc')
    b += p('M82 34q0-24 24-24 26 1 26 25l-1 17q-2 22-24 22-25 0-25-22z', '#bdddd0')
    b += p('M25 45q20-8 44 0m16 0q20-8 43 0', stroke='#aec996', width=2)
    b += bead(34, 42, 2.7, 3.2) + bead(59, 42, 2.7, 3.2)
    b += p('M93 42q3 4 7 0m15 0q3 4 7 0', width=2.3)
    b += e(40, 26, 1.4, 1.7, '#a7bc8f', 'none') + e(53, 26, 1.4, 1.7, '#a7bc8f', 'none')
    b += e(101, 25, 1.4, 1.7, '#96bcaa', 'none') + e(114, 25, 1.4, 1.7, '#96bcaa', 'none')
    b += p('M42 57q5 4 10 0m51 0q5 4 10 0', stroke='#819e7b', width=2)
    b += blush(29, 53, '#e0b7a6', 4) + blush(64, 53, '#e0b7a6', 4)
    b += blush(89, 53, '#dfb8b2', 4) + blush(125, 53, '#dfb8b2', 4)
    b += p('M15 89h8m104 0h8M29 132h8m76 0h8', stroke='#e0ebc8', width=2.5)
    svg('Generated/Enemy/monitor_boss.svg', b, sizes.get('monitor_boss', (300, 320)), (150, 160))
    for name, body in creatures.items():
        svg(f'Generated/Enemy/{name}.svg', body, sizes.get(name, (128, 128)))
    return len(creatures) + 1


if __name__ == '__main__':
    from generate_cohesive_art import ART, svg, path, ellipse, rect, group
    print(f'Generated {generate(ART, svg, path, ellipse, rect, group)} rounded desert creatures.')
