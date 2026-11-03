"""One-shot creature vocalisations for Portal Wonders, synthesised with numpy.
Usage: python3 synth_voices.py <out_dir>   (writes .wav; encode to .m4a with ffmpeg)"""
import sys, os, wave, numpy as np

SR = 44100
out_dir = sys.argv[1]

# ------------------------------------------------------------------ building blocks
def seconds(n): return np.arange(int(n * SR)) / SR

def curve(points, tt):
    """Piecewise-linear value over time from [(t, v), ...]."""
    ts, vs = zip(*points)
    return np.interp(tt, ts, vs)

def voiced(f0, tt, harmonics=12, rolloff=0.9, jitter=0.0, rng=None):
    """Harmonic-rich tone following an f0 curve (additive pulse approximation)."""
    if jitter and rng is not None:
        f0 = f0 * (1 + jitter * np.cumsum(rng.standard_normal(len(tt))) / np.sqrt(len(tt)))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    y = np.zeros_like(tt)
    for n in range(1, harmonics + 1):
        y += np.sin(n * phase) / n ** rolloff
    return y / np.abs(y).max()

def bandpass(x, lo, hi, order=2.0):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 * order)) * 1 / (1 + (f / hi) ** (2 * order))
    return np.fft.irfft(spec * g, len(x))

def formants(x, centers, widths, gains=None):
    """Vocal-tract colouring: sum of resonant bandpasses."""
    gains = gains or [1.0] * len(centers)
    y = np.zeros_like(x)
    for c, w, g in zip(centers, widths, gains):
        y += bandpass(x, c - w / 2, c + w / 2, order=1.5) * g
    return y / (np.abs(y).max() + 1e-9)

def env(tt, attack, release, hold_level=1.0):
    e = np.full(len(tt), hold_level)
    a = int(attack * SR); r = int(release * SR)
    if a: e[:a] = np.linspace(0, hold_level, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e

def tremolo(tt, rate, depth):
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * rate * tt))

def reverb(x, decay_s=1.0, taps=6, rng=None, wet=0.5):
    rng = rng or np.random.default_rng(3)
    y = x.copy()
    for i in range(taps):
        d = int(SR * (0.03 + 0.09 * i + rng.uniform(0, 0.02)))
        g = np.exp(-(0.03 + 0.09 * i) / decay_s * 3) * wet
        if d < len(x): y[d:] += x[:-d] * g
    return y

def place(buf, start_s, sig, gain=1.0):
    s = int(start_s * SR); e = min(s + len(sig), len(buf))
    if s < len(buf): buf[s:e] += sig[: e - s] * gain

def finish(x, peak=0.7):
    x = x - x.mean()
    return np.clip(x / (np.abs(x).max() + 1e-9) * peak, -1, 1)

