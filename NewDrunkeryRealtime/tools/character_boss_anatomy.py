"""Animal-led boss silhouettes, without circular-body or mascot-face templates.

Sandworm and scorpion have no mouth. Native monitor facing remains UP.
Coordinates describe art only; combat shapes are tuned separately.
"""
from character_art_refinements import p, e

INK = '#59473f'


def sandworm():
    # Long, bent segmented trunk. The tapered rear curls back beneath the neck;
    # there is no face disc or humanoid torso.
    b = p('M34 105Q5 99 13 76 18 62 38 67L75 78Q94 81 98 66 100 51 80 44L50 37Q26 29 31 15 40 2 62 8 80 13 84 27L90 43Q119 51 115 76 111 107 80 108L38 95Q21 89 21 98Z', '#c89b68', w=3.3)
    b += p('M34 105Q11 98 18 82 24 76 40 80L80 94Q104 95 110 74L108 86Q97 112 76 107L37 95Q21 89 21 98Z', '#a77b57', 'none')
    # Transverse plates follow the bends, rather than radial decoration around
    # a round "head". The undercut gives the emerging body weight.
    for d in ['M19 72L20 89','M30 67L28 91','M43 69L39 94',
              'M57 73L52 98','M72 77L68 103','M87 77L87 106',
              'M97 67L115 70','M94 55L112 55','M78 44L88 29',
              'M63 41L71 17','M48 36L57 8','M35 29L43 10']:
        b += p(d, stroke='#8c6850', w=2.3)
    for d in ['M24 73L25 83','M47 74L44 82','M76 83L76 92','M102 59L108 61','M50 14L47 24']:
        b += p(d, stroke='#edc58d', w=1.7)
    # A low, armoured wedge at the forward end. Side eye slits are inset in the
    # plate; no lips, teeth, fangs, grin, jaw or anthropomorphic cheeks.
    b += p('M26 22L31 8 44 5 57 10 65 26 60 45 45 53 29 44 23 32Z', '#e0b97f', w=3)
    b += p('M45 10L56 17 60 30 55 44 45 49 39 43 46 31Z', '#c39361', 'none')
    for x,y in [(28,25),(29,30),(54,24),(55,29)]:
        b += e(x,y,1.4,1.8,'#6a5145')
    b += p('M35 14L40 18M49 15L46 21', stroke='#a47c55', w=1.7)
    # Short sensory spines, attached to the head plates rather than a crown.
    b += p('M26 18L20 11 22 26M59 16L65 9 65 25', '#c39361', w=2)
    return b


def scorpion():
    # Eight jointed legs splay from the thorax; no hands, mittens or upright pose.
    b = ''
    legs = [
        ('M49 63L32 55 19 66 11 72', 'M79 63L96 55 109 66 117 72'),
        ('M46 73L28 72 20 87 12 91', 'M82 73L100 72 108 87 116 91'),
        ('M47 84L31 91 30 106 23 113', 'M81 84L97 91 98 106 105 113'),
        ('M52 93L42 106 46 118', 'M76 93L86 106 82 118'),
    ]
    for left, right in legs:
        b += p(left, stroke=INK, w=6) + p(right, stroke=INK, w=6)
        b += p(left, stroke='#ac7795', w=3.1) + p(right, stroke='#ac7795', w=3.1)
    # Segmented abdomen, narrowed where it joins the raised tail.
    b += p('M45 67Q41 44 49 29L61 22 75 28Q87 44 83 69L75 87H53Z', '#c892b0', w=3)
    b += p('M72 29Q85 43 79 66L71 82 62 86 64 74 71 56Z', '#a96d93', 'none')
    for d in ['M48 35Q62 41 78 35','M45 46Q62 53 81 46','M45 58Q63 65 82 57','M49 71Q64 76 77 69']:
        b += p(d, stroke='#895978', w=2)
    # Five thick tail segments ending in a sharp downward-pointing sting.
    b += p('M57 28L57 16 67 9 82 11 96 20 104 33 101 47 93 53 86 47 91 37 87 28 76 24 68 30Z', '#bc82a4', w=3)
    for d in ['M62 14L70 25','M77 11L78 24','M91 17L86 28','M102 31L90 34','M102 44L90 40']:
        b += p(d, stroke='#855574', w=2)
    b += p('M90 47Q104 49 103 63L96 73 96 62 86 57Z', '#825476', w=2.2)
    # Low carapace/head, narrow inset eye clusters instead of two dot eyes.
    b += p('M48 68L56 59H72L80 68 77 89 69 99H59L50 90Z', '#dfacc2', w=3)
    b += p('M71 62L77 70 74 87 67 94H62L65 80Z', '#c58ca9', 'none')
    b += p('M53 68L62 71 61 76 55 74Z','#64455a','none')
    b += p('M66 71L75 68 73 74 67 76Z','#64455a','none')
    b += p('M55 70L60 72M69 72L73 70',stroke='#eed39f',w=1.2)
    b += p('M53 65L62 68M66 68L75 65',stroke='#ae7495',w=1.7)
    # Articulated pedipalps lead to long opposing fingers, not boxing gloves.
    b += p('M50 81L35 89 28 104M78 81L93 89 100 104',stroke=INK,w=9)
    b += p('M50 81L35 89 28 104M78 81L93 89 100 104',stroke='#b87d9f',w=5)
    left = p('M29 96Q13 88 7 101 3 111 14 119L25 123 21 113 14 108 18 103 28 111 35 109 35 103Z','#d49bb7',w=2.7)
    left += p('M29 108L34 121 27 126 29 115 23 110Z','#be83a4',w=2)
    b += left + '<g transform="translate(128 0) scale(-1 1)">' + left + '</g>'
    b += p('M15 99L12 104M103 100L108 104M52 41L55 42',stroke='#f3c9d2',w=1.6)
    return b


