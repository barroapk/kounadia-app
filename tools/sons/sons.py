# Sons de notification KOUNADIA : 100 % synthétisés (aucun son existant).
# Usage : python3 tools/sons/sons.py <dossier de sortie>  (compilé à chaque fabrication de l'app)
import os, sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt
SR = 44100
rng = np.random.default_rng(11)
t_ = lambda d: np.arange(int(SR * d)) / SR
def lp(x, f): return sosfilt(butter(2, f, 'low', fs=SR, output='sos'), x)
def hp(x, f): return sosfilt(butter(2, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b): return sosfilt(butter(2, [a, b], 'band', fs=SR, output='sos'), x)
def place(buf, sig, at):
    i = int(at * SR); j = min(len(buf), i + len(sig)); buf[i:j] += sig[: j - i]
def bell(f, d, bright=1.0, decay=4.0):
    # cloche FM douce (rapport 3.5 → timbre de verre / vibraphone)
    t = t_(d); env = np.exp(-t * decay) * np.minimum(1, t / 0.004)
    idx = bright * 2.2 * np.exp(-t * 6)
    return np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t)) * env
def marimba(f, d):
    t = t_(d); env = np.exp(-t * 7) * np.minimum(1, t / 0.002)
    return (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 25)) * env
def brass(freqs, d, cutoff=2600):
    t = t_(d); x = np.zeros(len(t))
    for f in freqs:
        for det in (-0.003, 0.003):
            ph = 2 * np.pi * f * (1 + det) * t
            x += sum(np.sin(k * ph) / k for k in range(1, 14))
    env = np.minimum(1, t / 0.012) * np.exp(-t * 2.2)
    swell = lp(x, cutoff) * env
    return swell / (np.max(np.abs(swell)) + 1e-9)
def reverb(x, mix=0.25):
    out = x.copy()
    for dl, g in ((0.029, .5), (0.047, .4), (0.071, .32), (0.103, .25), (0.149, .18), (0.211, .12)):
        k = int(dl * SR); y = np.zeros_like(x); y[k:] = x[:-k] * g; out += mix * lp(y, 5000)
    return out
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
os.makedirs(OUT, exist_ok=True)
def finish(x, name, tail=0.25):
    x = np.concatenate([x, np.zeros(int(SR * tail))])
    x = reverb(x)
    # Plus fort : présence (2-4 kHz) renforcée, puis volume moyen relevé avec un limiteur doux (sans saturer).
    x = x + 0.35 * bp(x, 1800, 4200)
    x = x / np.max(np.abs(x))
    rms = np.sqrt(np.mean(x[np.abs(x) > 0.02] ** 2)) + 1e-9
    g = min(2.2, 0.30 / rms)
    x = np.tanh(x * g * 1.3) / np.tanh(g * 1.3)
    x = x / np.max(np.abs(x)) * 0.97
    n = int(SR * 0.03); x[-n:] *= np.linspace(1, 0, n)
    wavfile.write(os.path.join(OUT, name + '.wav'), SR, (x * 32767).astype(np.int16)); print(name, round(len(x) / SR, 2), 's')

# 1. BUT : deux coups de cuivres « ta-DAAA » + clameur de stade + cymbale
b = np.zeros(int(SR * 1.7))
place(b, brass([261.6, 329.6, 392.0], 0.16) * 0.8, 0.00)
place(b, brass([349.2, 440.0, 523.3, 698.5], 1.2, 3400), 0.17)
crowd = bp(rng.standard_normal(int(SR * 1.5)), 400, 2600)
ce = np.minimum(1, t_(1.5) / 0.25) * np.exp(-t_(1.5) * 1.6)
place(b, crowd * ce * 0.35, 0.12)
cym = hp(rng.standard_normal(int(SR * 1.0)), 6000) * np.exp(-t_(1.0) * 4) * 0.25
place(b, cym, 0.17)
kick = np.sin(2 * np.pi * np.cumsum(50 + 90 * np.exp(-t_(0.3) * 30)) / SR) * np.exp(-t_(0.3) * 9)
place(b, kick * 0.9, 0.17)
finish(b, 'k_goal')