def write(name, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(out_dir, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print(f"wrote {name}.wav  {len(x)/SR:.2f}s")

# ------------------------------------------------------------------ narwhal
def narwhal_clicks():
    """Echolocation buzz: broadband clicks that accelerate into a terminal buzz."""
    rng = np.random.default_rng(1)
    dur = 1.6; buf = np.zeros(int(dur * SR))
    t_click = 0.05; gap = 0.09
    while t_click < dur - 0.1:
        n = int(0.0025 * SR)
        click = bandpass(rng.standard_normal(n * 8), 5000, 16000)[:n] * env(seconds(n / SR), 0.0002, 0.002)
        place(buf, t_click, click, gain=rng.uniform(0.6, 1.0))
        t_click += gap
        gap = max(0.006, gap * 0.93)
    return finish(reverb(buf, 0.6, rng=rng, wet=0.25), 0.6)

def narwhal_whistle():
    """Tonal whistle that rises, wavers, and falls."""
    rng = np.random.default_rng(2)
    tt = seconds(1.1)
    f0 = curve([(0, 1500), (0.3, 3400), (0.6, 2600), (0.85, 3100), (1.1, 1700)], tt)
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * 11 * tt)
    y = voiced(f0, tt, harmonics=3, rolloff=1.6, jitter=0.002, rng=rng) * env(tt, 0.05, 0.25)
    return finish(reverb(bandpass(y, 800, 9000), 1.4, rng=rng, wet=0.45), 0.6)

def narwhal_knocks():
    """A run of low, resonant knocks (narwhals really do this)."""
    rng = np.random.default_rng(4)
    buf = np.zeros(int(1.4 * SR))
    for i, start in enumerate(np.cumsum(rng.uniform(0.09, 0.16, 8))):
        n = int(0.03 * SR); tt = seconds(n / SR)
        f0 = curve([(0, 900), (0.03, 450)], tt)
        knock = voiced(f0, tt, harmonics=6, rolloff=1.2) * env(tt, 0.001, 0.025)
        place(buf, start, knock, gain=rng.uniform(0.6, 1.0))
    return finish(reverb(bandpass(buf, 250, 3000), 1.2, rng=rng, wet=0.5), 0.6)

# ------------------------------------------------------------------ unicorn (horse)
def unicorn_whinny():
    """Classic whinny: high, rippling, then tumbling down into a chesty finish."""
    rng = np.random.default_rng(5)
    tt = seconds(1.6)
    f0 = curve([(0, 850), (0.12, 1050), (0.55, 980), (1.0, 520), (1.35, 330), (1.6, 260)], tt)
    f0 *= 1 + 0.06 * np.sin(2 * np.pi * 6.5 * tt)                     # vibrato
    y = voiced(f0, tt, harmonics=14, rolloff=0.75, jitter=0.004, rng=rng)
    y *= tremolo(tt, curve([(0, 15), (1.0, 13), (1.6, 9)], tt).mean(), 0.65)   # the "heh-heh-heh" ripple
    y = formants(y, [1000, 2100, 3300, 4600], [260, 380, 500, 700], [1.0, 0.8, 0.55, 0.3])
    breath = bandpass(rng.standard_normal(len(tt)), 2000, 7000) * 0.12
    y = (y + breath) * env(tt, 0.06, 0.35) * curve([(0, 0.8), (0.5, 1.0), (1.2, 0.9), (1.6, 0.5)], tt)
    return finish(reverb(y, 0.9, rng=rng, wet=0.3), 0.7)

def unicorn_nicker():
    """Soft, low, pulsing greeting nicker."""
    rng = np.random.default_rng(6)
    tt = seconds(0.9)
    f0 = curve([(0, 140), (0.3, 125), (0.9, 95), ], tt) * (1 + 0.02 * np.sin(2 * np.pi * 7 * tt))
    y = voiced(f0, tt, harmonics=18, rolloff=0.9, jitter=0.006, rng=rng)
    y *= tremolo(tt, 19, 0.8)
    y = formants(y, [500, 1200, 2400], [220, 320, 450], [1.0, 0.6, 0.3])
    y *= env(tt, 0.08, 0.3)
    return finish(reverb(y, 0.6, rng=rng, wet=0.2), 0.6)

def unicorn_snort():
    """Breathy snort with a fluttering lip."""
    rng = np.random.default_rng(8)
    tt = seconds(0.55)
    y = bandpass(rng.standard_normal(len(tt)), 250, 3500) * tremolo(tt, 26, 0.7)
    y *= env(tt, 0.02, 0.3) * curve([(0, 1.0), (0.2, 0.9), (0.55, 0.3)], tt)
    return finish(reverb(y, 0.4, rng=rng, wet=0.15), 0.55)

# ------------------------------------------------------------------ puppy
def _yip(rng, f_base=650):
    tt = seconds(0.11)
    f0 = curve([(0, f_base * 0.8), (0.02, f_base * 1.35), (0.06, f_base * 1.1), (0.11, f_base * 0.7)], tt)
    y = voiced(f0, tt, harmonics=10, rolloff=0.7, jitter=0.01, rng=rng)
    y = formants(y, [1300, 2600, 3900], [350, 500, 700], [1.0, 0.7, 0.35])
    attack = bandpass(rng.standard_normal(len(tt)), 1500, 6000) * env(tt, 0.002, 0.09) * 0.35
    return (y + attack) * env(tt, 0.004, 0.05)

def puppy_yip():
    rng = np.random.default_rng(9)
    buf = np.zeros(int(0.6 * SR))
    place(buf, 0.02, _yip(rng, 680))
    return finish(reverb(buf, 0.5, rng=rng, wet=0.25), 0.7)

def puppy_bark():
    """Two quick yips, the second a touch lower — the classic puppy double bark."""
    rng = np.random.default_rng(10)
    buf = np.zeros(int(0.9 * SR))
    place(buf, 0.02, _yip(rng, 700))
    place(buf, 0.24, _yip(rng, 620), gain=0.9)
    return finish(reverb(buf, 0.5, rng=rng, wet=0.25), 0.7)

def puppy_whine():
    """Pleading whine: thin, rising then sagging."""
    rng = np.random.default_rng(12)
    tt = seconds(0.75)
    f0 = curve([(0, 1100), (0.25, 1750), (0.5, 1600), (0.75, 1000)], tt) * (1 + 0.02 * np.sin(2 * np.pi * 9 * tt))
    y = voiced(f0, tt, harmonics=4, rolloff=1.3, jitter=0.004, rng=rng)
    y = formants(y, [1600, 3200], [500, 800], [1.0, 0.4])
    y *= env(tt, 0.06, 0.2)
    return finish(reverb(y, 0.5, rng=rng, wet=0.2), 0.55)

# ------------------------------------------------------------------ mermaid (bonus)
def mermaid_hum():
    """A sung three-note vocalise, soft and reverberant."""
    rng = np.random.default_rng(13)
    tt = seconds(2.2)
    f0 = curve([(0, 330), (0.6, 330), (0.7, 392), (1.3, 392), (1.4, 440), (2.2, 440)], tt)
    f0 *= 1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt) * curve([(0, 0), (0.4, 1), (2.2, 1)], tt)
    y = voiced(f0, tt, harmonics=12, rolloff=1.1, jitter=0.002, rng=rng)
    y = formants(y, [700, 1100, 2600], [200, 250, 400], [1.0, 0.7, 0.25])
    y *= env(tt, 0.15, 0.6)
    return finish(reverb(y, 2.4, taps=8, rng=rng, wet=0.55), 0.5)

