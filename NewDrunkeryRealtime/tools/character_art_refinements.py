"""Approved flat character refinements; offline SVG generation only.

Use --only merchant or --only red_lamb for a narrow update.
"""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

INK = '#59473f'

def p(d,fill='none',stroke=INK,w=2.4):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'

def e(x,y,rx,ry,fill,stroke='none',w=2.4):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>'

def svg(body,w,h):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'


def red_lamb_body():
    ram = '<ns0:path xmlns:ns0="http://www.w3.org/2000/svg" d="M35 94v13q6 7 13 0V94m32 0v13q6 7 13 0V94" fill="#ba8181" stroke="#69534e" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round" /><ns0:ellipse xmlns:ns0="http://www.w3.org/2000/svg" cx="23" cy="77" rx="10" ry="9" fill="#f1c4b8" stroke="#69534e" stroke-width="3.2" /><ns0:path xmlns:ns0="http://www.w3.org/2000/svg" d="M22 62q-8-18 10-24-1-17 19-17 12-14 27-3 20-7 27 12 17 4 16 22 8 20-7 31-1 20-23 22H47q-25-1-25-21-12-10 0-22z" fill="#eaa6aa" stroke="#69534e" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round" />'
    ram += p('M24 84Q34 98 48 94 64 106 78 95 97 98 112 84L111 91Q108 105 91 105H47Q29 104 24 94Z','#d38d99','none')
    # Large wool masses; just three interior marks, not texture scribbles.
    ram += p('M28 48Q33 42 41 44M40 28Q49 24 57 28M29 76Q34 80 39 77',stroke='#f4c8c4',w=2)
    ram += p('M40 91Q45 95 51 91M25 61Q30 55 35 59',stroke='#be7e8d',w=1.7)
    # Ears are tucked into the fleece, broad bases and pointed folds.
    ram += p('M66 48Q53 34 45 40 48 52 63 56Z','#ebbcaa',w=2.5)
    ram += p('M94 47Q107 32 115 38 115 49 102 54Z','#ebbcaa',w=2.5)
    ram += p('M50 43L61 50M110 40L101 48',stroke='#bf8b84',w=1.5)
    # Far horn is smaller for a three-quarter head, with a single inner curl.
    ram += p('M96 40Q108 42 113 34 119 24 110 19 101 14 95 22 90 30 96 40Z','#d4b389',w=2.6)
    ram += p('M99 36Q109 38 110 29 110 23 104 23 99 23 100 28L104 30',stroke='#a78866',w=1.8)
    # Original broad face outline retained, with an inset shadow for volume.
    ram += p('M58 53q1-17 23-17 25 0 26 25l-1 18q-3 22-25 22-24-1-25-23z','#fff0d5',w=3)
    ram += p('M101 47Q107 54 106 68L105 79Q102 97 86 100L77 99Q97 95 98 78L99 56Z','#e8cfb0','none')
    # Forelock and horn overlap hide the join without human eyebrows or hair.
    ram += p('M60 49Q58 39 68 40 72 33 80 38 90 32 96 40 105 40 102 49L94 52 85 47 77 52 68 48Z','#eaa6aa',w=2.1)
    # Ordinary enemy: open oval eyes, slightly wandering gaze, soft animal mouth.
    ram += e(72, 66, 3.5, 4.8, '#594742')
    ram += e(94, 66, 3.5, 4.8, '#594742')
    ram += e(71.1, 64.2, .9, 1.1, '#fff0d5')
    ram += e(93.1, 64.2, .9, 1.1, '#fff0d5')
    ram += p('M79 78Q83 76 87 78L83 82Z', '#b28b79', 'none')
    ram += p('M83 82V85M83 85Q80 89 77 86M83 85Q86 89 89 86', stroke='#9a7868', w=1.6)
    # Front curl flows as one broad connected mass. Keep the sheep horn identity.
    ram += p('M68 44Q54 49 46 39 38 28 48 20 58 12 68 21 78 30 70 39L65 41Z','#d2ae85',w=2.8)
    ram += p('M65 39Q55 43 49 35 43 27 51 23 59 18 65 26 69 32 62 34 57 35 55 30',stroke='#a28161',w=1.8)
    ram += p('M46 26L50 28M47 38L51 35M59 17L58 22',stroke='#b28e67',w=1.2)
    
    return ram