# 2. FIN DU MATCH : vrai sifflet d'arbitre à bille (court, court, long), écho du stade, puis applaudissements
def whistle(d, f0=3050):
    t = t_(d); n = len(t)
    # La bille qui tourne : vibration rapide et irrégulière de la hauteur et du volume (≈ 30 fois par seconde).
    rate = 30 + 4 * np.cumsum(rng.standard_normal(n)) / np.sqrt(n * 40)
    ph = 2 * np.pi * np.cumsum(rate) / SR
    pea = np.sin(ph) + 0.3 * np.sin(2 * ph + 1.3)
    rise = 1 - 0.12 * np.exp(-t / 0.025)                        # attaque : la note monte vite
    fall = 1 - 0.05 * np.clip((t - (d - 0.05)) / 0.05, 0, 1)     # fin : la note retombe un peu
    f = f0 * rise * fall * (1 + 0.035 * pea)
    p = 2 * np.pi * np.cumsum(f) / SR
    am = 1 - 0.45 * (0.5 + 0.5 * pea)
    x = np.sin(p) + 0.22 * np.sin(2 * p + 0.4) + 0.06 * np.sin(3 * p)
    breath = bp(rng.standard_normal(n), f0 * 0.8, f0 * 1.25) * 0.35 + hp(rng.standard_normal(n), 5000) * 0.08
    env = np.minimum(1, t / 0.012) * np.minimum(1, (d - t) / 0.04)
    env *= 1 + 0.08 * np.sin(2 * np.pi * t / max(d, 0.3))   # souffle naturel
    return (x * am + breath) * env
def stadium(x):
    # écho des tribunes (grand espace ouvert)
    out = x.copy()
    for dl, g in ((0.09, .30), (0.16, .22), (0.24, .16), (0.35, .10), (0.48, .06)):
        k = int(dl * SR); y = np.zeros_like(x); y[k:] = x[:-k] * g; out += lp(y, 3500)
    return out
f = np.zeros(int(SR * 2.4))
place(f, whistle(0.17), 0.00); place(f, whistle(0.17), 0.30); place(f, whistle(0.85), 0.60)
f = stadium(f)
# applaudissements et clameur qui montent après le coup de sifflet
nA = int(SR * 1.3); tA = t_(1.3)
claps = np.zeros(nA)
for k in range(260):
    at = int(rng.uniform(0, 1.25) * SR); L = int(0.012 * SR)
    burst = bp(rng.standard_normal(L), rng.uniform(900, 1600), 4200) * np.exp(-np.arange(L) / (0.003 * SR))
    claps[at:at + L] += burst[: max(0, min(L, nA - at))] * rng.uniform(0.4, 1)
roar = bp(rng.standard_normal(nA), 300, 2200)
envA = np.minimum(1, tA / 0.35) * np.exp(-np.maximum(0, tA - 0.5) * 2.2)
place(f, (claps * 0.5 + roar * 0.35) * envA * 0.55, 1.05)
finish(f, 'k_fulltime', tail=0.15)

# 3. COUP SÛR VALIDÉ : deux notes de cristal montantes (quinte) + éclat
s = np.zeros(int(SR * 1.1))
place(s, bell(1318.5, 0.9, 0.8, 5) * 0.6, 0.00)
place(s, bell(1975.5, 1.0, 0.9, 4) * 0.7, 0.12)
place(s, bell(2637.0, 0.6, 0.5, 6) * 0.25, 0.12)
finish(s, 'k_sure_won')

# 4. COUPON VALIDÉ : arpège joyeux (do-mi-sol-do) + pluie de pièces scintillantes
c = np.zeros(int(SR * 1.8))
for i, fr in enumerate((523.3, 659.3, 784.0, 1046.5)):
    place(c, marimba(fr, 0.7) * 0.55, i * 0.085)
    place(c, bell(fr * 2, 0.8, 0.6, 5) * 0.22, i * 0.085)
for k in range(16):
    at = 0.34 + k * 0.045 + rng.uniform(0, 0.02)
    place(c, bell(rng.uniform(3200, 5200), 0.25, 0.4, 14) * 0.12 * (1 - k / 18), at)
place(c, bell(1046.5, 1.3, 0.7, 2.6) * 0.45, 0.34)
place(c, bell(1568.0, 1.3, 0.7, 2.6) * 0.3, 0.34)
finish(c, 'k_coupon_won')

# 5. COUPONS / COUPS SÛRS DISPONIBLES : « ding-dong-ding » doux et chaleureux
d = np.zeros(int(SR * 1.2))
for at, fr, g in ((0.0, 784.0, 0.55), (0.16, 1174.7, 0.5), (0.32, 1568.0, 0.42)):
    place(d, marimba(fr, 0.8) * g, at); place(d, bell(fr, 0.8, 0.35, 5) * g * 0.35, at)
finish(d, 'k_tips')
