"""Deterministic, original synthesized demo audio. No downloaded samples.

Run with Python + NumPy. All loops are rendered offline (including circular
room echoes), so playback has no synthesis cost. Instrument names describe
the intended timbre rather than recordings of acoustic instruments.
"""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "Audio"
RATE = 32000
RNG = np.random.default_rng(20261117)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def voice(midi, duration, kind):
    t = np.arange(round(duration * RATE)) / RATE
    f = hz(midi)
    attack = np.minimum(t / .008, 1)
    release = np.minimum((duration - t) / .06, 1)
    if kind == "pluck":
        x = sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * (3 + k * 1.5)) / k ** 1.4 for k in range(1, 7))
        x += RNG.normal(0, .035, t.size) * np.exp(-t * 70)
    elif kind == "flute":
        phase = 2 * np.pi * f * t + .03 * np.sin(2 * np.pi * 5 * t)
        x = (np.sin(phase) + .12 * np.sin(2 * phase) + .045 * np.sin(3 * phase)) * np.minimum(t / .07, 1)
        x += RNG.normal(0, .006, t.size)
    elif kind == "bell":
        x = (np.sin(2 * np.pi * f * t) * np.exp(-t * 3) + .25 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t * 7))
    elif kind == "pad":
        x = (np.sin(2 * np.pi * f * t) + .2 * np.sin(2 * np.pi * (f * 2 + .3) * t)) * np.minimum(t / .4, 1)
    elif kind == "bass":
        x = (np.sin(2 * np.pi * f * t) + .18 * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t * 2.5)
    elif kind == "drum":
        phase = 2 * np.pi * (55 * t + 4 * (1 - np.exp(-t * 24)))
        x = np.sin(phase) * np.exp(-t * 14) + RNG.normal(0, .2, t.size) * np.exp(-t * 65)
    elif kind == "rim":
        x = RNG.normal(0, .3, t.size) * np.exp(-t * 85) + np.sin(2 * np.pi * 560 * t) * np.exp(-t * 80)
    elif kind == "shaker":
        n = RNG.normal(0, .35, t.size)
        x = (n - np.roll(n, 1)) * np.exp(-t * 60)
    else:
        raise ValueError(kind)
    return x * attack * release