# ------------------------------------------------------------------ mermaid: siren song
A4, B4, C5, D5, E5, F5, G5, A5 = 440.0, 493.88, 523.25, 587.33, 659.25, 698.46, 783.99, 880.0
E4, F4, G4, D4, C4 = 329.63, 349.23, 392.0, 293.66, 261.63

def melody_curve(notes, tt, glide=0.09):
    """notes: [(freq or None for rest, seconds)] -> (f0 curve, loudness gate) with portamento."""
    pts, gate = [], []
    t0 = 0.0; last = None
    for f, d in notes:
        if f is None:
            gate += [(t0, 0.0), (t0 + d, 0.0)]; t0 += d; continue
        if last is None: pts.append((t0, f))
        else:            pts += [(t0, last), (t0 + glide, f)]
        pts.append((t0 + d, f))
        gate += [(t0, 0.0), (t0 + 0.08, 1.0), (t0 + d - 0.05, 1.0), (t0 + d, 0.85)]
        last = f; t0 += d
    pts.append((t0 + 1, last or A4))
    f0 = curve(pts, tt)
    g = curve(sorted(gate), tt)
    return f0, g

def sung_voice(notes, tt, rng, vibrato=0.007, brightness=1.0, breath=0.08):
    """A sung line: harmonic voice, vowel morphing between 'ah' and 'oo', vibrato, breath."""
    f0, gate = melody_curve(notes, tt)
    f0 = f0 * (1 + vibrato * np.sin(2 * np.pi * 5.3 * tt + rng.uniform(0, 6)) * curve([(0, 0.3), (0.5, 1)], tt))
    raw = voiced(f0, tt, harmonics=16, rolloff=1.0, jitter=0.0015, rng=rng)
    ah = formants(raw, [700, 1150, 2600, 3300], [220, 260, 420, 500], [1.0, 0.8, 0.35 * brightness, 0.2 * brightness])
    oo = formants(raw, [320, 760, 2300, 3100], [160, 220, 400, 500], [1.0, 0.55, 0.2 * brightness, 0.1 * brightness])
    morph = 0.5 + 0.5 * np.sin(2 * np.pi * 0.17 * tt + rng.uniform(0, 6))
    y = ah * morph + oo * (1 - morph)
    y += bandpass(rng.standard_normal(len(tt)), 1500, 6000) * breath * gate
    return y * gate

def chorus(x, rng, depth=0.004):
    """Two slightly detuned copies for shimmer (cheap resample via interpolation)."""
    n = len(x); idx = np.arange(n)
    y = x.copy()
    for d in (1 + depth, 1 - depth):
        src = np.clip(idx * d, 0, n - 1)
        y += np.interp(src, idx, x) * 0.5
    return y / (np.abs(y).max() + 1e-9)

def underwater(x):
    """Roll off the top so it sits in the trench, not on the surface."""
    return bandpass(x, 60, 4200, order=1.2)

def siren_piece(melody, harmony, rng, dur, octave_whisper=True):
    tt = seconds(dur)
    lead = sung_voice(melody, tt, rng)
    harm = sung_voice(harmony, tt, rng, vibrato=0.005, brightness=0.7, breath=0.05) * 0.45
    y = lead + harm
    if octave_whisper:
        up = [(f * 2 if f else None, d) for f, d in melody]
        y += sung_voice(up, tt, rng, vibrato=0.004, brightness=0.4, breath=0.02) * 0.12
    y = chorus(y, rng)
    y *= env(tt, 0.4, 1.2)
    return finish(reverb(underwater(y), decay_s=3.5, taps=10, rng=rng, wet=0.6), 0.55)