def vulture():
    # Balanced spread wings. Central head, short recessed neck, tucked feet;
    # a hovering bird silhouette rather than a diagonal diving gesture.
    b = p('M51 88L43 109 52 107 56 118 64 112 72 118 76 107 85 109 77 88Z','#887796',w=2.5)
    wing=p('M53 52Q38 40 23 39L7 42 16 50 4 52 14 59 3 64 15 69 5 77 21 79 13 88 31 86 28 96 46 86 56 73Z','#9badbd',w=2.8)
    wing+=p('M49 54Q35 47 23 47L29 57 20 57 29 65 21 68 34 73 30 78 44 77 54 67Z','#becbd1',w=1.7)
    wing+=p('M20 51L39 62M17 64L37 70M23 79L40 77',stroke='#7e8f9e',w=1.5)
    b+=wing+'<g transform="translate(128 0) scale(-1 1)">'+wing+'</g>'
    # Compact feathered chest tapers into the tail. No long upright torso.
    b+=p('M47 58Q49 45 64 45 79 45 82 59L86 77Q84 94 72 101L64 106 55 101Q44 95 42 78Z','#a18db4',w=2.8)
    b+=p('M77 57Q87 72 81 87L72 98 64 103 58 98Q76 87 76 70Z','#806d9a','none')
    b+=p('M51 71L58 76 64 72 70 76 77 71M55 86L64 91 73 86',stroke='#c3b5cd',w=1.6)
    # Two tucked legs emerge at the same depth, with hooked talons.
    b+=p('M53 94L51 103 45 105M75 94L77 103 83 105',stroke=INK,w=4)
    b+=p('M53 94L51 103 45 105M75 94L77 103 83 105',stroke='#c2a076',w=2)
    b+=p('M46 104L43 109M51 103L50 109M77 103L78 109M82 104L85 109',stroke='#68534b',w=1.4)
    # Bare neck is visible but kept directly over the breast.
    b+=p('M54 40L55 58Q64 65 73 58L74 40Z','#c69e88',w=2.1)
    b+=p('M58 42L59 56 65 58 68 43Z','#e0c0a5','none')
    ruff=p('M46 53L51 49 56 52 60 48 65 51 70 48 75 52 79 50 83 55 80 63 75 61 70 66 64 62 58 66 53 61 48 63Z','#f0dec0',w=2)
    b+=ruff
    # Forward-facing skull with a hooked central beak. Small lateral eyes
    # carry an alert, predatory expression without a human smile.
    b+=p('M48 26Q48 12 64 11 80 12 80 26L77 40 69 47H59L51 40Z','#dfbda5',w=2.7)
    b+=p('M73 16Q81 22 77 36L70 43 65 45 63 41Q73 33 73 16Z','#c69e88','none')
    b+=p('M51 27L60 29 59 34 53 33ZM68 29L77 27 75 33 69 34Z','#efe0b8',w=1.2)
    b+=p('M57 29V33M71 29V33',stroke='#59473f',w=1.7)
    b+=p('M51 24L60 27M68 27L77 24',stroke='#795b4e',w=2)
    b+=p('M59 33Q64 30 69 33L69 43 65 49 64 42 59 40Z','#c59b65',w=1.8)
    b+=p('M62 34L63 40',stroke='#e8ca8a',w=1.2)
    return b


