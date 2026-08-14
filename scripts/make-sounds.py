#!/usr/bin/env python3
"""Generate amtrino's notification sounds (pure stdlib — no numpy).

Output: Sources/AmtrBar/Resources/Sounds/*.wav — 44.1 kHz, 16-bit mono,
each under 2.5 s. The wavs are COMMITTED; this script is how they were
made and how they change. Design goal: soothing — soft attacks, warm
near-harmonic partials, long exponential decays, a whisper of echo.

Usage: python3 scripts/make-sounds.py
"""

import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..",
                   "Sources", "AmtrBar", "Resources", "Sounds")


def buf(seconds):
    return [0.0] * int(RATE * seconds)


def add_tone(b, freq, t0, amp, tau, partials, attack=0.02, detune_cents=0.0):
    """One struck-mallet tone summed into b.

    partials: [(ratio, level)] relative to the fundamental. Each partial
    decays faster than the fundamental (tau / ratio^0.8) — the physical
    behavior that reads as 'warm' instead of 'electronic'.
    """
    start = int(t0 * RATE)
    f = freq * (2.0 ** (detune_cents / 1200.0))
    length = min(len(b) - start, int((attack + tau * 6) * RATE))
    for n in range(max(0, length)):
        t = n / RATE
        # raised-cosine attack, then exponential decay
        env = 0.5 - 0.5 * math.cos(math.pi * t / attack) if t < attack \
            else math.exp(-(t - attack) / tau)
        s = 0.0
        for ratio, level in partials:
            s += level * math.exp(-(t / tau) * (ratio ** 0.8 - 1.0)) \
                * math.sin(2.0 * math.pi * f * ratio * t)
        b[start + n] += amp * env * s


def echo(b, taps=((0.09, 0.14), (0.19, 0.07), (0.31, 0.035))):
    """A whisper of room: a few quiet delayed copies of the dry signal."""
    dry = list(b)
    for delay, gain in taps:
        d = int(delay * RATE)
        for n in range(d, len(b)):
            b[n] += gain * dry[n - d]


def finish(b, peak):
    """Normalize to `peak` and fade the tail so the file ends at silence."""
    m = max(abs(x) for x in b) or 1.0
    fade = int(0.15 * RATE)
    out = []
    for n, x in enumerate(b):
        g = peak / m
        left = len(b) - n
        if left < fade:
            g *= left / fade
        out.append(x * g)
    return out


def write(name, b):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767))
            for x in b))
    print(f"wrote {path} ({len(b) / RATE:.2f}s)")


KALIMBA = [(1.0, 1.0), (2.0, 0.28), (3.01, 0.10), (4.2, 0.035)]
MARIMBA = [(1.0, 1.0), (3.98, 0.16), (9.1, 0.04)]
PURE = [(1.0, 1.0), (2.0, 0.12)]


def calm():
    """Soft chime — the default. ONE gentle kalimba note (F#4), doubled a
    few cents apart for warmth. (Was a two-note fifth; the second note
    got cut 2026-08-14 — one tone reads calmer.)"""
    b = buf(1.8)
    for cents, a in ((0.0, 1.0), (2.5, 0.4)):
        add_tone(b, 369.99, 0.00, 1.00 * a, 0.48, KALIMBA,
                 detune_cents=cents)
    echo(b)
    return finish(b, 0.42)


def bloom():
    """A quiet rising D-major arpeggio in near-sine tones — the softest
    of the three."""
    b = buf(2.3)
    for freq, t0, amp in ((293.66, 0.00, 0.95), (440.00, 0.14, 0.85),
                          (739.99, 0.30, 0.70)):
        add_tone(b, freq, t0, amp, 0.55, PURE, attack=0.035)
        add_tone(b, freq, t0, amp * 0.35, 0.55, PURE, attack=0.035,
                 detune_cents=3.0)
    echo(b)
    return finish(b, 0.38)


def wood():
    """One warm low marimba note (A3) with a faint octave shimmer —
    the least melodic, most neutral option."""
    b = buf(2.0)
    add_tone(b, 220.0, 0.0, 1.0, 0.65, MARIMBA)
    add_tone(b, 220.0, 0.0, 0.4, 0.65, MARIMBA, detune_cents=2.0)
    add_tone(b, 440.0, 0.06, 0.22, 0.5, PURE, attack=0.03)
    echo(b)
    return finish(b, 0.42)


if __name__ == "__main__":
    write("calm.wav", calm())
    write("bloom.wav", bloom())
    write("wood.wav", wood())
