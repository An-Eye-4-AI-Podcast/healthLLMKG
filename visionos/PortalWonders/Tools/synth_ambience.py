"""Procedural ambience beds for Portal Wonders. Deterministic, seamless loops, mono 44.1 kHz."""
import sys, os, wave, numpy as np

SR = 44100
LOOP = 40.0            # seconds in the final loop
XF = 3.0               # crossfade seconds used to make the loop seamless
N = int(SR * (LOOP + XF))
t = np.arange(N) / SR
out_dir = sys.argv[1]

# ------------------------------------------------------------------ utilities
def noise(rng, color="white"):
    w = rng.standard_normal(N)
    if color == "white":
        return w
    spec = np.fft.rfft(w)
    f = np.fft.rfftfreq(N, 1 / SR)
    f[0] = f[1]
    if color == "pink":
        spec /= np.sqrt(f)
    elif color == "brown":
        spec /= f
    x = np.fft.irfft(spec, N)
    return x / (np.abs(x).max() + 1e-9)

def bandpass(x, lo, hi, order=2.0):
    """Soft FFT bandpass with gentle skirts."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 * order)) * 1 / (1 + (f / hi) ** (2 * order))
    return np.fft.irfft(spec * g, len(x))

def lfo(rate_hz, phase=0.0, depth=1.0):
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * rate_hz * t + phase))

def envelope(length, attack, release):
    n = int(length * SR)
    e = np.ones(n)
    a = int(attack * SR); r = int(release * SR)
    if a: e[:a] = np.linspace(0, 1, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e

def place(buf, start_s, sig, gain=1.0):
    s = int(start_s * SR)
    e = min(s + len(sig), len(buf))
    if s < len(buf):
        buf[s:e] += sig[: e - s] * gain

def reverb(x, decay_s=1.5, taps=6, rng=None):
    """Cheap feedback-free reverb: a handful of decaying delayed copies."""
    y = x.copy()
    rng = rng or np.random.default_rng(1)
    for i in range(taps):
        d = int(SR * (0.05 + 0.12 * i + rng.uniform(0, 0.03)))
        g = np.exp(-(0.05 + 0.12 * i) / decay_s * 3) * 0.6
        y[d:] += x[:-d] * g
    return y

def make_loop(x):
    """Crossfade the tail into the head so the loop point is inaudible, then trim."""
    n_loop = int(LOOP * SR); n_xf = int(XF * SR)
    head = x[:n_xf]; tail = x[n_loop:n_loop + n_xf]
    fade = np.linspace(0, 1, n_xf)
    y = x[:n_loop].copy()
    y[:n_xf] = head * fade + tail * (1 - fade)
    return y

def finish(x, peak=0.5):
    x = x - x.mean()
    x = x / (np.abs(x).max() + 1e-9) * peak
    # soft limiter
    return np.tanh(x * 1.2) / np.tanh(1.2) * peak

def write(name, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(out_dir, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print("wrote", path, f"{LOOP:.0f}s")

# ------------------------------------------------------------------ trench
def trench():
    rng = np.random.default_rng(7)
    mix = np.zeros(N)
    # Abyssal pressure: brown noise rumble with a slow swell.
    mix += bandpass(noise(rng, "brown"), 20, 180) * 0.9 * lfo(0.05, depth=0.5)
    # Sub drone, slightly detuned partials that beat against each other.
    for f0, g in [(41, 0.25), (55.3, 0.18), (82, 0.10), (110.7, 0.06)]:
        mix += np.sin(2 * np.pi * f0 * t + rng.uniform(0, 6)) * g * lfo(0.03 + g, depth=0.6)
    # Whale-ish calls: slow downward glides with harmonics, washed in reverb.
    calls = np.zeros(N)
    for start in np.cumsum(rng.uniform(5, 11, 8)):
        dur = rng.uniform(1.2, 2.6)
        n = int(dur * SR); tt = np.arange(n) / SR
        f_start = rng.uniform(180, 320); f_end = f_start * rng.uniform(0.55, 0.8)
        freq = f_start * (f_end / f_start) ** (tt / dur)
        phase = 2 * np.pi * np.cumsum(freq) / SR
        sig = (np.sin(phase) + 0.4 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)) * envelope(dur, 0.35, 0.6)
        place(calls, start, sig, gain=rng.uniform(0.08, 0.16))
    mix += reverb(calls, decay_s=2.5, rng=rng)
    # Bubbles: short upward chirps, sparse, quiet.
    bub = np.zeros(N)
    for start in np.cumsum(rng.uniform(0.3, 1.4, 60)):
        dur = rng.uniform(0.04, 0.09); n = int(dur * SR); tt = np.arange(n) / SR
        f0 = rng.uniform(600, 1600)
        freq = f0 * (1 + 1.8 * tt / dur)
        sig = np.sin(2 * np.pi * np.cumsum(freq) / SR) * envelope(dur, 0.005, 0.03)
        place(bub, start, sig, gain=rng.uniform(0.01, 0.035))
    mix += bub
    # Faint sonar-like shimmer in the far distance.
    mix += bandpass(noise(rng, "pink"), 2000, 6000) * 0.012 * lfo(0.11, depth=0.9)
    return finish(make_loop(mix), peak=0.55)

# ------------------------------------------------------------------ valley
def valley():
    rng = np.random.default_rng(11)
    mix = np.zeros(N)
    # Breeze across the meadow: pink noise with two slow, out-of-phase swells.
    wind = bandpass(noise(rng, "pink"), 150, 1800)
    mix += wind * 0.35 * lfo(0.07, depth=0.7) * lfo(0.023, phase=1.3, depth=0.5)
    # Stream some way off: brighter noise, fluttering.
    mix += bandpass(noise(rng, "white"), 1500, 6000) * 0.05 * lfo(3.1, depth=0.4) * lfo(0.3, depth=0.3)
    # Songbirds: FM trills at random pitches.
    birds = np.zeros(N)
    for start in np.cumsum(rng.uniform(0.8, 3.2, 22)):
        notes = rng.integers(2, 6)
        for k in range(notes):
            dur = rng.uniform(0.07, 0.18); n = int(dur * SR); tt = np.arange(n) / SR
            f0 = rng.uniform(2200, 4800)
            freq = f0 * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(20, 45) * tt)) * (1 + rng.uniform(-0.15, 0.3) * tt / dur)
            sig = np.sin(2 * np.pi * np.cumsum(freq) / SR) * envelope(dur, 0.01, 0.04)
            place(birds, start + k * rng.uniform(0.09, 0.2), sig, gain=rng.uniform(0.03, 0.07))
    mix += reverb(birds, decay_s=0.8, rng=rng)
    # Enchanted chimes: slow pentatonic bells with long tails (the unicorn is near).
    bells = np.zeros(N)
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7]
    for start in np.cumsum(rng.uniform(1.5, 4.5, 12)):
        f0 = rng.choice(scale); dur = 3.5; n = int(dur * SR); tt = np.arange(n) / SR
        sig = (np.sin(2 * np.pi * f0 * tt) * np.exp(-tt * 1.4)
               + 0.35 * np.sin(2 * np.pi * f0 * 2.76 * tt) * np.exp(-tt * 3.5)
               + 0.15 * np.sin(2 * np.pi * f0 * 5.4 * tt) * np.exp(-tt * 6))
        place(bells, start, sig * envelope(dur, 0.003, 0.5), gain=rng.uniform(0.04, 0.09))
    mix += reverb(bells, decay_s=2.0, rng=rng)
    # Bees / insects: very quiet buzzing bed.
    mix += np.sin(2 * np.pi * 210 * t + 3 * np.sin(2 * np.pi * 0.9 * t)) * 0.006 * lfo(0.17, depth=0.9)
    return finish(make_loop(mix), peak=0.5)

# ------------------------------------------------------------------ den
def den():
    rng = np.random.default_rng(23)
    mix = np.zeros(N)
    # Room tone: low brown noise plus a faint fridge hum.
    mix += bandpass(noise(rng, "brown"), 30, 300) * 0.35
    mix += (np.sin(2 * np.pi * 60 * t) + 0.3 * np.sin(2 * np.pi * 120 * t)) * 0.02 * lfo(0.2, depth=0.2)
    # Wall clock: a tick every second, alternating tick/tock timbre.
    for i in range(int(LOOP + XF)):
        dur = 0.025; n = int(dur * SR)
        burst = bandpass(rng.standard_normal(n * 4), 1800 if i % 2 else 2600, 6000)[:n] * envelope(dur, 0.001, 0.02)
        place(mix, i + 0.5, burst, gain=0.09)
    # Afternoon birds outside, muffled by the window.
    birds = np.zeros(N)
    for start in np.cumsum(rng.uniform(1.5, 5, 12)):
        for k in range(rng.integers(2, 5)):
            dur = rng.uniform(0.08, 0.16); n = int(dur * SR); tt = np.arange(n) / SR
            f0 = rng.uniform(2000, 3800)
            freq = f0 * (1 + 0.2 * np.sin(2 * np.pi * rng.uniform(15, 35) * tt))
            sig = np.sin(2 * np.pi * np.cumsum(freq) / SR) * envelope(dur, 0.01, 0.04)
            place(birds, start + k * 0.15, sig, gain=0.03)
    mix += bandpass(birds, 300, 2600) * 0.6
    # Puppy breathing: soft, quick pants of filtered noise in short bouts.
    pant = np.zeros(N)
    for bout in np.cumsum(rng.uniform(6, 12, 5)):
        for k in range(rng.integers(6, 14)):
            dur = 0.12; n = int(dur * SR)
            burst = bandpass(rng.standard_normal(n * 2), 400, 2200)[:n] * envelope(dur, 0.02, 0.06)
            place(pant, bout + k * 0.27, burst, gain=rng.uniform(0.02, 0.04))
    mix += pant
    # The occasional fabric rustle as the pup shifts on the couch.
    for start in np.cumsum(rng.uniform(4, 9, 6)):
        dur = rng.uniform(0.3, 0.7); n = int(dur * SR)
        burst = bandpass(rng.standard_normal(n * 2), 800, 5000)[:n] * envelope(dur, 0.08, 0.2) * lfo(9, depth=0.6)[:n]
        place(mix, start, burst, gain=0.03)
    return finish(make_loop(mix), peak=0.45)

write("trench_ambience", trench())
write("valley_ambience", valley())
write("den_ambience", den())