def monitor():
    # Three-quarter oblique creature, with a visible flank, receding far legs,
    # projecting snouts and a shared low shoulder. No mirrored overhead diagram.
    # Tail sweeps behind the near haunch, tapering as an actual continuation
    # of the spine instead of a separate decorative curl.
    b=p('M105 92Q127 95 132 115 136 136 147 143 128 141 118 127L100 112 87 103Z','#719582',w=2.7)
    b+=p('M114 103Q125 116 128 127L139 140Q124 133 117 122L102 109Z','#587c70','none')
    b+=p('M114 102Q127 111 131 127',stroke='#a2bca0',w=1.5)
    # Far legs are smaller, darker and partially hidden by the trunk.
    b+=p('M71 67L56 73 53 88 44 91 43 96 58 97 65 88 69 80 82 80Z','#5f8878',w=2.4)
    b+=p('M109 86L126 94 125 108 134 113 133 117 119 114 115 104 102 101Z','#5f8878',w=2.4)
    b+=p('M44 94L39 97M49 96L46 100M130 113L136 118',stroke='#66574a',w=1.2)
    # A long low animal trunk; the upper back is a narrow illuminated plane,
    # while the shaded flank carries most of the visible mass.
    b+=p('M55 64Q68 52 85 58L112 72Q127 83 124 99L115 112Q105 119 89 111L61 94Q47 85 48 74Z','#87a78e',w=3)
    b+=p('M51 77Q70 74 88 87L119 94 123 90 123 101 114 112Q104 117 89 109L60 94Q48 86 51 77Z','#638d79','none')
    b+=p('M59 65Q71 57 85 63L109 76 117 88Q99 83 88 78L66 72Z','#a6bea0','none')
    # Dorsal ridge follows the diagonal volume, never the centre of a belly.
    b+=p('M60 61L67 55 70 62 76 58 79 65 86 62 89 70 95 67 98 75 104 73 107 81 112 80 116 90', '#60816d',w=1.2)
    b+=p('M58 72Q75 71 88 82M94 86L108 91',stroke='#789d83',w=1.6)
    for x,y,rx,ry in [(69,76,2.5,1.8),(78,81,2.7,2),(87,87,2.8,2),(98,93,3,2),(109,98,2.5,2)]:
        b+=e(x,y,rx,ry,'#abc19e')
    # Broad near hind thigh, then knee, lower leg and planted clawed foot.
    b+=p('M100 90Q115 89 120 100L119 111 108 121 114 128 127 129 128 135 111 138 98 130 98 118 104 108 94 105Z','#8aab91',w=2.8)
    b+=p('M113 100Q118 108 108 117L103 122 105 129 117 133',stroke='#5c826e',w=1.7)
    b+=p('M119 132L130 135M115 135L125 140M111 135L118 142',stroke='#65564b',w=1.3)
    # Near foreleg descends from the shoulder and bends back toward the palm;
    # its ground line is below the far forefoot, showing the oblique camera.
    b+=p('M63 76Q71 80 70 90L61 102 64 110 76 113 76 119 61 121 49 112 48 101 55 90 53 82Z','#98b49a',w=2.7)
    b+=p('M60 85L58 94 53 103 56 111 66 115',stroke='#74977f',w=1.6)
    b+=p('M69 115L79 120M64 118L73 124M59 118L65 125',stroke='#65564b',w=1.3)
    # Rear neck first: grows out of the same shoulder behind the near head.
    b+=p('M78 72Q71 61 73 50L72 36 60 28 51 37 55 56Q58 72 65 79Z','#86ad9b',w=2.6)
    b+=p('M61 44L65 59 72 68',stroke='#638d7d',w=1.5)
    # Far head shows its upper and side planes, projected upper-left snout.
    b+=p('M55 44L45 37 37 26 27 22 24 16 30 12 47 15 58 19 66 30 65 39Z','#a5c6b4',w=2.7)
    b+=p('M28 22L44 26 55 31 63 29 65 36 57 43 46 36 39 28Z','#79a28f','none')
    b+=p('M28 16L44 19 55 23',stroke='#c3d7bd',w=1.5)
    b+=p('M46 23L54 24 53 29 47 28Z','#d6cf95',w=1.2)
    b+=p('M50 25V28',stroke='#4d5245',w=1.6)
    b+=p('M27 18L29 19M30 24L42 29 52 34',stroke='#5d7c69',w=1.3)
    # Stronger near neck curves forward along the ground. The jaw projects
    # well beyond the shoulder, rather than sitting atop an upright stalk.
    b+=p('M60 83Q47 81 41 68L32 56 39 46 52 52Q54 66 69 71L71 80Z','#9bb99a',w=2.7)
    b+=p('M36 58Q44 73 57 76L66 78',stroke='#73967c',w=2)
    # Near skull and elongated monitor muzzle, with a distinct upper jaw and
    # cheek, one lateral eye and a low closed jawline. No humanoid face mask.
    b+=p('M37 64L26 59 18 51 8 47 5 40 10 35 28 38 40 43 48 52 47 59Z','#b5cda6',w=2.8)
    b+=p('M8 46L25 48 37 53 46 52 46 58 36 63 25 57 18 51Z','#8cae8b','none')
    b+=p('M10 39L27 42 37 46',stroke='#d1ddba',w=1.6)
    b+=p('M29 46L39 47 37 53 31 52Z','#dad09a',w=1.2)
    b+=p('M34 48V52',stroke='#4d5245',w=1.7)
    b+=p('M8 42L10 43M10 49L24 53 37 57',stroke='#5d7c69',w=1.4)
    b+=p('M28 44L39 45',stroke='#6b8b6f',w=1.6)
    # Visual direction is upper-left, preserving an upper-facing forward axis
    # while the uneven limbs and overlapping heads establish the side view.
    return b


BOSSES = {'sandworm_boss': sandworm, 'scorpion_boss': scorpion,
          'vulture_boss': vulture, 'monitor_boss': monitor}
