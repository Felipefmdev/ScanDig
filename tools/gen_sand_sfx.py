"""Gera os sons de areia do ScanDig (issue #10) por síntese: ruído filtrado em passa-banda.

  python tools/gen_sand_sfx.py        -> escreve assets/audio/generated/sand_*.wav e imprime os níveis

Camadas:
  - "crunch": dezenas de micro-rajadas de ruído branco (2-8 ms) com passa-banda 1.5-4 kHz,
    densidade a decair -> grão de areia a partir-se;
  - "swish": ruído rosa com passa-banda 0.8-2.5 kHz e envelope lento -> terra a deslizar;
  - "thud" muito baixo (< 300 Hz, -18 dB relativo) só nas pazadas rápidas, para dar corpo
    sem virar "baque".
Tudo normalizado para pico -3 dBFS. Mono, 22 050 Hz, 16 bits.
"""
import math
import os
import random
import struct
import wave

SR = 22050
PEAK_DBFS = -3.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "generated")


class Biquad:
    """Passa-banda RBJ (ganho de pico constante 0 dB)."""

    def __init__(self, f0: float, q: float) -> None:
        w0 = 2 * math.pi * f0 / SR
        alpha = math.sin(w0) / (2 * q)
        a0 = 1 + alpha
        self.b0, self.b1, self.b2 = alpha / a0, 0.0, -alpha / a0
        self.a1, self.a2 = -2 * math.cos(w0) / a0, (1 - alpha) / a0
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x: float) -> float:
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def pink():
    b = [0.0] * 7
    while True:
        w = random.uniform(-1, 1)
        b[0] = 0.99886 * b[0] + w * 0.0555179
        b[1] = 0.99332 * b[1] + w * 0.0750759
        b[2] = 0.96900 * b[2] + w * 0.1538520
        b[3] = 0.86650 * b[3] + w * 0.3104856
        b[4] = 0.55000 * b[4] + w * 0.5329522
        b[5] = -0.7616 * b[5] - w * 0.0168980
        yield (sum(b) + w * 0.5362) * 0.11
        b[6] = w * 0.115926


def crunch(dur: float, density: float, f_lo: float, f_hi: float, decay: float) -> list[float]:
    n = int(SR * dur)
    out = [0.0] * n
    t = 0.0
    while t < dur:
        # densidade cai ao longo do som
        rate = density * math.exp(-t / decay)
        t += random.expovariate(max(rate, 1.0))
        if t >= dur:
            break
        start = int(t * SR)
        blen = int(SR * random.uniform(0.002, 0.008))
        bp = Biquad(random.uniform(f_lo, f_hi), random.uniform(1.2, 3.0))
        amp = random.uniform(0.3, 1.0) * math.exp(-t / (decay * 1.5))
        for i in range(blen):
            if start + i >= n:
                break
            e = math.sin(math.pi * i / blen)
            out[start + i] += bp(random.uniform(-1, 1)) * e * amp
    return out


def swish(dur: float, f0: float, f1: float, attack: float) -> list[float]:
    n = int(SR * dur)
    src = pink()
    out = []
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        bp = _swish_bp.setdefault(round(f, -1), Biquad(f, 0.9))
        env = min(1.0, t / attack) * (1 - t / dur) ** 1.6
        out.append(bp(next(src)) * env)
    return out


_swish_bp: dict = {}


def thud(dur: float, f: float) -> list[float]:
    n = int(SR * dur)
    return [math.sin(2 * math.pi * f * i / SR) * math.exp(-i / SR / 0.03) for i in range(n)]


def mix(*layers: tuple[list[float], float, float]) -> list[float]:
    """layers: (amostras, ganho, atraso em s)."""
    total = max(int(d * SR) + len(s) for s, g, d in layers)
    out = [0.0] * total
    for s, g, d in layers:
        off = int(d * SR)
        for i, v in enumerate(s):
            out[off + i] += v * g
    return out


def fade_out(s: list[float], ms: float = 15.0) -> list[float]:
    n = int(SR * ms / 1000)
    for i in range(min(n, len(s))):
        s[-1 - i] *= i / n
    return s


def write(name: str, s: list[float]) -> tuple[str, float, float]:
    s = fade_out(s)
    peak = max(abs(v) for v in s) or 1.0
    target = 10 ** (PEAK_DBFS / 20)
    s = [v / peak * target for v in s]
    rms = math.sqrt(sum(v * v for v in s) / len(s))
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in s))
    return name, 20 * math.log10(max(abs(v) for v in s)), 20 * math.log10(rms)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    random.seed(1312)
    report = []
    for k in range(3):
        _swish_bp.clear()
        s = mix(
            (crunch(0.32, 900, 1500, 4200, 0.09), 1.0, 0.0),
            (swish(0.38, 2400, 900, 0.015), 0.55, 0.01),
            (thud(0.12, 95 + 10 * k), 0.12, 0.0),
        )
        report.append(write("sand_dig_fast_%d.wav" % k, s))
    for k in range(2):
        _swish_bp.clear()
        s = mix(
            (crunch(0.5, 380, 1200, 3200, 0.2), 1.0, 0.02),
            (swish(0.55, 1600, 800, 0.08), 0.65, 0.0),
        )
        report.append(write("sand_dig_careful_%d.wav" % k, s))
    for k in range(2):
        _swish_bp.clear()
        # terra a sair da lâmina (swish) + chuva de grãos a cair (crunch espalhado)
        s = mix(
            (swish(0.35, 1200, 2600, 0.03), 0.7, 0.0),
            (crunch(0.45, 420, 1800, 4500, 0.25), 0.8, 0.18),
        )
        report.append(write("sand_throw_%d.wav" % k, s))
    for k in range(5):
        _swish_bp.clear()
        # passo: crunch curto e abafado, banda mais baixa, sem transiente forte
        s = mix(
            (crunch(0.16, 520, 900, 2400, 0.05), 1.0, 0.0),
            (swish(0.18, 1300, 700, 0.02), 0.45, 0.0),
        )
        report.append(write("sand_step_%d.wav" % k, s))
    print("%-26s %8s %8s" % ("ficheiro", "pico dB", "RMS dB"))
    for name, pk, rms in report:
        print("%-26s %8.1f %8.1f" % (name, pk, rms))


if __name__ == "__main__":
    main()
