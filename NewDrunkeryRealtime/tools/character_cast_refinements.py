"""Flat desert cast: species silhouettes, expressive faces and restrained detail.

Offline generation only; no sizes, collisions or gameplay values are changed.
The approved merchant and lamb are owned by character_art_refinements.py.
"""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET
from character_art_refinements import p, e, document, merchant_body, red_lamb_body
from character_cast_shapes import SHAPES

ART = Path(__file__).resolve().parents[1] / 'ArtResource'
INK = '#59473f'


def eye(x, y, rx=3.3, ry=4.4, color=INK):
    return e(x, y, rx, ry, color) + e(x-.9, y-1.6, .85, 1, '#fff0d5')


def creature_eye(x, y, rx=6, ry=7, dx=0, dy=1):
    # The large white and small pupil carry ordinary-enemy expressions.
    return (e(x,y,rx,ry,'#fff7e7',INK,1.4)
            + e(x+dx,y+dy,1.9,2.4,INK))


def sleepy(x, y, width=9, color=INK):
    return p(f'M{x} {y}q{width/2} 4 {width} 0', stroke=color, w=2.2)


def stern(x, y, width=13, flip=False, color=INK):
    slope = -3 if flip else 3
    return (p(f'M{x} {y}l{width} {slope} -1 8q-6 4 -11 0Z', color, 'none')
            + p(f'M{x+2} {y+2}l{width-5} {slope*.6}', stroke='#f8dfb4', w=1.5))


def chest():
    return (p('M18 96H102L98 135H22Z','#805849',w=3)
            + p('M22 104H98V124H22Z','#b48b5b',w=2)
            + p('M31 98V132M89 98V132',stroke='#e0be80',w=2.3)
            + e(60,117,8,8,'#dfbb67',INK,2)
            + p('M60 113V121M56 117H64',stroke='#7c5b43',w=1.7))


