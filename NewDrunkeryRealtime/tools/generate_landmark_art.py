"""Hand-authored landmarks in the approved flat character palette."""

def generate():
    from character_cast_refinements import generate as generate_cast
    generate_cast('landmarks')

if __name__ == '__main__':
    generate()
