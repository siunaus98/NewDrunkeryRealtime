"""Separate solid silhouettes from ground decoration; SVGs rasterize on import."""
from generate_cohesive_art import svg, path as p, ellipse as e


def generate():
    # A substantial upright boulder: broad filled lower body covers the radius
    # used by the map collider. Only the soft lower-right shadow extends past it.
    b = e(69, 143, 54, 13, '#857962', 'none').replace('fill="#857962"', 'fill="#857962" opacity=".24"')
    b += p('M13 101Q9 79 19 59L32 24Q39 12 58 11l28 6q17 4 21 26l11 51q5 30-12 43-18 17-47 14-26 0-41-16-9-13-5-34z', '#a49a9a', '#685b5c', 4)
    b += p('M19 66l17-40q4-9 22-9l28 6 13 32-30 28-46-2z', '#c9bdb0', 'none')
    b += p('M70 83l31-28 12 43q4 27-13 36-16 12-36 10z', '#8f8690', 'none')
    b += p('M35 29l24-7m-36 63 39 2 7 22m0-26 29-25', 'none', '#786b71', 2.6)
    b += p('M28 116q6 17 24 19', 'none', '#c1b3a6', 3)
    svg('Environment/solid_boulder.svg', b, (256, 320), (128, 160))

    # A thick, rooted cactus cluster. The broad front barrel makes the footprint
    # legible; rounded caps and small flowers fit the friendly desert cast.
    b = e(68, 143, 55, 13, '#857962', 'none').replace('fill="#857962"', 'fill="#857962" opacity=".24"')
    b += p('M22 126Q11 116 11 89V67q0-17 13-17 14 0 14 17v14h6V34q0-23 19-23 20 0 20 23v39h7V54q0-18 13-18 14 0 14 18v42q0 28-17 32z', '#82b78c', '#566f5b', 3.6)
    b += p('M63 21v78M23 59v35m80-49v41', 'none', '#b7d49b', 3)
    b += p('M30 100q0-27 31-28 35 0 39 29l3 18q0 28-36 30-39 0-40-28z', '#75a888', '#566f5b', 3.6)
    b += p('M48 84q-12 34 0 55m36-54q10 31-1 53m-18-57v61', 'none', '#a4c59a', 2.5)
    for x, y in [(24, 76), (58, 35), (73, 60), (103, 64), (38, 111), (67, 96), (90, 122)]:
        b += p(f'M{x} {y}l-3-4m3 4 4-2', 'none', '#ede3b7', 2.2)
    b += p('M57 13q-8-9-1-11 6-1 8 8 4-9 10-4 4 5-4 10z', '#e9b2bd', '#916e78', 2)
    b += e(64, 12, 3, 3, '#f4d788', 'none')
    svg('Environment/solid_cactus.svg', b, (256, 320), (128, 160))

    # Gravel is embedded and low contrast, with no upright wall or dark outline.
    b = e(62, 37, 53, 16, '#d1b486', 'none')
    b += p('M10 39q3-10 17-11l10 4q9 9-6 14-16 4-21-7z', '#b9a58c', 'none')
    b += p('M44 22q4-9 15-8l9 4q6 9-7 13-14 3-17-9z', '#c6b59c', 'none')
    b += p('M70 39q5-12 23-11 16 4 15 12-10 8-30 6z', '#b5a08b', 'none')
    b += p('M17 36l12-3m49 2 15-2', 'none', '#d9c59f', 2)
    svg('Environment/ground_gravel.svg', b, (256, 128), (128, 64))

    # Low paddle-like seedlings, not a miniature solid cactus with raised arms.
    b = e(64, 50, 46, 10, '#c7b18a', 'none')
    b += p('M58 48Q20 51 22 36q14-13 36 12z', '#9fbb8d', 'none')
    b += p('M65 48q13-30 30-19 4 16-30 19z', '#b2c79a', 'none')
    b += p('M60 46q-23-21-8-31 17 2 8 31z', '#95b484', 'none')
    b += p('M59 48l-6-21m9 21 23-11', 'none', '#c8d3a1', 2)
    svg('Environment/ground_cactus.svg', b, (256, 144), (128, 72))
    print('Generated 2 solid props and 2 ground decorations.')


if __name__ == '__main__':
    generate()