def npc_bodies():
    result = {'merchant': merchant_body()}
    # Patient stonecutter: heavy stone, squared apron and a concentrated gaze.
    b = e(60,134,41,6,'#59473f22')
    b += p('M34 77Q61 64 87 78L101 130H21Z','#698e88',w=3)
    b += p('M42 78L46 126H82L79 78 66 87 56 80Z','#d5b17a',w=2.4)
    b += p('M43 81L48 99M77 81L73 98M48 116H74',stroke='#eed3a0',w=1.8)
    b += p('M38 31Q41 15 62 15 85 17 86 37L81 61 69 73H54L41 61Z','#edc58f',w=2.8)
    b += p('M79 34L85 38 80 61 67 70 59 68Q77 57 79 34Z','#d0a379','none')
    b += p('M36 37L34 25 43 13 77 15 89 30 86 39Q61 31 36 37Z','#b5a380',w=2.8)
    b += p('M42 24L79 26M43 16L48 24',stroke='#e0d3ad',w=1.7)
    b += p('M42 58L54 63 62 60 70 63 80 57 77 71 64 80 50 74Z','#e9dec0',w=2)
    b += p('M45 46H55M68 46H78',stroke=INK,w=2.6)
    b += e(51,50,2.4,3.2,INK)+e(73,50,2.4,3.2,INK)
    b += p('M57 66H67',stroke='#a68d70',w=1.5)
    b += p('M18 91L65 87 72 128 18 132Z','#beb59b',w=3)
    b += p('M23 97L61 94M28 104H55M28 113H49M28 122H55',stroke='#867f6d',w=2)
    b += p('M84 84L71 112',stroke='#755843',w=5)
    b += p('M73 109L69 119 77 114Z','#c8cfbc',w=1.5)
    b += p('M81 91Q85 87 90 93L85 102 78 98Z','#edc58f',w=2)
    result['engraver'] = b
    # Porcelain host: composed face, glazed mask, bobbed hair and ceramic cracks.
    b = e(60,134,40,6,'#59473f22')
    b += p('M32 80Q60 68 88 80L101 130H20Z','#548b9a',w=3)
    b += p('M44 79L60 94 77 79 84 127H36Z','#f0e3c5',w=2.3)
    b += p('M43 88L51 96 45 104M78 88L70 96 76 104M29 120L34 123M86 123L93 120',stroke='#bed8cd',w=2)
    b += p('M28 49Q25 11 60 12 96 12 94 49L90 78 77 84H39L29 74Z','#604951',w=3)
    b += p('M35 39Q37 23 61 23 83 23 86 42L82 62Q73 76 61 78 46 76 37 62Z','#f3dfb6',w=2.3)
    b += p('M80 41L85 42 81 62Q73 74 61 76L55 73Q76 67 80 41Z','#dbc6a3','none')
    b += p('M33 42L40 22 61 17 85 29 89 43Q70 43 55 31L48 43Z','#604951',w=2.4)
    b += p('M37 26L45 21M75 23L83 29',stroke='#9b7882',w=1.8)
    b += p('M44 49Q49 52 54 49M68 49Q73 52 78 49',stroke='#71534c',w=2.2)
    b += p('M56 65Q61 67 66 64M39 55L43 61 40 66',stroke='#a57969',w=1.4)
    b += p('M34 103L28 112 40 121M87 104L94 113 81 122',stroke='#edcfa7',w=7)
    b += e(60,113,32,16,'#f4e7c6',INK,2.7)+e(60,111,25,10,'#a8ccc6',INK,1.6)
    b += p('M43 110Q59 104 76 110',stroke='#eef3d7',w=2)
    result['porcelain'] = b
    # Gambler: one raised brow, easy grin, waistcoat and a large die.
    b = e(60,134,42,6,'#59473f22')
    b += p('M31 79Q60 67 90 79L102 131H19Z','#92705c',w=3)
    b += p('M45 77L61 98 77 77 83 129H39Z','#e6b56c',w=2.2)
    b += p('M45 84L49 101 42 106M78 84L73 101 80 106',stroke='#edd0a0',w=2)
    b += e(61,121,2,2,'#f7dfa3')
    b += p('M35 32Q39 16 61 16 83 16 88 33L85 54Q82 68 63 76 44 72 37 58Z','#dbad7e',w=2.8)
    b += p('M80 32L86 34 82 56Q75 71 63 74L55 70Q78 62 80 32Z','#c4916d','none')
    b += p('M33 38L31 25 43 13 78 15 91 31 85 44 80 31 68 36 57 30 44 39Z','#59473f',w=2.2)
    b += p('M27 32L40 11H79L96 33 92 38Q61 29 29 39Z','#6d716d',w=2.8)
    b += p('M36 27H86M43 17H76',stroke='#d5b77b',w=2)
    b += p('M43 43L55 42M68 40Q75 35 81 39',stroke=INK,w=2.4)
    b += sleepy(44,48,10)+eye(74,47,2.8,3.7)
    b += p('M48 60Q62 70 77 57L73 66Q59 73 48 60Z','#705047',w=1.3)
    b += p('M52 61Q63 65 73 60',stroke='#f8dfb4',w=2)
    b += p('M24 92L44 86 50 112 29 118Z','#eee0b8',w=2.4)
    b += p('M35 94L41 101 36 109 30 102Z','#a4564d','none')
    b += p('M80 91L99 98 95 120 75 114Z','#e9d9b6',w=2.7)
    for x,y in [(84,99),(91,109),(82,108)]: b+=e(x,y,1.8,1.8,'#775347')
    result['gambler'] = b
    # Repayment visitor: worried but earnest; plain round eyes and a held bag.
    b = e(60,134,40,6,'#59473f22')
    b += p('M34 79Q59 68 85 79L99 131H22Z','#588b83',w=3)
    b += p('M39 82L48 106 60 114 73 105 83 82M47 81L60 92 74 81',stroke='#d2dbb3',w=2)
    b += p('M36 32Q39 15 61 15 84 15 87 33L84 56Q77 74 61 77 44 72 38 58Z','#e9bd86',w=2.8)
    b += p('M81 34L85 36 82 57Q74 71 61 75L54 71Q77 62 81 34Z','#d1a073','none')
    b += p('M32 39Q29 14 60 11 88 10 91 37L81 44 76 29 64 35 56 27 44 38 42 46Z','#d2a655',w=2.5)
    b += p('M40 24Q57 15 77 23',stroke='#edd095',w=2)
    b += p('M44 44L54 41M70 41L80 44',stroke='#8e6f4f',w=2.2)
    b += eye(49,51,2.8,3.9)+eye(75,51,2.8,3.9)
    b += p('M54 64Q61 68 68 63',stroke='#a17458',w=1.8)
    b += p('M41 97L37 84 51 80 61 93Q87 105 80 131H35Q25 112 41 97Z','#c29860',w=2.7)
    b += p('M42 97L64 99M40 106Q52 101 65 106',stroke='#8f6c4a',w=1.8)
    b += e(53,117,9,9,'#e7c76e',INK,2)
    b += p('M52 112L56 117 52 122 48 117Z','#fff0af','none')
    b += p('M30 100L39 95 46 102 43 109 33 107M77 99L86 101 84 110 74 108', '#e9bd86',w=2)
    result['repayment'] = b
    # Fire keeper: bright core and a brisk surprised face, not a human baby.
    b = e(60,135,39,5,'#59473f22')
    b += p('M31 108Q18 88 29 64L40 46 43 65Q53 55 50 40 50 22 65 10 61 36 79 50 99 67 92 86L83 109Z','#e57e38',w=3)
    b += p('M40 107Q31 83 49 66L52 79Q64 69 64 52 84 74 79 104Z','#ffdc83','none')
    b += eye(49,84,3.3,4.8)+eye(70,84,3.3,4.8)
    b += e(60,96,3,4.2,'#a96437')
    b += p('M42 69L47 64M78 57L82 64',stroke='#ffe8ae',w=2)
    b += p('M22 108H98L89 133H31Z','#91704f',w=3)
    b += p('M28 115H92M39 117L43 128M81 117L77 128',stroke='#d5b77b',w=2)
    b += p('M18 86Q12 77 20 68M102 86Q109 76 101 70',stroke='#f2b45f',w=2)
    result['furnace'] = b
    # Box devil: curled horns and an inviting grin; distinct from a sly human.
    b = e(60,135,43,5,'#59473f22')
    b += p('M18 93L27 75H95L104 93Z','#a17150',w=3)
    b += p('M34 87Q23 69 32 49L28 26 49 37Q61 31 75 37L96 24 91 49Q101 69 86 89Z','#a94d63',w=3)
    b += p('M84 45L91 50Q98 70 83 87H71Q89 71 84 45Z','#87495d','none')
    b += p('M41 43Q23 33 29 19 34 12 42 18L40 26Q35 22 34 27 35 33 47 35Z','#e9c48d',w=2)
    b += p('M79 42Q97 32 91 18 86 12 79 18L81 26Q86 21 87 27 86 33 74 35Z','#e9c48d',w=2)
    b += p('M39 56Q47 49 54 56M68 56Q76 48 84 54',stroke='#ffe49d',w=3)
    b += p('M40 68Q61 84 84 66L78 85Q61 95 45 84Z','#503d48',w=2)
    b += p('M47 73L51 81 55 76M70 76L75 81 79 71','#fff0c5','none')
    b += chest()
    b += p('M31 91L20 101M88 91L100 101',stroke='#cb7990',w=6)
    result['devil'] = b
    # Masked trickster: theatre mask, asymmetric squint, playful angular cloak.
    b = e(60,136,36,5,'#59473f22')
    b += p('M36 59Q19 82 27 111L39 126 51 118 63 128 76 118 88 123Q104 92 85 58Z','#745b99',w=3)
    b += p('M80 72Q96 98 85 117L75 111 63 121 51 112 40 120 34 109Q55 119 68 96Z','#5c4b80','none')
    b += p('M29 57L23 27 46 37 61 10 77 37 100 26 91 57Z','#ac668d',w=3)
    b += p('M42 49L61 25 80 49Z','#dab780',w=2)
    b += p('M35 59Q61 43 88 59L81 87Q62 107 42 88Z','#d7b99a',w=2.7)
    b += p('M80 59L86 60 79 86Q69 97 59 98L54 93Q76 84 80 59Z','#c4a08a','none')
    b += p('M44 66L55 71 44 76',stroke='#684b74',w=2.5)
    b += p('M68 67L79 64 77 75Q71 79 68 74Z','#684b74','none')
    b += p('M48 82Q64 92 77 78',stroke='#744557',w=2.3)
    b += p('M29 79L11 62 16 53 31 62M91 79L107 60 112 67 100 94','#8f75b2',w=2.4)
    b += e(14,49,5.5,5.5,'#f1ce7e',INK,2)+e(106,49,5.5,5.5,'#b8d7c1',INK,2)
    b += p('M45 122L38 136M75 122L82 136',stroke='#be8a9e',w=4)
    b += p('M12 31L16 24 20 31 16 36ZM104 17L108 10 112 17 108 22Z','#e7c587','none')
    result['prankster'] = b
    # Sand spirit: unreadable glowing eyes, drifting sand folds; no cheek dots.
    b = e(60,130,34,6,'#dcb76855')
    b += p('M38 111Q18 83 29 51 39 21 60 13 85 20 95 52 106 84 80 111L75 129 61 121 48 132 41 118Z','#c19b59',w=2.8)
    b += p('M78 34Q96 61 89 85L75 111 68 119 61 115Q88 78 78 34Z','#a78751','none')
    b += p('M35 51Q60 25 86 50L78 83H45Z','#80663e',w=2.5)
    b += p('M40 45Q60 27 80 44',stroke='#ffe4a3',w=2)
    b += e(49,60,3.1,5,'#fff0ba')+e(73,60,3.1,5,'#fff0ba')
    b += p('M55 75H67',stroke='#e6cb88',w=1.8)
    b += p('M43 94L50 108 61 113 72 106 78 93M60 93V108',stroke='#f5df9f',w=2)
    b += p('M31 80L17 90 26 100M89 80L104 90 96 100M20 116Q8 111 12 100M100 116Q112 111 108 100',stroke='#e8c77e',w=2.8)
    b += p('M13 47L17 40 21 47 17 54ZM96 28L100 21 104 28 100 35Z','#f8e2a0','none')
    result['sand_spirit'] = b
    return result