def mermaid_siren_a():
    """Slow descending lament that turns and climbs back — the classic lure."""
    rng = np.random.default_rng(21)
    melody  = [(E5, 1.0), (D5, 0.7), (C5, 1.0), (A4, 1.4), (None, 0.3), (C5, 0.6), (D5, 0.6), (E5, 1.8)]
    harmony = [(C5, 1.0), (B4, 0.7), (A4, 1.0), (F4, 1.4), (None, 0.3), (A4, 0.6), (B4, 0.6), (C5, 1.8)]
    return siren_piece(melody, harmony, rng, 8.2)

def mermaid_siren_b():
    """Rising arc to a held high note, then settling home."""
    rng = np.random.default_rng(22)
    melody  = [(A4, 0.7), (C5, 0.7), (E5, 1.0), (G5, 0.5), (E5, 1.4), (None, 0.25), (D5, 0.5), (C5, 0.5), (A4, 1.8)]
    harmony = [(D4, 0.7), (F4, 0.7), (A4, 1.0), (C5, 0.5), (A4, 1.4), (None, 0.25), (G4, 0.5), (F4, 0.5), (D4, 1.8)]
    return siren_piece(melody, harmony, rng, 8.0)

def mermaid_lure():
    """One long glissando: rises out of the dark, hangs, and sinks away."""
    rng = np.random.default_rng(24)
    tt = seconds(6.0)
    f0 = curve([(0, A4 * 0.9), (2.4, E5), (3.9, E5), (5.2, A4), (6.0, G4)], tt)
    f0 *= 1 + 0.008 * np.sin(2 * np.pi * 5.1 * tt) * curve([(0, 0), (2.0, 1), (6, 1)], tt)
    raw = voiced(f0, tt, harmonics=16, rolloff=1.0, jitter=0.002, rng=rng)
    y = formants(raw, [420, 900, 2400, 3200], [180, 240, 420, 500], [1.0, 0.6, 0.25, 0.12])
    y += bandpass(rng.standard_normal(len(tt)), 1200, 5000) * 0.1 * curve([(0, 0.2), (3, 1), (6, 0.4)], tt)
    y = chorus(y, rng, depth=0.006)
    y *= env(tt, 0.9, 1.6) * curve([(0, 0.4), (2.4, 1.0), (3.9, 0.9), (6, 0.2)], tt)
    return finish(reverb(underwater(y), decay_s=4.0, taps=10, rng=rng, wet=0.65), 0.5)

def mermaid_call():
    """Short 'oo-ee' call: quick rise, hold, fall. Her hello."""
    rng = np.random.default_rng(25)
    tt = seconds(1.8)
    f0 = curve([(0, G4), (0.3, E5), (0.9, E5), (1.3, C5), (1.8, C5)], tt)
    f0 *= 1 + 0.006 * np.sin(2 * np.pi * 5.6 * tt)
    raw = voiced(f0, tt, harmonics=14, rolloff=1.0, jitter=0.002, rng=rng)
    morph = curve([(0, 0), (0.3, 0), (0.9, 1), (1.8, 1)], tt)       # oo -> ee
    oo = formants(raw, [320, 760, 2300], [160, 220, 400], [1.0, 0.55, 0.2])
    ee = formants(raw, [300, 2300, 3000], [140, 300, 400], [1.0, 0.7, 0.35])
    y = oo * (1 - morph) + ee * morph
    y *= env(tt, 0.08, 0.5)
    return finish(reverb(underwater(y), decay_s=3.0, taps=8, rng=rng, wet=0.55), 0.5)

for name, fn in [("mermaid_siren_a", mermaid_siren_a), ("mermaid_siren_b", mermaid_siren_b),
                 ("mermaid_lure", mermaid_lure), ("mermaid_call", mermaid_call),
                 ("narwhal_clicks", narwhal_clicks), ("narwhal_whistle", narwhal_whistle), ("narwhal_knocks", narwhal_knocks),
                 ("unicorn_whinny", unicorn_whinny), ("unicorn_nicker", unicorn_nicker), ("unicorn_snort", unicorn_snort),
                 ("puppy_yip", puppy_yip), ("puppy_bark", puppy_bark), ("puppy_whine", puppy_whine),
                 ("mermaid_hum", mermaid_hum)]:
    write(name, fn())
