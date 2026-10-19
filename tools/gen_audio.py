"""Sons gerados e normalização do ScanDig (issue #123). Requer: pip install numpy scipy soundfile

  python tools/gen_audio.py gen [nomes]          -> escreve assets/audio/generated/*.ogg (cavar e passos
                                                     por superfície, arremesso, loops de ambiente e clima)
                                                     e gull_caw/gull_dive/spray_hiss.wav; com nomes, só eles
  python tools/gen_audio.py normalize <arquivos> -> normaliza .ogg/.wav no lugar (mono, alvo abaixo)
  python tools/gen_audio.py measure <arquivos>   -> imprime pico e RMS (das janelas com som)
  python tools/gen_audio.py loop <gravação> <nome.ogg> -> gravação de terceiros (CC0) vira loop:
                                                     mono, SR, cauda cruzada no início, normalizada
  python tools/gen_audio.py beach <ondas gravadas...> -> amb_praia_day/night e amb_ilha com as
                                                     rebentações gravadas (CC0) por cima do sintético
  python tools/gen_audio.py clip <gravação> <início s> <fim s> <nome.ogg> [semitons]
                                                  -> trecho de gravação (CC0) vira one-shot normalizado

Normalização (a mesma para os gerados e os da Kenney): RMS das janelas de 20 ms acima de -50 dB
levado a -18 dBFS (loops: -20), ganho entre -12 e +16 dB, pico limitado a -3 dBFS por um limitador
suave (no máximo 6 dB de redução). Rodar de novo é idempotente (ganho ~0).
Tudo é ruído filtrado e senos sintetizados aqui, menos o que vem de gravação CC0 (autor, link e o
comando exato em CREDITS.md): weather_rain/weather_blizzard (`loop`), as rebentações da Praia e da
Ilha (`beach`) e as vozes de corvo, morcego e lobo (`clip`).
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


def write_wav(name: str, x: np.ndarray) -> str:
    y = normalize(x, SR, RMS_ONESHOT)
    fade = min(len(y), int(SR * 0.012))
    y[-fade:] *= np.linspace(1.0, 0.0, fade)
    path = os.path.join(OUT, name)
    sf.write(path, y.astype(np.float32), SR, subtype="PCM_16")
    return path


def write_ogg(name: str, x: np.ndarray, loop: bool = False) -> str:
    y = normalize(x, SR, RMS_LOOP if loop else RMS_ONESHOT)
    if not loop:
        fade = min(len(y), int(SR * 0.012))
        y[-fade:] *= np.linspace(1.0, 0.0, fade)
    path = os.path.join(OUT, name)
    write_vorbis(path, y, SR)
    return path


def write_vorbis(path: str, y: np.ndarray, sr: int) -> None:
    """Em blocos: o libsndfile 1.2 quebra ao gravar um .ogg longo (>~30 s) de uma vez."""
    with sf.SoundFile(path, "w", sr, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(y), 4096):
            f.write(y[i: i + 4096].astype(np.float32))


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


def gull_dive() -> np.ndarray:
    """Gaivota mergulhando: grito que desce de tom sobre um assobio de ar."""
    dur = 0.7
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 1300 - 700 * t / dur
    tone = sum(np.sin(2 * np.pi * np.cumsum(f * h) / SR) / h ** 1.3 for h in range(1, 6))
    cry = band(tone * (1.0 + 0.4 * np.sin(2 * np.pi * 28 * t)), 600, 4000) * env_ad(n, 0.05, 0.3)
    air = whoosh(2)
    return cry + np.pad(air, (0, max(0, n - len(air))))[:n] * 0.6


def spray_hiss() -> np.ndarray:
    """Spray: chiado de ar em passa-alta com ataque rápido."""
    dur = 0.6
    n = int(SR * dur)
    return high(band(white(n), 2500, 9000), 2000) * env_ad(n, 0.015, 0.35) * np.hanning(n * 2)[n:] ** 0.2


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


def ash(n: int) -> np.ndarray:
    """Tempestade de cinzas: vento grave e áspero + grãos batendo."""
    w = wind(n, 180, 520, 0.6, 0.15)
    grit = np.zeros(n)
    k = int(n / SR * 220)
    grit[rng.integers(0, n, k)] = rng.uniform(-1, 1, k)
    return w + band(grit, 1500, 5000) * 0.6


def creak(dur: float) -> np.ndarray:
    """Rangido de madeira (stick-slip): trem de estalos cuja taxa sobe e desce, cada estalo
    excitando ressonâncias de tábua (senos amortecidos)."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = rng.uniform(35, 60)
    rate = f0 * (1.0 + rng.uniform(0.8, 1.8) * np.sin(np.pi * t / dur) ** 1.5)
    ph = np.cumsum(rate) / SR
    clicks = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    clicks[idx] = rng.uniform(0.5, 1.0, len(idx))
    rl = int(SR * 0.03)
    rt = np.arange(rl) / SR
    res = sum(np.sin(2 * np.pi * f * rt) * np.exp(-rt / d) * g
              for f, d, g in ((rng.uniform(380, 520), 0.010, 1.0), (rng.uniform(900, 1200), 0.006, 0.6),
                              (rng.uniform(1900, 2400), 0.003, 0.3)))
    out = signal.fftconvolve(clicks, res)[:n]
    return out * np.sin(np.pi * t / dur) ** 0.7