def refine_enemy(name):
    from character_boss_anatomy import BOSSES
    if name in BOSSES:
        return BOSSES[name]()
    if name == 'red_lamb_enemy':
        return red_lamb_body()
    shapes = SHAPES[name]
    # Mildly stronger outer line; preserve the authored shape coordinates.
    b = ''.join(shapes)
    b = b.replace('stroke="#69534e"','stroke="#59473f"')
    if name == 'desert_bird_enemy':
        b = ''.join(shapes[:4]) + p('M29 83Q38 108 74 106 97 106 105 89L105 96Q96 111 71 110 38 110 29 90Z','#e5d6be','none') + ''.join(shapes[4:])
        b += p('M41 76Q47 91 55 87M45 77L52 82',stroke='#789aa5',w=1.7)
        b += eye(61,56,3,4)+eye(82,56,3,4)
        b += p('M99 65L109 65',stroke='#b38452',w=1.5)
    elif name == 'sand_hare_enemy':
        b = ''.join(shapes[:4])+p('M99 72Q113 84 106 98 101 107 86 109L69 110Q96 103 98 86Z','#e5b79d','none')+''.join(shapes[4:])
        b += creature_eye(55,71,6.4,7.6,1)+creature_eye(81,71,6.4,7.6,1)
        b += p('M64 82Q68 79 72 82L68 86Z','#bd8586','none')
        b += p('M68 86V90M68 90L64 92M68 90L72 92',stroke='#9b7165',w=1.5)
        b += p('M61 88L56 87M75 88L80 87',stroke='#c49a85',w=1.2)
    elif name == 'camel_enemy':
        b = ''.join(shapes[:3])+p('M26 80Q31 94 50 94H86Q105 93 114 80L111 91Q103 103 83 102H48Q29 101 26 90Z','#ae8fbe','none')+''.join(shapes[3:])
        b += creature_eye(101,28,4.4,5.2,0)+creature_eye(118,27,4.4,5.2,0)
        b += p('M110 39H114M119 38H121M111 44Q115 47 119 44',stroke='#ae8290',w=1.4)
        b += p('M36 62L40 75M64 58L68 73',stroke='#a386b2',w=1.7)
    elif name == 'cactus_beetle_enemy':
        b = ''.join(shapes[:8])+p('M88 63Q104 81 93 98 86 110 67 111L64 107Q90 99 90 77Z','#80ab83','none')+''.join(shapes[8:])
        b += eye(52,50,3.3,4.3)+eye(76,50,3.3,4.3)
        b += p('M45 76L49 83M79 76L75 83M47 94L51 99M81 94L77 99',stroke='#dce5ad',w=2)
    elif name == 'sand_scarab_enemy':
        b = ''.join(shapes[:9])+p('M93 65Q105 84 92 101 81 112 64 112V107Q90 98 89 78Z','#84acbf','none')+''.join(shapes[9:])
        b += p('M47 44H58M70 44H81',stroke='#678697',w=1.8)
        b += eye(52,50,2.6,3.4)+eye(76,50,2.6,3.4)
        b += p('M44 88Q50 91 55 89M73 89Q79 91 84 88',stroke='#cfe4db',w=1.8)
    elif name == 'stealing_scarab':
        b = ''.join(shapes[:8])+p('M95 68Q105 90 88 105L64 112V107Q89 97 90 77Z','#d0ae6d','none')+''.join(shapes[8:])
        b += creature_eye(52,47,6,7,-1.5)+creature_eye(77,47,6,7,-1.5)
        b += p('M43 80L53 88 64 80 75 88 85 80M48 97L64 104 80 97',stroke='#f8dfa4',w=1.7)
    elif name == 'sun_moth_enemy':
        b += p('M19 44Q33 48 43 61M15 79L29 83 46 75M109 44Q95 48 85 61M113 79L99 83 82 75',stroke='#caa789',w=1.7)
        b += eye(54,48,3.3,4.6)+eye(75,48,3.3,4.6)
        b += p('M58 76H70',stroke='#f8debf',w=2)
    elif name == 'thorn_splitter_enemy':
        b = ''.join(shapes[:4])+p('M93 58Q103 75 94 94 84 107 65 108L61 103Q86 97 88 79Z','#c2bc7c','none')+''.join(shapes[4:])
        b += sleepy(45,72,10)+sleepy(73,72,10)
        b += p('M42 59L46 65M85 57L81 64M48 94L52 98M81 94L77 98',stroke='#eee5af',w=1.7)
        b += p('M62 22L63 38M33 30L46 39M93 32L81 41',stroke='#779c70',w=1.6)
    elif name == 'sun_guardian_enemy':
        b = ''.join(shapes[:3])+p('M95 57Q108 84 98 102L82 109 63 111V105Q88 102 88 79Z','#91b3b2','none')+''.join(shapes[3:])
        b += creature_eye(47,79,6,6.5,0,1.8)+creature_eye(81,79,6,6.5,0,1.8)
        b += p('M32 66L41 63 46 69M91 65L85 71 92 77M41 100L47 96',stroke='#d6dfc1',w=1.7)
        b += e(68,38,4,4,'#f8e4af')
    return b.replace('stroke="#69534e"','stroke="#59473f"')


