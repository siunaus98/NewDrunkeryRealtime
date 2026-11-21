"""Offline portraits shared by world NPCs, indicators and dialogue panels."""

def generate():
    from character_cast_refinements import generate as generate_cast
    from character_art_refinements import generate as generate_refinements
    generate_cast('npcs')
    generate_refinements('merchant')

if __name__ == '__main__':
    generate()
