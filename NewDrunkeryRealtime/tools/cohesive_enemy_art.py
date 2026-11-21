"""Compatibility entry for the refined round desert creatures."""
import xml.etree.ElementTree as ET

def generate(art, svg, path, ellipse, rect, group):
    from character_cast_refinements import enemy_bodies
    from character_art_refinements import document
    creatures = enemy_bodies()
    for name, body in creatures.items():
        target = art / 'Generated/Enemy' / f'{name}.svg'
        source = ET.parse(target).getroot()
        size = (int(source.get('width')), int(source.get('height')))
        view = (150, 160) if name == 'monitor_boss' else (128, 128)
        target.write_text(document(body, *size, view), encoding='utf-8')
    return len(creatures)

if __name__ == '__main__':
    from generate_cohesive_art import ART, svg, path, ellipse, rect, group
    print(f'Generated {generate(ART, svg, path, ellipse, rect, group)} refined desert creatures.')