def write(name, x, peak=.72):
    ROOT.mkdir(exist_ok=True)
    x = x / max(float(np.max(np.abs(x))) / peak, 1)
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as out:
        out.setnchannels(2 if x.ndim == 2 else 1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(np.round(x * 32767).astype("<i2").tobytes())
    print(f"{name}: {len(x) / RATE:.2f}s, peak={np.max(np.abs(x)):.3f}, rms={np.sqrt(np.mean(x*x)):.3f}")


def music(name, bpm, chords, melody, mood):
    beat = 60 / bpm
    bars = 24
    n = round(bars * 4 * beat * RATE)
    song = np.zeros((n, 2))

    def add(at, midi, beats, kind, gain, pan=0):
        sample = voice(midi, beats * beat, kind) * gain
        start = round(at * beat * RATE)
        indices = (start + np.arange(len(sample))) % n
        song[indices, 0] += sample * math.sqrt((1 - pan) / 2)
        song[indices, 1] += sample * math.sqrt((1 + pan) / 2)

    for bar in range(bars):
        root, third, fifth = chords[bar % len(chords)]
        add(bar * 4, root - 12, 1.8, "bass", .15)
        if mood != "night":
            add(bar * 4 + 2, root - 12, 1.4, "bass", .11)
        for note in [root + 12, third + 12, fifth + 12]:
            add(bar * 4, note, 4.3, "pad", .025 if mood != "night" else .04, -.3)
        pattern = [root + 12, fifth + 12, third + 12, fifth + 12]
        for j, note in enumerate(pattern):
            add(bar * 4 + j + .03, note, .9, "pluck", .13 if mood != "night" else .09, -.35)
        phrase = melody[bar % len(melody)]
        for pos, note, length in phrase:
            # Middle section varies the voicing and leaves room for percussion.
            kind = "flute" if (bar // 8) % 2 == 0 else "bell"
            add(bar * 4 + pos, note, length, kind, .15 if kind == "flute" else .12, .25)
        if mood == "night":
            if bar % 2 == 0:
                add(bar * 4 + 2, 60, .15, "shaker", .07, .4)
        else:
            for pos in ([0, 1.5, 2.5, 3.5] if mood == "boss" else [0, 2.5]):
                add(bar * 4 + pos, 60, .5, "drum", .22 if mood == "boss" else .16, -.1)
            for pos in [1, 3]:
                add(bar * 4 + pos, 60, .18, "rim", .12, .2)
            for pos in np.arange(.5, 4, .5):
                add(bar * 4 + pos, 60, .14, "shaker", .07, .45)
        if mood == "boss":
            for pos in [.5, 1.5, 2.5, 3.5]:
                add(bar * 4 + pos, root, .35, "pluck", .16, -.4)
    # Circular echoes preserve the tails at the loop seam.
    dry = song.copy()
    for delay, gain in [(.17, .15), (.31, .09), (.47, .06)]:
        song += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
    write(name, song)


def sweep(start, end, duration, gain=.4, noisy=False):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * (start * t + (end - start) * t * t / (2 * duration))
    envelope = np.minimum(t / .005, 1) * (1 - t / duration) ** 1.4
    x = np.sin(phase) * gain
    if noisy:
        x += RNG.normal(0, gain * .35, t.size)
    return x * envelope


def chime(notes, gap=.07, duration=.22):
    x = np.zeros(round((gap * (len(notes) - 1) + duration) * RATE))
    for i, note in enumerate(notes):
        sample = voice(note, duration, "bell") * .3
        start = round(i * gap * RATE)
        x[start:start + len(sample)] += sample
    return x



def bubble(duration=.42, gain=.28):
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for offset, freq, length in [(.02, 430, .11), (.12, 620, .08), (.22, 520, .13), (.31, 780, .07)]:
        start = round(offset * RATE)
        end = min(len(t), start + round(length * RATE))
        local = np.arange(max(end - start, 0)) / RATE
        x[start:end] += np.sin(2 * np.pi * (freq + 90 * local) * local) * np.minimum(local / .008, 1) * np.maximum(1 - local / length, 0) ** 1.8
    return x * gain


def metallic(duration=.48, gain=.3):
    t = np.arange(round(duration * RATE)) / RATE
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * decay) for f, decay in [(740, 8), (1180, 12), (1810, 17)])
    return x * np.minimum(t / .003, 1) * np.maximum(1 - t / duration, 0) ** 1.5 * gain


def flame(duration=.55, gain=.34):
    """A short gas/flame bed with irregular crackles, rather than a tonal sweep."""
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.normal(0, 1, t.size)
    # Smooth noise gives the broad whoosh; the sparse impulses read as flame pops.
    smooth = np.convolve(noise, np.ones(160) / 160, mode="same")
    pops = np.zeros_like(t)
    for at, amp in [(.06, .8), (.19, .55), (.31, .7), (.44, .42)]:
        i = round(at * RATE)
        if i < len(pops):
            length = min(round(.035 * RATE), len(pops) - i)
            pops[i:i + length] += RNG.normal(0, amp, length) * np.exp(-np.arange(length) / (RATE * .008))
    tone = np.sin(2 * np.pi * 92 * t) * .18 + np.sin(2 * np.pi * 177 * t) * .08
    envelope = np.minimum(t / .012, 1) * np.maximum(1 - t / duration, 0) ** .7
    # Keep a quiet, wide noise bed under the crackles so the fire reads as a
    # sustained flame rather than a single synthetic click.
    return (noise * .16 + smooth * 1.35 + pops + tone) * envelope * gain