def tent(n: int) -> np.ndarray:
    """Base (acampamento): brisa suave + lona mexendo + a madeira da tenda a ranger de vez em quando."""
    air = breeze(n, 180, 650, 0.6) * 0.45
    canvas = band(pink(n), 90, 300) * 0.25 * lfo(n, 1.0 / 6.0, 0.8, rng.uniform(0, 6))
    wood = np.zeros(n)
    for _ in range(5):
        at = rng.uniform(0.0, n / SR)
        for r in range(int(rng.integers(1, 3))):
            place(wood, creak(rng.uniform(0.35, 0.8)), int((at + r * rng.uniform(0.6, 1.1)) * SR), rng.uniform(0.05, 0.1))
    return air + canvas + wood


def load_mono(src: str) -> np.ndarray:
    """Gravação (wav/ogg/flac/mp3) -> mono no SR do jogo."""
    d, sr = sf.read(src, always_2d=True)
    x = d.mean(axis=1)
    return signal.resample_poly(x, SR, sr) if sr != SR else x


def rec_waves(n: int, period: float, calm: float, shots: list) -> np.ndarray:
    """Como waves(), mas cada rebentação leva por cima uma onda gravada (CC0) e a sintética fica
    só como cauda de espuma e corpo grave."""
    base = low(pink(n), 350) * 0.35 * lfo(n, 1.0 / 12.0, 0.4, 0.3)
    surf = np.zeros(n)
    t = rng.uniform(0.0, 1.5)
    while t < n / SR:
        ln = int(SR * rng.uniform(4.0, 5.5))
        e = env_ad(ln, rng.uniform(1.2, 1.8), rng.uniform(1.2, 1.8) * (1.0 + calm))
        crash = low(pink(ln), 900) * e * 0.35
        place(surf, crash, int(t * SR), rng.uniform(0.7, 1.0))
        shot = shots[int(rng.integers(0, len(shots)))]
        if calm > 0.0:
            shot = low(shot, 3000 - 1800 * calm)
        place(surf, shot, int((t + rng.uniform(0.2, 0.6)) * SR), rng.uniform(0.75, 1.0) * (1.0 - 0.4 * calm))
        t += period * rng.uniform(0.8, 1.2)
    return base + surf


