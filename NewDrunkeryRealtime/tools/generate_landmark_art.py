"""Hand-authored landmark vectors in the kitchen's warm atelier palette."""
from pathlib import Path

ART = Path(__file__).resolve().parents[1] / 'ArtResource/Restaurant'


def generate():
    body = '''<ellipse cx="80" cy="207" rx="57" ry="9" fill="#513420" opacity=".18" stroke="none"/>
<path d="M32 194h96v17H32z" fill="#94785b"/><path d="M41 179h78v17H41z" fill="#c6ad7e"/>
<path d="M51 170l13-68h32l13 68z" fill="#d5d3b6"/><path d="M71 108l-9 60h35l-9-60" fill="#f0e6c9"/>
<path d="M65 117l-5 37m34-35 5 35m-32 17h29" fill="none" stroke="#acb4a2" stroke-width="2"/>
<path d="M60 99L45 78l-11 7 14 30 21 8m31-24 15-21 11 7-14 30-21 8" fill="#e7debf"/>
<path d="M50 67q-1-34 29-36 32 1 32 37l-14 35H63z" fill="#abbcb0"/>
<ellipse cx="80" cy="69" rx="22" ry="28" fill="#f3e6c8"/>
<path d="M57 66q3-25 23-26 18 1 25 25L92 48 80 59 68 50z" fill="#c7cfb8"/>
<path d="M68 68h6m12 0h6M75 82q5 4 10 0" fill="none" stroke="#7d7967" stroke-width="2"/>
<path d="M62 97l18 13 18-13-7 23H69z" fill="#91b9b0"/><path d="M80 108v53" fill="none" stroke="#d5bb79" stroke-width="3"/>
<path d="M47 111q33 17 66 0l-5 17q-28 14-56 0z" fill="#d3b476"/><ellipse cx="80" cy="111" rx="33" ry="13" fill="#f1dfad"/>
<path d="M61 109q19-10 38 0" fill="none" stroke="#a5c4b3" stroke-width="2"/>
<path d="M80 6l5 10 11 2-8 8 2 11-10-5-10 5 2-11-8-8 11-2z" fill="#f1cf7b" stroke-width="2"/>
<path d="M48 30l-7-7m71 7 7-7M80 3V0" fill="none" stroke="#d7b76e" stroke-width="2"/>
<path d="M48 185h64m-72 16h81M66 39q14-8 28 0" fill="none" stroke="#fff0cb" stroke-width="2"/>'''
    (ART / 'goddess_statue.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="160" height="220" viewBox="0 0 160 220"><g stroke="#5d5141" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">' + body + '</g></svg>\n', encoding='utf-8')
    # Retain the original merchant's canvas so carrying/sorting metrics agree.
    event = (ART.parent / 'Events/merchant.svg').read_text(encoding='utf-8')
    import re
    source = re.sub(r'^.*?<svg[^>]*>', '', event, count=1, flags=re.S).rsplit('</svg>', 1)[0]
    (ART / 'salesperson.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="320" viewBox="0 0 256 320"><g transform="translate(8 12) scale(2)">' + source + '</g></svg>\n', encoding='utf-8')
    from finish_art_direction import finish
    finish(ART / 'goddess_statue.svg')
    finish(ART / 'salesperson.svg')


if __name__ == '__main__':
    generate()