def enemy_bodies():
    return {name:refine_enemy(name) for name in ['red_lamb_enemy',*SHAPES]}


def goddess_body():
    # Calm carved figure, retaining the existing statue size and service bowl.
    b=e(80,207,57,9,'#51342022')
    b+=p('M32 194H128V211H32Z','#94785b',w=3)+p('M41 179H119V196H41Z','#c6ad7e',w=3)
    b+=p('M51 170L64 102H96L109 170Z','#d5d3b6',w=3)
    b+=p('M72 108L63 168H97L87 108Z','#f0e6c9',w=2)
    b+=p('M66 126L60 154M94 126L100 154M76 134V160',stroke='#acb4a2',w=1.8)
    b+=p('M61 99L45 78 34 85 48 115 69 123M99 99L115 78 126 85 112 115 91 123','#e7debf',w=3)
    b+=p('M50 67Q49 33 79 31 111 32 111 68L97 103H63Z','#abbcb0',w=3)
    b+=p('M58 59Q60 42 80 41 101 42 103 61L99 79 89 94H72L61 79Z','#f3e6c8',w=2.4)
    b+=p('M57 66Q60 42 80 40 99 41 105 65L92 49 80 59 68 50Z','#c7cfb8',w=2.2)
    b+=p('M68 68Q72 71 76 68M85 68Q89 71 93 68M76 82H85',stroke='#7d7967',w=1.7)
    b+=p('M62 97L80 110 98 97 91 120H69Z','#91b9b0',w=2.4)
    b+=p('M80 110V160',stroke='#d5bb79',w=2.8)
    b+=p('M47 111Q80 128 113 111L108 128Q80 142 52 128Z','#d3b476',w=2.5)
    b+=e(80,111,33,13,'#f1dfad',INK,2.4)
    b+=p('M61 109Q80 99 99 109',stroke='#a5c4b3',w=2)
    b+=p('M80 6L85 16 96 18 88 26 90 37 80 32 70 37 72 26 64 18 75 16Z','#f1cf7b',w=2)
    b+=p('M48 30L41 23M112 30L119 23M48 185H112M40 201H121',stroke='#d7b76e',w=2)
    return b


def generate(only='all'):
    if only in ('all','enemies'):
        for name,body in enemy_bodies().items():
            target=ART/'Generated/Enemy'/f'{name}.svg'
            source=ET.parse(target).getroot()
            width,height=int(source.get('width')),int(source.get('height'))
            view=(150,160) if name=='monitor_boss' else (128,128)
            target.write_text(document(body,width,height,view),encoding='utf-8')
    if only in ('all','npcs'):
        for name,body in npc_bodies().items():
            (ART/'Events'/f'{name}.svg').write_text(document(body,120,144),encoding='utf-8')
    if only in ('all','landmarks'):
        world='<g transform="translate(8 12) scale(2)">'+merchant_body()+'</g>'
        (ART/'Restaurant/salesperson.svg').write_text(document(world,256,320),encoding='utf-8')
        (ART/'Restaurant/goddess_statue.svg').write_text(document(goddess_body(),160,220),encoding='utf-8')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only',choices=['all','enemies','npcs','landmarks'],default='all')
    generate(parser.parse_args().only)