def wave_shots(paths: list[str]) -> list:
    """Ondas gravadas -> one-shots: 30 ms de entrada, 0.8 s de saída, RMS igualado entre elas e
    estalos (pico > 12 dB acima do RMS) segurados pelo limitador."""
    shots = []
    for p in paths:
        x = high(load_mono(p), 40)
        fi, fo = int(SR * 0.03), int(SR * 0.8)
        x[:fi] *= np.linspace(0.0, 1.0, fi)
        x[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
        x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * 0.22
        shots.append(limit(x, 0.22 * 4.0, SR))
    return shots


AMBIENT = {
    "amb_campo_day.ogg": lambda n: breeze(n, 250, 900, 0.6) * 0.5 + birds(n, 9),
    "amb_campo_night.ogg": lambda n: breeze(n, 200, 700, 0.6) * 0.35 + crickets(n),
    "amb_ruinas.ogg": lambda n: low(brown(n), 220) * 0.25 + drips(n, 14),
    "amb_geleira.ogg": lambda n: wind(n, 350, 1100, 0.7, 0.5),
    "amb_cratera.ogg": rumble,
    "weather_ashstorm.ogg": ash,
    "amb_base.ogg": tent,
}
## Praia e Ilha: rebentações gravadas (comando `beach`), por cima das camadas sintéticas.
BEACH = {
    "amb_praia_day.ogg": lambda n, s: rec_waves(n, 7.0, 0.0, s) + gulls(n, 4),
    "amb_praia_night.ogg": lambda n, s: rec_waves(n, 8.0, 0.3, s) + crickets(n) * 0.25,
    "amb_ilha.ogg": lambda n, s: rec_waves(n, 9.0, 0.5, s) * 0.8 + gulls(n, 7) + breeze(n, 300, 1200, 0.5) * 0.2,
}


def gen(only: list[str]) -> None:
    """Sem nomes: tudo. Com nomes (ex.: amb_base.ogg): só esses arquivos."""
    os.makedirs(OUT, exist_ok=True)
    made: list[str] = []

    def want(name: str) -> bool:
        return not only or name in only

    for surface in ("dirt", "snow", "stone"):
        for k in range(3):
            if want("%s_dig_fast_%d.ogg" % (surface, k)):
                made.append(write_ogg("%s_dig_fast_%d.ogg" % (surface, k), dig(surface, False)))
        for k in range(2):
            if want("%s_dig_careful_%d.ogg" % (surface, k)):
                made.append(write_ogg("%s_dig_careful_%d.ogg" % (surface, k), dig(surface, True)))
    for k in range(5):
        if want("gravel_step_%d.ogg" % k):
            made.append(write_ogg("gravel_step_%d.ogg" % k, gravel_step()))
    for k in range(3):
        if want("whoosh_%d.ogg" % k):
            made.append(write_ogg("whoosh_%d.ogg" % k, whoosh(k)))
    for k in range(3):
        if want("emerge_%d.ogg" % k):
            made.append(write_ogg("emerge_%d.ogg" % k, emerge()))
    for name, fn in AMBIENT.items():
        if want(name):
            made.append(write_ogg(name, make_loop(fn), loop=True))
    # criaturas e spray (antes sem script de origem; mesmos nomes de arquivo)
    for name, fn in (("gull_caw.wav", lambda: gull(0.6)), ("gull_dive.wav", gull_dive), ("spray_hiss.wav", spray_hiss)):
        if want(name):
            made.append(write_wav(name, fn()))
    report(made)


def beach(paths: list[str]) -> None:
    shots = wave_shots(paths)
    report([write_ogg(name, make_loop(lambda n, f=fn: f(n, shots)), loop=True) for name, fn in BEACH.items()])


def clip_file(src: str, start: float, end: float, name: str, semitones: float = 0.0) -> None:
    """Gravação -> one-shot: trecho [start, end] s, mono, tom deslocado (muda a duração junto),
    entrada de 5 ms e saída de 60 ms, normalizado como os outros one-shots."""
    x = load_mono(src)
    x = high(x[int(start * SR): int(end * SR)], 60)
    if semitones != 0.0:
        ratio = 2.0 ** (semitones / 12.0)
        up, down = int(round(1000 / ratio)), 1000
        x = signal.resample_poly(x, up, down)
    fi, fo = int(SR * 0.005), min(len(x) // 2, int(SR * 0.06))
    x[:fi] *= np.linspace(0.0, 1.0, fi)
    x[-fo:] *= np.linspace(1.0, 0.0, fo)
    report([write_ogg(name, x)])


def loop_file(src: str, name: str, xfade: float = 2.0) -> None:
    """Gravação -> loop do jogo: a cauda (xfade s) cruzada sobre o início, como em make_loop."""
    d, sr = sf.read(src, always_2d=True)
    x = signal.resample_poly(d.mean(axis=1), SR, sr) if sr != SR else d.mean(axis=1)
    xf = int(SR * xfade)
    n = len(x) - xf
    out = x[:n].copy()
    ramp = np.linspace(0.0, 1.0, xf)
    out[:xf] = out[:xf] * np.sqrt(ramp) + x[n:] * np.sqrt(1.0 - ramp)
    report([write_ogg(name, out, loop=True)])


def normalize_files(paths: list[str]) -> None:
    for p in paths:
        d, sr = sf.read(p, always_2d=True)
        x = d.mean(axis=1)
        loop = os.path.basename(p).startswith(("amb_", "weather_"))
        y = normalize(x, sr, RMS_LOOP if loop else RMS_ONESHOT).astype(np.float32)
        if p.endswith(".ogg"):
            write_vorbis(p, y, sr)
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
        gen(sys.argv[2:])
    elif cmd == "normalize":
        normalize_files(sys.argv[2:])
    elif cmd == "loop":
        loop_file(sys.argv[2], sys.argv[3])
    elif cmd == "beach":
        beach(sys.argv[2:])
    elif cmd == "clip":
        clip_file(sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5],
                  float(sys.argv[6]) if len(sys.argv) > 6 else 0.0)
    elif cmd == "measure":
        report(sys.argv[2:])
    else:
        print(__doc__)