def merchant_body():
    m=e(60,133,42,7,'#513420',w=0)
    m='<g opacity=".16">'+m+'</g>'
    # Torso and sleeves use broad masses; chest still anchors hands and silhouette.
    m+=p('M30 78Q39 68 48 68H75Q87 68 95 80L101 119 83 131H35L20 116Z','#486f79',w=3)
    m+=p('M31 91L26 114 40 122M87 91L94 114 81 123',stroke='#355963',w=2.5)
    m+=p('M47 68L60 86 75 67 80 120H42Z','#cba25d',w=2.5)
    m+=p('M36 77L45 92 52 87 60 104 69 87 77 92 86 76',stroke='#ddcd9c',w=2)
    m+=p('M50 70L60 81 71 70 69 62H51Z','#dca87e',w=2)
    # Ears sit at the face sides and remain clearly separate from hair.
    m+=e(33,45,5,8,'#e4b489',INK,2.2)+e(88,45,5,8,'#e4b489',INK,2.2)
    # Broad jaw, soft geometric cheek, slight asymmetry only in the expression.
    m+=p('M34 28Q42 15 60 15 80 15 88 28L86 49Q83 65 69 73H53Q38 66 35 51Z','#e4b489',w=3)
    m+=p('M81 29L87 30 84 50Q80 64 68 69H60Q77 61 79 46Z','#ce986f','none')
    # Hair uses clean locks, avoiding the zigzag sheet from earlier revisions.
    m+=p('M33 36L31 26Q41 13 60 14 80 13 90 26L88 39 83 44 81 28 70 32 62 27 49 33 43 29 39 43Z','#4e4146',w=2.2)
    # Two angular eyebrows and large simple ink eyes. Small cutouts carry gaze.
    m+=p('M41 38Q49 34 56 38M67 36Q75 31 83 35',stroke='#59473f',w=2.6)
    m+=p('M41 43L56 45 54 53Q48 56 43 52Z','#4e4146','none')
    m+=p('M66 44L81 40 80 50Q74 55 68 52Z','#4e4146','none')
    m+=p('M44 44L53 46M69 45L78 43',stroke='#f8dfb4',w=1.8)
    # Mustache and beard are a single compact graphic framing a small wry mouth.
    m+=p('M42 57L49 61 57 58 62 61 70 57 81 54 78 64 69 73H55L45 66Z','#725047',w=1.8)
    m+=p('M52 62Q62 67 72 60',stroke='#f1cb98',w=1.7)
    # Slouch hat is recognizable from the source, with a balanced arched brim.
    m+=p('M36 25Q38 8 60 9 80 7 85 25L95 31 95 37Q60 26 25 38L25 32Z','#728a88',w=3)
    m+=p('M37 23Q59 11 81 22',stroke='#e1bf75',w=2.7)
    m+=p('M29 31Q61 20 91 31',stroke='#a8b8a3',w=1.4)
    # Front satchel straps are visible but restrained, with one large clasp.
    m+=p('M36 78L47 95M84 78L73 95',stroke='#cba25d',w=5)
    m+=p('M36 78L47 95M84 78L73 95',stroke='#ecd49d',w=1.4)
    # Chest and hands stay close to original proportions; no new standing body.
    m+=p('M21 104H99L93 134H27Z','#8f6547',w=3)
    m+=p('M25 109H95L92 119H28Z','#b38a5c',w=2)
    m+=p('M33 106V131M84 106V131',stroke='#d5b67a',w=2.2)
    m+=p('M36 84Q31 83 27 89L19 94 25 103 37 98 42 91Z','#e4b489',w=2.5)
    m+=p('M85 84Q91 83 96 89L104 94 98 103 85 98 80 91Z','#e4b489',w=2.5)
    m+=p('M24 94L30 97M96 94L91 97',stroke='#b48264',w=1.3)
    m+=e(60,119,8,8,'#e2bf65',INK,2)
    m+=p('M60 114V124M55 119H65',stroke='#806042',w=1.7)
    
    return m

ART = Path(__file__).resolve().parents[1] / 'ArtResource'
STYLE = 'character-refinement-v1'

def document(body, width, height, view=None):
    view = view or (width, height)
    root = ET.fromstring(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {view[0]} {view[1]}" data-art-direction="{STYLE}">{body}</svg>')
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    for node in root.iter():
        for attribute in ('fill', 'stroke'):
            color = node.get(attribute, '')
            if color.startswith('#') and len(color) == 9:
                node.set(attribute, color[:7])
                node.set(attribute + '-opacity', str(int(color[7:], 16) / 255))
    # Godot's SVG importer requires a default namespace, without ns0 prefixes.
    return ET.tostring(root, encoding='unicode') + '\n'

def generate(only='all'):
    if only == 'all':
        from character_cast_refinements import generate as generate_cast
        generate_cast()
        return
    if only in ('all', 'red_lamb'):
        (ART/'Generated/Enemy/red_lamb_enemy.svg').write_text(document(red_lamb_body(), 128, 128), encoding='utf-8')
    if only in ('all', 'merchant'):
        body = merchant_body()
        (ART/'Events/merchant.svg').write_text(document(body, 120, 144), encoding='utf-8')
        world = '<g transform="translate(8 12) scale(2)">' + body + '</g>'
        (ART/'Restaurant/salesperson.svg').write_text(document(world, 256, 320), encoding='utf-8')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', choices=['all', 'merchant', 'red_lamb'], default='all')
    generate(parser.parse_args().only)
