#!/usr/bin/env python3
"""Synthesizes the placeholder SFX and music loop into assets/audio/*.mp3.

Everything is generated from code (no samples), so the audio is original and
license-free. Replace the files with real audio at any time; names are the
contract (see lib/features/gameplay/audio/sfx.dart).

Usage: python3 tool/synth_audio.py   (needs numpy + ffmpeg with libmp3lame)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.2):
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    e[na:] *= np.exp(-np.arange(n - na) / (r * SR))
    return e


def tone(freq, d, kind="sine", a=0.005, r=0.2):
    x = t(d)
    if kind == "sine":
        w = np.sin(2 * np.pi * freq * x)
    elif kind == "tri":
        w = 2 * np.abs(2 * ((freq * x) % 1) - 1) - 1
    else:
        w = np.sin(2 * np.pi * freq * x) + 0.3 * np.sin(4 * np.pi * freq * x)
    return w * env(len(x), a, r)


def pluck(freq, d, decay=0.996):
    """Karplus-Strong plucked string (oud-like)."""
    n = int(SR * d)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = decay * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.001, d)


def noise(d, r=0.05, lp=0.2):
    n = int(SR * d)
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    for i in range(1, n):
        y[i] = y[i - 1] + lp * (x[i] - y[i - 1])
    return y * env(n, 0.001, r)


def mix(*parts):
    n = max(len(p) for _, p in parts)
    out = np.zeros(n)
    for offset, p in parts:
        start = int(offset * SR)
        end = min(n, start + len(p))
        if start >= n:
            out = np.concatenate([out, np.zeros(start + len(p) - n)])
            n = len(out)
            end = start + len(p)
        if end > len(out):
            out = np.concatenate([out, np.zeros(end - len(out))])
        out[start:end] += p[: end - start]
    return out


def save(name, x, gain=0.8, bitrate="96k"):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".mp3")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-codec:a",
         "libmp3lame", "-b:a", bitrate, dst],
        check=True,
    )
    os.unlink(path)
    print("wrote", dst, os.path.getsize(dst), "bytes")


def main():
    os.makedirs(OUT, exist_ok=True)
    save("tap", mix((0, noise(0.06, 0.015, 0.5)), (0, tone(1400, 0.06, r=0.02))), 0.5)
    save("pick", mix((0, tone(660, 0.12, "tri", r=0.06)), (0.03, tone(880, 0.1, r=0.05))), 0.5)
    save("drop", mix((0, noise(0.12, 0.04, 0.15)), (0, tone(220, 0.15, r=0.05))), 0.7)
    save("invalid", mix((0, tone(180, 0.18, "rich", r=0.08)), (0.07, tone(150, 0.18, "rich", r=0.08))), 0.5)
    save("complete", mix(*[(i * 0.07, pluck(f, 0.6)) for i, f in enumerate([523, 659, 784, 1046])]), 0.7)
    save("coin", mix((0, tone(1318, 0.25, r=0.1)), (0.06, tone(1760, 0.3, r=0.12))), 0.5)
    save("booster", mix(*[(i * 0.04, tone(800 + i * 220, 0.2, r=0.08)) for i in range(6)]), 0.5)
    save("button", tone(900, 0.05, "tri", r=0.015), 0.4)
    hijaz = [293.66, 311.13, 369.99, 392.0, 440.0, 466.16, 523.25, 587.33]
    win = [(i * 0.12, pluck(hijaz[k], 0.9)) for i, k in enumerate([0, 2, 4, 7, 6, 7])]
    win += [(0.75, tone(587.33, 0.9, r=0.4)), (0.75, tone(440, 0.9, r=0.4))]
    save("win", mix(*win), 0.75)
    save("restore", mix(*[(i * 0.09, pluck(hijaz[k] * 2, 0.7)) for i, k in enumerate([0, 3, 4, 7])]), 0.7)

    # Music: 16 bars of 4/4 at 92 bpm in D Hijaz, oud-like plucks + frame drum.
    beat = 60 / 92
    melody = [0, 2, 3, 4, 3, 2, 1, 0, 4, 5, 4, 3, 2, 3, 1, 0,
              4, 4, 5, 7, 6, 5, 4, 3, 2, 3, 4, 3, 2, 1, 0, 0]
    parts = []
    for i, k in enumerate(melody * 2):
        parts.append((i * beat, pluck(hijaz[k], beat * 1.8, 0.995) * 0.6))
    for bar in range(16):
        b0 = bar * 4 * beat
        parts.append((b0, pluck(hijaz[0] / 2, beat * 3.5, 0.997) * 0.5))
        parts.append((b0 + 2 * beat, pluck(hijaz[4] / 2, beat * 1.8, 0.997) * 0.4))
        for s, (amp, lp) in enumerate([(0.9, 0.08), (0.35, 0.5), (0.5, 0.25), (0.35, 0.5)]):
            parts.append((b0 + s * beat, noise(0.25, 0.08, lp) * amp))
    loop_len = int(16 * 4 * beat * SR)
    music = mix(*parts)
    tail = music[loop_len:]
    music = music[:loop_len]
    music[: len(tail)] += tail  # wrap the ring-out so the loop is seamless
    save("music_bazaar", music * 0.8, 0.55, "64k")


if __name__ == "__main__":
    main()