def chop(duration=.24, gain=.48):
    """Two wooden chopping impacts with a dry, low transient."""
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for at, amp in [(.025, 1.0), (.135, .82)]:
        i = round(at * RATE)
        length = min(round(.055 * RATE), len(x) - i)
        local = np.arange(max(length, 0)) / RATE
        if length > 0:
            impact = RNG.normal(0, .34, length) + np.sin(2 * np.pi * 105 * local) * 1.15
            x[i:i + length] += impact * np.exp(-local * 70) * amp
    return (x + RNG.normal(0, .05, len(x))) * np.minimum(t / .002, 1) * gain


def coin_clink(duration=.62, gain=.62):
    """Several bright coin strikes with a short metallic ring."""
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for at, freq, amp in [(.02, 2180, 1.0), (.18, 2840, .78), (.34, 2410, .9), (.47, 3260, .62)]:
        local = np.maximum(t - at, 0.0)
        active = (t >= at).astype(float)
        x += active * (np.sin(2 * np.pi * freq * local) + .42 * np.sin(2 * np.pi * freq * 1.71 * local)) * np.exp(-local * 18) * amp
    return x * np.minimum(t / .002, 1) * gain


def evil_laugh(duration=.58, gain=.48):
    """Two breathy, descending 'heh' syllables made from voiced noise."""
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    noise = RNG.normal(0, 1, len(t))
    breath = noise - np.roll(noise, 3)
    for at, length, f0 in [(.02, .19, 170), (.27, .23, 145)]:
        local = np.maximum(t - at, 0.0)
        active = (t >= at).astype(float)
        env = active * np.minimum(local / .012, 1) * np.maximum(1 - local / length, 0) ** .8
        wobble = np.sin(2 * np.pi * (f0 - 32 * local / length) * local)
        x += env * (breath * .48 + wobble * .62 + np.sin(2 * np.pi * f0 * 2.03 * local) * .16)
    return x * gain


def fire_whoosh(duration=.46, gain=.45):
    """Playful rising breath: an excited little 'whoo-hoo' of flame."""
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.normal(0, 1, len(t))
    smooth = np.convolve(noise, np.ones(120) / 120, mode="same")
    phase = 2 * np.pi * (250 * t + 260 * t * t / duration)
    env = np.minimum(t / .02, 1) * np.maximum(1 - t / duration, 0) ** .65
    return (smooth * .7 + np.sin(phase) * .35 + np.sin(phase * .52) * .16) * env * gain


def glass_chime(duration=.58, gain=.52):
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for freq, decay, amp in [(1640, 7, 1.0), (2460, 10, .7), (3420, 14, .42), (4170, 18, .25)]:
        x += np.sin(2 * np.pi * freq * t) * np.exp(-t * decay) * amp
    return x * np.minimum(t / .001, 1) * np.maximum(1 - t / duration, 0) ** .25 * gain


def stone_hit(duration=.52, gain=.58):
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.normal(0, 1, len(t))
    x = np.sin(2 * np.pi * 82 * t) * np.exp(-t * 8) + np.sin(2 * np.pi * 137 * t) * np.exp(-t * 13)
    x += noise * np.exp(-t * 55) * .62
    return x * np.minimum(t / .002, 1) * np.maximum(1 - t / duration, 0) ** .65 * gain


def spirit_woohoo(duration=.56, gain=.42):
    """Unintelligible airy two-syllable spirit call: wu-hoo."""
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for at, length, f0, f1 in [(.0, .22, 230, 180), (.25, .27, 330, 470)]:
        local = np.maximum(t - at, 0.0)
        active = (t >= at).astype(float)
        env = active * np.minimum(local / .018, 1) * np.maximum(1 - local / length, 0) ** .5
        phase = 2 * np.pi * (f0 * local + (f1 - f0) * local * local / (2 * length))
        x += env * (np.sin(phase) + .28 * np.sin(phase * 2.01))
    return x * gain


