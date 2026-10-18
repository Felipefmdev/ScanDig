"""Sons gerados e normalização do ScanDig (issue #123). Requer: pip install numpy scipy soundfile

  python tools/gen_audio.py gen                  -> escreve assets/audio/generated/*.ogg (cavar e passos
                                                     por superfície, arremesso, loops de ambiente e clima)
  python tools/gen_audio.py normalize <arquivos> -> normaliza .ogg/.wav no lugar (mono, alvo abaixo)
  python tools/gen_audio.py measure <arquivos>   -> imprime pico e RMS (das janelas com som)

Normalização (a mesma para os gerados e os da Kenney): RMS das janelas de 20 ms acima de -50 dB
levado a -18 dBFS (loops: -20), ganho entre -12 e +16 dB, pico limitado a -3 dBFS por um limitador
suave (no máximo 6 dB de redução). Rodar de novo é idempotente (ganho ~0).
Tudo é ruído filtrado e senos sintetizados aqui: sem amostras de terceiros (CC0, ver CREDITS.md).
Os loops têm a cauda cruzada no início, então emendam sem clique (import com loop=true).
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import ndimage, signal

SR = 22050
PEAK_DBFS = -3.0
RMS_ONESHOT = -18.0
RMS_LOOP = -20.0
LOOP_S = 24.0
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "generated")
rng = np.random.default_rng(123)


# --- Blocos ----------------------------------------------------------------------------

def white(n: int) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def pink(n: int) -> np.ndarray:
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1.0, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, white(n)) * 4.0


def brown(n: int) -> np.ndarray:
    x = signal.lfilter([1.0], [1.0, -0.995], white(n))
    return x / (np.abs(x).max() + 1e-9)


def band(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def high(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-4))


def lfo(n: int, rate: float, depth: float, seed_phase: float = 0.0) -> np.ndarray:
    """LFO lento e irregular (soma de dois senos) entre 1-depth e 1. Período inteiro no loop."""
    t = np.arange(n) / SR
    r1 = round(rate * LOOP_S) / LOOP_S
    r2 = round(rate * 1.618 * LOOP_S) / LOOP_S
    v = 0.6 * np.sin(2 * np.pi * r1 * t + seed_phase) + 0.4 * np.sin(2 * np.pi * r2 * t + 2.1 * seed_phase)
    return 1.0 - depth * (0.5 + 0.5 * v)


def place(dst: np.ndarray, src: np.ndarray, at: int, gain: float = 1.0) -> None:
    """Soma `src` em `dst` a partir de `at`, dando a volta (para loops)."""
    idx = (np.arange(len(src)) + at) % len(dst)
    np.add.at(dst, idx, src * gain)


def crunch(dur: float, density: float, f_lo: float, f_hi: float, decay: float) -> np.ndarray:
    """Micro-rajadas de ruído (2-8 ms) em passa-banda aleatória, densidade a decair: grãos a partir."""
    n = int(SR * dur)
    out = np.zeros(n)
    t = 0.0
    while t < dur:
        t += rng.exponential(1.0 / max(density * np.exp(-t / decay), 1.0))
        if t >= dur:
            break
        blen = int(SR * rng.uniform(0.002, 0.008))
        f0 = rng.uniform(f_lo, f_hi)
        burst = band(white(blen + 64), f0 / 1.4, f0 * 1.4)[64:] * np.hanning(blen)
        start = int(t * SR)
        end = min(n, start + blen)
        out[start:end] += burst[: end - start] * rng.uniform(0.3, 1.0) * np.exp(-t / (decay * 1.5))
    return out


def swish(dur: float, f0: float, f1: float, attack: float, decay: float = 0.0) -> np.ndarray:
    """Ruído rosa com passa-banda que desliza de f0 a f1 (em blocos de 10 ms)."""
    n = int(SR * dur)
    src = pink(n)
    out = np.zeros(n)
    blk = int(SR * 0.01)
    for s in range(0, n, blk):
        f = f0 + (f1 - f0) * s / n
        seg = band(src[max(0, s - 256): s + blk], f / 1.5, f * 1.5)
        out[s: s + blk] = seg[-len(out[s: s + blk]):]
    e = env_ad(n, attack, decay if decay > 0 else dur * 0.4)
    return out * e * np.hanning(n * 2)[n:] ** 0.3


def thud(dur: float, f: float) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t * (1.0 - 0.3 * t / dur)) * env_ad(n, 0.004, dur * 0.25)


def clinks(dur: float, count: int, f_lo: float, f_hi: float) -> np.ndarray:
    """Pedrinhas batendo: senos curtos com decaimento rápido."""
    n = int(SR * dur)
    out = np.zeros(n)
    for _ in range(count):
        ln = int(SR * rng.uniform(0.02, 0.05))
        t = np.arange(ln) / SR
        f = rng.uniform(f_lo, f_hi)
        ping = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t)) * np.exp(-t / 0.008)
        at = int(rng.uniform(0.0, dur * 0.6) * SR)
        end = min(n, at + ln)
        out[at:end] += ping[: end - at] * rng.uniform(0.2, 0.6)
    return out


def mix(n: int, *layers: tuple) -> np.ndarray:
    """layers: (sinal, ganho, atraso em s)."""
    out = np.zeros(n)
    for s, g, d in layers:
        at = int(d * SR)
        ln = min(len(s), n - at)
        if ln > 0:
            out[at: at + ln] += s[:ln] * g
    return out


# --- Normalização ----------------------------------------------------------------------

def measure(x: np.ndarray, sr: int) -> tuple:
    w = max(1, int(sr * 0.02))
    k = len(x) // w
    if k == 0:
        r = np.sqrt(np.mean(x ** 2))
    else:
        rw = np.sqrt(np.mean(x[: k * w].reshape(k, w) ** 2, axis=1))
        act = rw[rw > 10 ** (-50 / 20)]
        r = np.sqrt(np.mean(act ** 2)) if len(act) else np.sqrt(np.mean(x ** 2))
    pk = np.abs(x).max()
    return 20 * np.log10(max(pk, 1e-9)), 20 * np.log10(max(r, 1e-9))


def limit(x: np.ndarray, thr: float, sr: int) -> np.ndarray:
    """Limitador de pico simples: ataque instantâneo, release de 60 ms."""
    need = np.minimum(1.0, thr / np.maximum(np.abs(x), 1e-9))
    # olhar 1 ms à frente para o ganho já estar baixo quando o pico chega
    la = max(1, int(sr * 0.001))
    need = ndimage.minimum_filter1d(need, size=2 * la + 1)
    step = 1.0 / (sr * 0.06)
    g = np.empty_like(need)
    cur = 1.0
    for i in range(len(need)):
        cur = min(need[i], cur + step)
        g[i] = cur
    return x * g


def normalize(x: np.ndarray, sr: int, target_rms: float) -> np.ndarray:
    pk, rms = measure(x, sr)
    thr = 10 ** (PEAK_DBFS / 20)
    gain = float(np.clip(target_rms - rms, -12.0, 16.0))
    # no máximo 6 dB acima do que o pico permite (o resto o limitador segura)
    gain = min(gain, PEAK_DBFS - pk + 6.0)
    y = x * 10 ** (gain / 20)
    if np.abs(y).max() > thr:
        # sons muito transientes (grama, moedas) perdem mais no limitador do que ganham: aí
        # fica só o ganho até o pico
        plain = x * 10 ** ((PEAK_DBFS - pk) / 20)
        y = limit(y, thr, sr)
        if measure(y, sr)[1] < measure(plain, sr)[1]:
            y = plain
    return np.clip(y, -thr, thr)


def write_ogg(name: str, x: np.ndarray, loop: bool = False) -> str:
    y = normalize(x, SR, RMS_LOOP if loop else RMS_ONESHOT)
    if not loop:
        fade = min(len(y), int(SR * 0.012))
        y[-fade:] *= np.linspace(1.0, 0.0, fade)
    path = os.path.join(OUT, name)
    sf.write(path, y.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    return path


def make_loop(fn, xfade: float = 2.0) -> np.ndarray:
    """Gera LOOP_S + xfade e cruza a cauda sobre o início: emenda sem clique."""
    n = int(SR * LOOP_S)
    xf = int(SR * xfade)
    x = fn(n + xf)
    out = x[:n].copy()
    ramp = np.linspace(0.0, 1.0, xf)
    out[:xf] = out[:xf] * np.sqrt(ramp) + x[n: n + xf] * np.sqrt(1.0 - ramp)
    return out


# --- One-shots por superfície ----------------------------------------------------------

def dig(surface: str, careful: bool) -> np.ndarray:
    dur = 0.55 if careful else 0.4
    n = int(SR * dur)
    if surface == "dirt":
        # terra/grama: torrão úmido, mais grave e com corpo
        return mix(n, (crunch(dur, 260 if careful else 520, 350, 1500, 0.12), 1.0, 0.0),
                   (swish(dur * 0.8, 500, 900, 0.03), 0.6, 0.0),
                   (thud(0.18, 85.0), 0.0 if careful else 0.9, 0.0),
                   (high(swish(0.18, 2500, 1800, 0.01), 300), 0.25, 0.02))
    if surface == "snow":
        # neve: crocante e agudo (cristais), quase sem grave
        return mix(n, (crunch(dur, 500 if careful else 900, 1600, 5200, 0.1), 1.0, 0.0),
                   (high(swish(dur * 0.7, 3000, 2000, 0.02), 1200), 0.5, 0.0),
                   (thud(0.12, 120.0), 0.0 if careful else 0.35, 0.0))
    # pedra/cinza: cascalho com pedrinhas batendo
    return mix(n, (crunch(dur, 300 if careful else 600, 700, 3200, 0.12), 1.0, 0.0),
               (clinks(dur, 3 if careful else 7, 1800, 4200), 0.7, 0.0),
               (swish(dur * 0.7, 900, 600, 0.02), 0.4, 0.0),
               (thud(0.15, 95.0), 0.0 if careful else 0.7, 0.0))


def gravel_step() -> np.ndarray:
    """Passo em cascalho de basalto/cinza (Cratera)."""
    dur = 0.2
    n = int(SR * dur)
    return mix(n, (crunch(dur, 700, 700, 2600, 0.05), 1.0, 0.0),
               (clinks(dur, 2, 2000, 3800), 0.35, 0.0),
               (thud(0.08, 110.0), 0.4, 0.0))


def emerge() -> np.ndarray:
    """Criatura saindo da areia/terra: estouro de grãos + baque grave + terra a escorrer."""
    dur = 0.7
    n = int(SR * dur)
    return mix(n, (thud(0.35, rng.uniform(60, 80)), 1.0, 0.0),
               (crunch(0.6, 700, 500, 2600, 0.18), 0.9, 0.01),
               (swish(0.6, 700, 1600, 0.05, 0.25), 0.6, 0.05))


def whoosh(k: int) -> np.ndarray:
    dur = 0.28 + 0.04 * k
    n = int(SR * dur)
    x = swish(dur, 350 + 80 * k, 1500 - 120 * k, dur * 0.45, dur * 0.25)
    return x * np.sin(np.pi * np.arange(n) / n) ** 1.5


# --- Camadas de ambiente ---------------------------------------------------------------

def waves(n: int, period: float, calm: float) -> np.ndarray:
    """Ondas: base grave contínua + rebentações (sobe 1.5 s, espuma decai 3 s)."""
    base = low(pink(n), 350) * 0.35 * lfo(n, 1.0 / 12.0, 0.4, 0.3)
    surf = np.zeros(n)
    t = rng.uniform(0.0, 1.5)
    while t < n / SR:
        ln = int(SR * rng.uniform(4.0, 5.5))
        e = env_ad(ln, rng.uniform(1.2, 1.8), rng.uniform(1.2, 1.8) * (1.0 + calm))
        crash = low(pink(ln), 1400) * e * 0.7 + high(white(ln), 2500) * e ** 2 * 0.25 * (1.0 - calm)
        place(surf, crash, int(t * SR), rng.uniform(0.7, 1.0))
        t += period * rng.uniform(0.8, 1.2)
    return base + surf


def gull(dur: float = 0.38) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 1050 - 420 * (t / dur) ** 0.7 + 60 * np.sin(2 * np.pi * 7 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = sum(np.sin(ph * h) / h ** 1.2 for h in range(1, 7))
    rough = 1.0 + 0.5 * np.sin(2 * np.pi * 32 * t)
    return band(tone * rough, 700, 4000) * env_ad(n, 0.02, dur * 0.45)


def gulls(n: int, count: int) -> np.ndarray:
    out = np.zeros(n)
    for _ in range(count):
        at = rng.uniform(0.0, n / SR)
        reps = int(rng.integers(1, 4))
        for r in range(reps):
            place(out, gull(rng.uniform(0.3, 0.42)), int((at + r * 0.42) * SR), rng.uniform(0.25, 0.5))
    return out


def chirp(dur: float, f0: float, f1: float) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f0 + (f1 - f0) * np.sin(np.pi * t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / dur) ** 2


def birds(n: int, phrases: int) -> np.ndarray:
    out = np.zeros(n)
    for _ in range(phrases):
        at = rng.uniform(0.0, n / SR)
        base = rng.uniform(2800, 4800)
        for k in range(int(rng.integers(3, 7))):
            c = chirp(rng.uniform(0.04, 0.09), base, base * rng.uniform(1.15, 1.5))
            place(out, c, int((at + k * rng.uniform(0.08, 0.14)) * SR), rng.uniform(0.15, 0.35))
    return out


def crickets(n: int) -> np.ndarray:
    out = np.zeros(n)
    for f, period in ((4400.0, 0.62), (4950.0, 0.81)):
        t = rng.uniform(0.0, 0.5)
        while t < n / SR:
            for p in range(3):
                ln = int(SR * 0.014)
                tt = np.arange(ln) / SR
                place(out, np.sin(2 * np.pi * f * tt) * np.hanning(ln), int((t + p * 0.03) * SR), 0.22)
            t += period * rng.uniform(0.9, 1.1)
    return out


def breeze(n: int, lo: float, hi: float, depth: float) -> np.ndarray:
    return band(pink(n), lo, hi) * lfo(n, 1.0 / 8.0, depth, rng.uniform(0, 6))


def wind(n: int, lo: float, hi: float, gust: float, whistle: float) -> np.ndarray:
    """Vento: ruído em passa-banda com o centro varrido por um LFO lento + assobio estreito."""
    src = pink(n)
    blk = int(SR * 0.02)
    mod = lfo(n, 1.0 / 7.0, 1.0, rng.uniform(0, 6))
    out = np.zeros(n)
    wh = np.zeros(n)
    for s in range(0, n, blk):
        f = lo + (hi - lo) * mod[s]
        seg = src[max(0, s - 512): s + blk]
        out[s: s + blk] = band(seg, f / 1.6, f * 1.6)[-len(out[s: s + blk]):]
        wh[s: s + blk] = band(seg, f * 1.9, f * 2.05, 1)[-len(wh[s: s + blk]):]
    amp = lfo(n, 1.0 / 5.0, gust, rng.uniform(0, 6))
    return (out + wh * whistle * 3.0) * amp


def drips(n: int, count: int) -> np.ndarray:
    """Gotas em caverna: 'plip' que sobe de tom, com eco (dois atrasos com realimentação)."""
    dry = np.zeros(n)
    for _ in range(count):
        ln = int(SR * 0.07)
        t = np.arange(ln) / SR
        f0 = rng.uniform(700, 1300)
        f = f0 * (1.0 + 1.6 * (1.0 - np.exp(-t / 0.012)))
        d = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.018)
        place(dry, d, int(rng.uniform(0.0, n / SR) * SR), rng.uniform(0.3, 0.7))
    wet = dry.copy()
    for delay, g in ((0.23, 0.45), (0.41, 0.35), (0.67, 0.25)):
        wet += np.roll(low(dry, 2500), int(delay * SR)) * g
        wet += np.roll(low(dry, 1500), int(delay * 2.1 * SR)) * g * 0.5
    return wet


def rumble(n: int) -> np.ndarray:
    """Ronco grave da Cratera: ruído marrom passa-baixa + baques graves + borbulhar."""
    base = low(brown(n), 160, 4) * lfo(n, 1.0 / 9.0, 0.5, 1.0) * 1.2
    mid = band(pink(n), 120, 380) * 0.25 * lfo(n, 1.0 / 6.0, 0.6, 2.0)
    out = base + mid
    for _ in range(4):
        place(out, thud(1.4, rng.uniform(42, 60)), int(rng.uniform(0, n / SR) * SR), 0.5)
    for _ in range(14):
        ln = int(SR * 0.09)
        t = np.arange(ln) / SR
        f = rng.uniform(140, 260) * (1.0 + 0.8 * t / 0.09)
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.09)
        place(out, b, int(rng.uniform(0, n / SR) * SR), 0.12)
    return out


def rain(n: int) -> np.ndarray:
    """Chuva: chiado contínuo + milhares de gotinhas (cliques em passa-alta)."""
    hiss = band(pink(n), 900, 7000) * 0.5
    clicks = np.zeros(n)
    k = int(n / SR * 900)
    idx = rng.integers(0, n, k)
    clicks[idx] = rng.uniform(-1.0, 1.0, k) * rng.uniform(0.2, 1.0, k) ** 2
    drops = high(signal.lfilter([1.0], [1.0, -0.6], clicks), 1800) * 1.2
    return (hiss + drops) * lfo(n, 1.0 / 10.0, 0.2, 0.5)


def ash(n: int) -> np.ndarray:
    """Tempestade de cinzas: vento grave e áspero + grãos batendo."""
    w = wind(n, 180, 520, 0.6, 0.15)
    grit = np.zeros(n)
    k = int(n / SR * 220)
    grit[rng.integers(0, n, k)] = rng.uniform(-1, 1, k)
    return w + band(grit, 1500, 5000) * 0.6


AMBIENT = {
    "amb_praia_day.ogg": lambda n: waves(n, 7.0, 0.0) + gulls(n, 4),
    "amb_praia_night.ogg": lambda n: waves(n, 8.0, 0.3) + crickets(n) * 0.25,
    "amb_campo_day.ogg": lambda n: breeze(n, 250, 900, 0.6) * 0.5 + birds(n, 9),
    "amb_campo_night.ogg": lambda n: breeze(n, 200, 700, 0.6) * 0.35 + crickets(n),
    "amb_ruinas.ogg": lambda n: low(brown(n), 220) * 0.25 + drips(n, 14),
    "amb_geleira.ogg": lambda n: wind(n, 350, 1100, 0.7, 0.5),
    "amb_cratera.ogg": rumble,
    "amb_ilha.ogg": lambda n: waves(n, 9.0, 0.5) * 0.8 + gulls(n, 7) + breeze(n, 300, 1200, 0.5) * 0.2,
    "weather_rain.ogg": rain,
    "weather_blizzard.ogg": lambda n: wind(n, 600, 2200, 0.5, 0.8) + high(pink(n), 3000) * 0.3,
    "weather_ashstorm.ogg": ash,
}


def gen() -> None:
    os.makedirs(OUT, exist_ok=True)
    made: list[str] = []
    for surface in ("dirt", "snow", "stone"):
        for k in range(3):
            made.append(write_ogg("%s_dig_fast_%d.ogg" % (surface, k), dig(surface, False)))
        for k in range(2):
            made.append(write_ogg("%s_dig_careful_%d.ogg" % (surface, k), dig(surface, True)))
    for k in range(5):
        made.append(write_ogg("gravel_step_%d.ogg" % k, gravel_step()))
    for k in range(3):
        made.append(write_ogg("whoosh_%d.ogg" % k, whoosh(k)))
    for k in range(3):
        made.append(write_ogg("emerge_%d.ogg" % k, emerge()))
    for name, fn in AMBIENT.items():
        made.append(write_ogg(name, make_loop(fn), loop=True))
    report(made)


def normalize_files(paths: list[str]) -> None:
    for p in paths:
        d, sr = sf.read(p, always_2d=True)
        x = d.mean(axis=1)
        loop = os.path.basename(p).startswith(("amb_", "weather_"))
        y = normalize(x, sr, RMS_LOOP if loop else RMS_ONESHOT).astype(np.float32)
        if p.endswith(".ogg"):
            sf.write(p, y, sr, format="OGG", subtype="VORBIS")
        else:
            sf.write(p, y, sr, subtype="PCM_16")
    report(paths)


def report(paths: list[str]) -> None:
    print("%-30s %8s %8s %7s" % ("arquivo", "pico dB", "RMS dB", "dur s"))
    for p in paths:
        d, sr = sf.read(p, always_2d=True)
        pk, rms = measure(d.mean(axis=1), sr)
        print("%-30s %8.1f %8.1f %7.2f" % (os.path.basename(p), pk, rms, len(d) / sr))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "gen"
    if cmd == "gen":
        gen()
    elif cmd == "normalize":
        normalize_files(sys.argv[2:])
    elif cmd == "measure":
        report(sys.argv[2:])
    else:
        print(__doc__)