def dice_roll(duration=.72, gain=.48):
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    for at, amp in [(0.04, .45), (.14, .33), (.25, .27), (.36, .25), (.49, .8), (.61, .95)]:
        i = round(at * RATE)
        length = min(round(.035 * RATE), len(x) - i)
        if length > 0:
            local = np.arange(length) / RATE
            click = RNG.normal(0, 1, length) * np.exp(-local * 75) + np.sin(2 * np.pi * 1150 * local) * .36
            x[i:i + length] += click * amp
    return x * np.minimum(t / .002, 1) * gain


def void_voice(duration=.78, gain=.46):
    """Low, unstable, reverse-like void tone with dissonant upper partials."""
    t = np.arange(round(duration * RATE)) / RATE
    env = np.minimum(t / .09, 1) * np.maximum(1 - t / duration, 0) ** .3
    low = np.sin(2 * np.pi * (58 * t - 19 * t * t / duration))
    mid = np.sin(2 * np.pi * (173 * t + 35 * t * t / duration)) * .34
    high = np.sin(2 * np.pi * 611 * t + 1.7 * np.sin(2 * np.pi * 4 * t)) * .18
    noise = RNG.normal(0, .18, len(t))
    return (low + mid + high + noise) * env * gain


def short_music(name, root, melody, mood):
    beat = 60 / (92 if mood == "success" else 72)
    bars = 8
    n = round(bars * 4 * beat * RATE)
    song = np.zeros((n, 2))
    def add(at, midi, beats, kind, gain, pan=0):
        sample = voice(midi, beats * beat, kind) * gain
        start = round(at * beat * RATE)
        indices = (start + np.arange(len(sample))) % n
        song[indices, 0] += sample * math.sqrt((1 - pan) / 2)
        song[indices, 1] += sample * math.sqrt((1 + pan) / 2)
    for bar in range(bars):
        chord = [root, root + 4, root + 7] if mood == "success" else [root, root + 3, root + 7]
        for note in chord:
            add(bar * 4, note, 3.8, "pad", .035, -.25)
        add(bar * 4, root - 12, 1.4, "bass", .13)
        add(bar * 4 + 2, root - 12, 1.0, "bass", .09)
        for pos, note in enumerate(melody[bar % len(melody)]):
            add(bar * 4 + pos * .75, note, .55, "bell", .16 if mood == "success" else .11, .2)
        add(bar * 4, 60, .35, "drum", .13 if mood == "success" else .09)
        add(bar * 4 + 2, 60, .25, "rim", .08)
    dry = song.copy()
    song += np.roll(dry[:, ::-1], round(.19 * RATE), axis=0) * .12
    write(name, song)

def mix(*signals):
    length = max(len(signal) for signal in signals)
    result = np.zeros(length)
    for signal in signals:
        result[:len(signal)] += signal
    return result


def generate():
    music("music_title", 104, [(48, 52, 55), (45, 48, 52), (53, 57, 60), (55, 59, 62)], [
        [(0, 72, .7), (1, 76, .5), (2, 79, 1.4)], [(0, 76, .7), (1, 74, .5), (2.5, 72, 1)],
        [(0, 69, 1), (1.5, 72, .5), (2.5, 77, 1)], [(0, 74, .7), (1, 71, .5), (2, 72, 1.7)]], "title")
    short_music("music_success", 60, [[72, 76, 79, 84], [79, 83, 86, 91], [76, 79, 84, 88], [72, 76, 79, 84]], "success")
    short_music("music_end", 48, [[60, 63, 67, 70], [67, 65, 63, 60], [58, 62, 65, 67], [60, 58, 55, 52]], "end")
    # Dorian minor colour, plucked strings, breathy lead and hand percussion.
    music("music_night", 76, [(50, 53, 57), (48, 52, 55), (43, 46, 50), (45, 49, 52)], [
        [(0, 74, 1.5), (2.5, 77, .9)], [(1, 76, 1), (2.5, 72, .8)],
        [(0, 70, 1.6), (2.5, 69, 1)], [(0, 73, 1), (2, 74, 1.4)]], "night")
    music("music_day", 112, [(50, 53, 57), (48, 52, 55), (55, 59, 62), (45, 49, 52)], [
        [(0, 74, .6), (.75, 77, .5), (1.5, 81, .6), (2.5, 79, .8)],
        [(0, 76, .5), (1, 79, .6), (2, 76, .5), (3, 72, .5)],
        [(0, 79, .7), (1, 83, .5), (2, 81, .7), (3, 79, .5)],
        [(0, 76, .6), (1, 73, .6), (2.5, 74, 1)]], "day")
    music("music_boss", 126, [(38, 41, 45), (39, 43, 46), (43, 46, 50), (45, 49, 52)], [
        [(0, 74, .5), (1, 75, .4), (2, 77, .8), (3, 74, .5)],
        [(0, 75, .5), (1.5, 79, .5), (2.5, 82, .9)],
        [(0, 79, .8), (1.5, 77, .5), (3, 74, .7)],
        [(0, 73, .6), (1, 76, .5), (2, 73, .5), (3, 74, .7)]], "boss")
    effects = {
        "ui_move": sweep(650, 800, .05, .18), "ui_tab": chime([67, 74], .035, .12),
        "ui_confirm": chime([76, 79], .055, .16), "ui_cancel": chime([69, 64], .05, .13),
        "ui_refresh": chime([67, 71, 74, 79], .035, .17), "pickup": sweep(280, 520, .1, .24),
        "drop": sweep(230, 100, .11, .26), "interaction": voice(60, .09, "rim") * .8,
        "work_tick": voice(60, .08, "rim") * .6, "attack_light": sweep(480, 100, .14, .18, True),
        "attack_heavy": sweep(280, 50, .26, .37, True), "hit": sweep(140, 55, .12, .4, True),
        "hurt": sweep(260, 90, .24, .38, True), "dash": sweep(180, 750, .16, .17, True),
        "skill": chime([62, 69, 74, 77], .045, .3), "ultimate": chime([50, 62, 69, 74, 81], .065, .55),
        "event": chime([69, 73, 76, 81], .09, .35), "warning": chime([63, 62], .14, .23),
        "serve": mix(chime([74, 78, 81], .065, .25), metallic(.27, .22)), "success": chime([62, 66, 69, 74], .12, .5),
        "failure": chime([65, 63, 60, 57], .14, .5), "purchase": coin_clink(.62, .72),
        "cut": chop(.26, .64), "grind": sweep(175, 75, .34, .27, True),
        "wash": bubble(.42, .31), "brew": bubble(.55, .48), "roast": flame(.55, .82),
        "complete": chime([74, 81], .08, .17), "forage": metallic(.32, .48), "order": chime([72, 76], .07, .34), "upgrade": mix(chime([60, 67, 72, 76, 84], .08, .9), metallic(.3, .28)), "forge": metallic(.42, .58), "npc_merchant": coin_clink(.62, .72), "npc_devil": evil_laugh(.58, .6), "npc_furnace": fire_whoosh(.46, 1.15), "npc_porcelain": glass_chime(.58, .68), "npc_sand_spirit": spirit_woohoo(.56, .58), "npc_prankster": void_voice(.78, .64), "npc_engraver": stone_hit(.52, .95), "npc_gambler": dice_roll(.72, .82), "npc_repayment": coin_clink(.62, .72), "enemy_shoot": sweep(330, 170, .12, .2, True),
        "impact": voice(60, .4, "drum") * .6, "enemy_down": sweep(240, 70, .25, .18),
        "boss_alert": chime([50, 57, 62], .12, .5), "spit": sweep(110, 360, .23, .21, True),
    }
    for name, data in effects.items():
        write(name, data)


if __name__ == "__main__":
    generate()
