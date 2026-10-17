"""
Real-time black hole renderer (numpy).

Approach
--------
1. ONE-TIME (cached on disk): trace a light ray for every pixel through the
   Schwarzschild metric (orbit equation  u'' + u = 3 M u^2,  u = 1/r, M = 1).
   For each ray we record
     * every crossing of the (tilted) accretion-disk plane  -> radius, azimuth,
       relativistic Doppler / gravitational-redshift factor g
     * the direction it finally escapes to                  -> lensed starfield
     * whether it fell into the event horizon               -> true black shadow
   This produces genuine gravitational lensing: the far side of the disk bends
   over the shadow, the near side bends underneath it, and the photon ring
   appears from the higher-order images.

2. EVERY FRAME (a few ms): look up an animated polar disk texture through the
   cached maps.  The texture rotates differentially (Kepler: inner faster than
   outer), so the lensing stays physically consistent while the plasma moves.

Everything is rendered in grayscale.
"""
from __future__ import annotations

import math
import os
import time
from dataclasses import dataclass

import numpy as np

F32 = np.float32


@dataclass(frozen=True)
class Params:
    width: int = 1000
    height: int = 600
    cam_dist: float = 42.0      # observer radius (in M)
    elevation_deg: float = 2.7  # camera height above the disk plane
    roll_deg: float = -6.5      # screen roll: disk tilts down toward the LEFT
    tan_half_w: float = 0.45    # horizontal half field-of-view (tangent)
    r_in: float = 6.0           # ISCO of a Schwarzschild hole
    r_out: float = 27.0
    spin: float = 1.0           # -1: approaching (bright) side on the left
    dphi: float = 0.014
    max_phi: float = 3.7 * math.pi
    version: int = 8

    def key(self) -> str:
        return (f"bh{self.version}_{self.width}x{self.height}_{self.cam_dist:g}_"
                f"{self.elevation_deg:g}_{self.roll_deg:g}_{self.tan_half_w:g}_"
                f"{self.r_in:g}_{self.r_out:g}_{self.spin:g}_{self.dphi:g}")


# --------------------------------------------------------------------------- #
#  Starfield (sparse, mostly black space)                                      #
# --------------------------------------------------------------------------- #
def make_starmap(seed: int = 7, w: int = 4096, h: int = 2048, n: int = 1500) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w), np.float32)
    # uniform on the sphere
    lon = rng.uniform(0, w, n)
    lat = np.arccos(rng.uniform(-1, 1, n))          # 0..pi
    y = lat / math.pi * (h - 1)
    mag = rng.pareto(2.2, n) * 0.18 + 0.05           # mostly dim, a few bright
    mag = np.clip(mag, 0.05, 1.6)
    for xi, yi, m in zip(lon, y, mag):
        sig = 0.9 + 0.5 * min(m, 1.0)
        r = int(3 * sig) + 1
        x0, y0 = int(xi), int(yi)
        ys = np.arange(max(y0 - r, 0), min(y0 + r + 1, h))
        xs = np.arange(x0 - r, x0 + r + 1)
        gy = np.exp(-((ys[:, None] - yi) ** 2) / (2 * sig * sig))
        gx = np.exp(-((xs[None, :] - xi) ** 2) / (2 * sig * sig))
        img[np.ix_(ys, xs % w)] += (m * gy * gx).astype(np.float32)
    # faint diffuse band for depth (very subtle)
    xx = np.linspace(0, 2 * math.pi, w, endpoint=False)[None, :]
    yy = np.linspace(-1, 1, h)[:, None]
    band = np.exp(-((yy - 0.25 * np.sin(xx * 1.0 + 0.6)) ** 2) / 0.05)
    noise = _periodic_noise(h, w, 60, 40, seed + 1)
    img += (0.020 * band * (0.4 + noise)).astype(np.float32)
    return img


def _periodic_noise(h: int, w: int, sig_x: float, sig_y: float, seed: int) -> np.ndarray:
    """Gaussian-filtered white noise (periodic), normalised to 0..1."""
    rng = np.random.default_rng(seed)
    n = rng.standard_normal((h, w)).astype(np.float32)
    fx = np.fft.fftfreq(w)[None, :]
    fy = np.fft.fftfreq(h)[:, None]
    k = np.exp(-2 * (math.pi ** 2) * ((fx * sig_x) ** 2 + (fy * sig_y) ** 2))
    out = np.fft.ifft2(np.fft.fft2(n) * k).real.astype(np.float32)
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out


# --------------------------------------------------------------------------- #
#  One-time geodesic tracing                                                   #
# --------------------------------------------------------------------------- #
def trace(p: Params, progress=None) -> dict:
    W, H, N = p.width, p.height, p.width * p.height
    D = p.cam_dist
    el = math.radians(p.elevation_deg)
    e1 = np.array([math.cos(el), 0.0, math.sin(el)])      # BH -> camera
    fwd = -e1
    up = np.array([0.0, 0.0, 1.0]) - fwd * fwd[2]
    up /= np.linalg.norm(up)
    right = np.cross(fwd, up)

    xs = ((np.arange(W) + 0.5) / W * 2 - 1) * p.tan_half_w
    ys = (1 - (np.arange(H) + 0.5) / H * 2) * p.tan_half_w * H / W
    SX, SY = np.meshgrid(xs, ys)
    ro = math.radians(p.roll_deg)
    rx = SX * math.cos(ro) - SY * math.sin(ro)
    ry = SX * math.sin(ro) + SY * math.cos(ro)
    dirs = fwd[None, None, :] + rx[..., None] * right + ry[..., None] * up
    dirs = dirs.reshape(-1, 3)
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)

    cospsi = dirs @ fwd
    perp = dirs - cospsi[:, None] * fwd[None, :]
    sinpsi = np.linalg.norm(perp, axis=1)
    e2 = perp / np.maximum(sinpsi, 1e-9)[:, None]
    e2[sinpsi < 1e-9] = right

    u0 = 1.0 / D
    b = D * sinpsi / math.sqrt(1 - 2 / D)
    b = np.maximum(b, 1e-4)
    v0 = np.sqrt(np.maximum(1 / b ** 2 - u0 ** 2 * (1 - 2 * u0), 0))

    pid = np.arange(N, dtype=np.int32)
    u = np.full(N, u0, F32)
    v = v0.astype(F32)
    bb = b.astype(F32)
    E2 = e2.astype(F32)
    E2z = np.ascontiguousarray(E2[:, 2])
    e1x, e1y, e1z = [F32(x) for x in e1]

    cnt = np.zeros(N, np.int8)
    max_slots = 4
    cross = [dict(pid=[], r=[], az=[], g=[]) for _ in range(max_slots)]

    esc_dir = np.zeros((N, 3), F32)
    escaped = np.zeros(N, bool)

    phi = 0.0
    s_old = np.full(N, e1z, F32)
    dphi = F32(p.dphi)
    nsteps = int(p.max_phi / p.dphi)
    t0 = time.time()
    for step in range(nsteps):
        u_prev = u.copy()
        a = -u + 3 * u * u
        v += F32(.5) * dphi * a
        u += dphi * v
        np.minimum(u, F32(0.6), out=u)
        a = -u + 3 * u * u
        v += F32(.5) * dphi * a
        phi_old = phi
        phi += p.dphi
        cphi, sphi = F32(math.cos(phi)), F32(math.sin(phi))
        s_new = cphi * e1z + sphi * E2z

        ci = np.nonzero(s_old * s_new < 0)[0]
        if ci.size:
            t = s_old[ci] / (s_old[ci] - s_new[ci])
            phic = phi_old + t * dphi
            uc = u_prev[ci] + t * (u[ci] - u_prev[ci])
            rc = 1.0 / uc
            ok = (rc >= p.r_in) & (rc <= p.r_out)
            if ok.any():
                ci, phic, uc, rc = ci[ok], phic[ok], uc[ok], rc[ok]
                cp, sp = np.cos(phic)[:, None], np.sin(phic)[:, None]
                e2c = E2[ci]
                rhat = cp * e1[None, :].astype(F32) + sp * e2c
                phat = -sp * e1[None, :].astype(F32) + cp * e2c
                az = np.arctan2(rhat[:, 1], rhat[:, 0])
                bu = bb[ci] * uc
                kt = bu * np.sqrt(1 - 2 * uc)
                kr = np.sqrt(np.clip(1 - bu * bu * (1 - 2 * uc), 0, 1))
                kr = np.where(v[ci] > 0, -kr, kr)
                k3 = kr[:, None] * rhat + kt[:, None] * phat
                n = -k3
                vloc = np.sqrt(1.0 / (rc - 2.0))
                tang_dot_n = p.spin * (-np.sin(az) * n[:, 0] + np.cos(az) * n[:, 1])
                gam = 1.0 / np.sqrt(1 - vloc ** 2)
                g = np.sqrt(1 - 2 * uc) / (gam * (1 - vloc * tang_dot_n))
                pids = pid[ci]
                ks = cnt[pids]
                cnt[pids] += 1
                for k in range(max_slots):
                    m = ks == k
                    if m.any():
                        c = cross[k]
                        c["pid"].append(pids[m]); c["r"].append(rc[m].astype(F32))
                        c["az"].append(az[m].astype(F32)); c["g"].append(g[m].astype(F32))
        s_old = s_new

        dead = u >= 0.5
        esc = (v < 0) & (u <= u0)
        done = dead | esc
        if done.any():
            if esc.any():
                ei = np.nonzero(esc)[0]
                phi_inf = phi + np.arcsin(np.minimum(bb[ei] * u[ei], 1.0))
                d3 = (np.cos(phi_inf)[:, None] * e1[None, :].astype(F32)
                      + np.sin(phi_inf)[:, None] * E2[ei])
                esc_dir[pid[ei]] = d3
                escaped[pid[ei]] = True
            keep = ~done
            pid, u, v, bb, E2, E2z, s_old = (pid[keep], u[keep], v[keep], bb[keep],
                                             E2[keep], E2z[keep], s_old[keep])
            if pid.size == 0:
                break
        if progress and step % 40 == 0:
            progress(step / nsteps)
    if progress:
        progress(1.0)

    slots = []
    for c in cross:
        if not c["pid"]:
            slots.append(None)
            continue
        slots.append({k: np.concatenate(v_) for k, v_ in c.items()})
    return dict(slots=slots, esc_dir=esc_dir, escaped=escaped,
                seconds=time.time() - t0)


def bake_background(esc_dir: np.ndarray, escaped: np.ndarray, star: np.ndarray) -> np.ndarray:
    """Look the lensed escape directions up in the starfield."""
    h, w = star.shape
    idx = np.nonzero(escaped)[0]
    d = esc_dir[idx]
    lon = np.arctan2(d[:, 1], d[:, 0])
    lat = np.arcsin(np.clip(d[:, 2], -1, 1))
    xf = (lon + math.pi) / (2 * math.pi) * w
    yf = (math.pi / 2 - lat) / math.pi * (h - 1)
    x0 = np.floor(xf).astype(np.int64); y0 = np.floor(yf).astype(np.int64)
    fx = (xf - x0).astype(F32); fy = (yf - y0).astype(F32)
    x1 = (x0 + 1) % w; x0 %= w
    y1 = np.minimum(y0 + 1, h - 1)
    val = (star[y0, x0] * (1 - fx) * (1 - fy) + star[y0, x1] * fx * (1 - fy)
           + star[y1, x0] * (1 - fx) * fy + star[y1, x1] * fx * fy)
    out = np.zeros(escaped.size, F32)
    out[idx] = val
    return out


# --------------------------------------------------------------------------- #
#  Disk texture                                                                #
# --------------------------------------------------------------------------- #
NA, NR = 2048, 768


def make_disk_texture(seed: int = 11) -> np.ndarray:
    """Polar plasma texture [NR, NA] in 0..1: streaks, clumps, dark gaps."""
    streak = _periodic_noise(NR, NA, 70, 1.4, seed)
    streak2 = _periodic_noise(NR, NA, 150, 3.0, seed + 1)
    clump = _periodic_noise(NR, NA, 40, 9.0, seed + 2)
    fine = _periodic_noise(NR, NA, 18, 0.8, seed + 3)
    # radial structure: bright/dark rings with irregular gaps
    rr = np.linspace(0, 1, NR)
    rng = np.random.default_rng(seed + 4)
    ring = np.zeros(NR)
    for k in range(1, 14):
        ring += rng.normal(0, 1 / k ** 0.7) * np.sin(2 * math.pi * (k * rr * 0.9 + rng.uniform()))
    ring = (ring - ring.min()) / (ring.max() - ring.min())
    ring = 0.55 + 0.45 * ring
    t = (0.30 * streak + 0.30 * streak2 + 0.28 * clump + 0.12 * fine)
    t = (t - t.min()) / (t.max() - t.min())
    t = 0.38 + 0.80 * np.clip((t - 0.25) * 1.6, 0, 1) ** 1.2
    t = t * ring[:, None]
    # a few hot spots that orbit
    for _ in range(14):
        cy, cx = rng.uniform(0.05, 0.6) * NR, rng.uniform(0, NA)
        sy, sx = rng.uniform(2, 6), rng.uniform(30, 110)
        yy = np.arange(NR)[:, None]; xx = (np.arange(NA)[None, :] - cx + NA / 2) % NA - NA / 2
        t += rng.uniform(0.25, 0.6) * np.exp(-((yy - cy) ** 2) / (2 * sy ** 2) - (xx ** 2) / (2 * sx ** 2))
    # fine orbiting debris: tiny bright specks at many radii
    for _ in range(170):
        cy, cx = rng.uniform(0.02, 0.9) * NR, rng.uniform(0, NA)
        sy, sx = rng.uniform(0.8, 1.6), rng.uniform(2.5, 7.0)
        y0, y1 = int(max(cy - 6, 0)), int(min(cy + 7, NR))
        yy = np.arange(y0, y1)[:, None]
        xx = (np.arange(NA)[None, :] - cx + NA / 2) % NA - NA / 2
        t[y0:y1] += rng.uniform(0.5, 1.3) * np.exp(-((yy - cy) ** 2) / (2 * sy ** 2) - (xx ** 2) / (2 * sx ** 2))
    t = np.clip(t, 0, 1.8)
    return t.astype(F32)


# --------------------------------------------------------------------------- #
#  Cache                                                                       #
# --------------------------------------------------------------------------- #
def load_or_build(p: Params, cache_dir: str, progress=None) -> dict:
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, p.key() + ".npz")
    if os.path.exists(path):
        try:
            z = np.load(path)
            data = {"bg": z["bg"], "slots": []}
            for k in range(4):
                if f"pid{k}" in z:
                    data["slots"].append(dict(pid=z[f"pid{k}"], r=z[f"r{k}"],
                                              az=z[f"az{k}"], g=z[f"g{k}"]))
            return data
        except Exception:
            pass
    tr = trace(p, progress)
    star = make_starmap()
    bg = bake_background(tr["esc_dir"], tr["escaped"], star)
    out = {"bg": bg, "slots": [s for s in tr["slots"] if s is not None]}
    try:
        arrs = {"bg": bg.astype(np.float16)}
        for k, s in enumerate(out["slots"]):
            arrs[f"pid{k}"] = s["pid"]
            arrs[f"r{k}"] = s["r"].astype(np.float16)
            arrs[f"az{k}"] = s["az"].astype(np.float16)
            arrs[f"g{k}"] = s["g"].astype(np.float16)
        np.savez_compressed(path, **arrs)
    except Exception:
        pass
    return out


# --------------------------------------------------------------------------- #
#  Per-frame renderer                                                          #
# --------------------------------------------------------------------------- #
class BlackHoleRenderer:
    """Turns the cached maps into an 8-bit grayscale frame."""

    def __init__(self, p: Params, data: dict, rigid_period: float | None = None):
        self.p = p
        W, H = p.width, p.height
        self.N = W * H
        self.tex = make_disk_texture().ravel()
        self.bg = data["bg"].astype(F32)
        self.slots = []
        for si, s in enumerate(data["slots"]):
            r = s["r"].astype(F32)
            az = s["az"].astype(F32)
            g = s["g"].astype(F32)
            span = p.r_out - p.r_in
            x = np.clip((r - p.r_in) / span, 0, 1)
            ri = np.minimum((x * (NR - 1)).astype(np.int32), NR - 1) * NA
            col0 = (az / (2 * math.pi) * NA).astype(F32)
            # Keplerian: inner faster than outer.  ~7 s for one inner orbit.
            omega = (2 * math.pi / 7.0) * (p.r_in / r) ** 1.5
            if rigid_period:                      # seamless loops (GIF export)
                omega = np.full_like(r, 2 * math.pi / rigid_period)
            dcol = (omega * NA / (2 * math.pi)).astype(F32) * F32(-p.spin)
            emis = (p.r_in / r) ** 1.55
            edge_in = np.clip((r - p.r_in) / 0.9, 0, 1)
            edge_out = np.clip((p.r_out - r) / (0.55 * span), 0, 1)
            fade = (edge_in ** 0.8) * (edge_out ** 1.2)
            gg = np.clip(g, 0.15, 2.6)
            boost = (1.0, 1.15, 2.4, 3.2)[min(si, 3)]       # photon ring = higher-order images
            base = (emis * gg ** 3.1 * fade * 2.6 * boost).astype(F32)
            alpha = (0.92 * fade).astype(F32)
            self.slots.append(dict(pid=s["pid"].astype(np.int64), ri=ri.astype(np.int64),
                                   col0=col0, dcol=dcol, base=base, alpha=alpha))
        # soft vignette so the frame edge dissolves into black
        yy, xx = np.mgrid[0:H, 0:W]
        nx = (xx - W / 2) / (W / 2); ny = (yy - H / 2) / (H / 2)
        d = np.sqrt(nx * nx * 1.35 + ny * ny * 1.15)
        v = np.clip(1.15 - d, 0, 1)
        self.vig = (v * v * (3 - 2 * v)).astype(F32).ravel()
        self.out = np.zeros(self.N, F32)
        self.trans = np.ones(self.N, F32)
        self.gray = np.zeros(self.N, np.uint8)
        self.exposure = 3.0

    def render(self, t: float, speed: float = 1.0, intensity: float = 1.0) -> np.ndarray:
        """Return (H, W) uint8 grayscale."""
        ts = t * speed
        out, trans = self.out, self.trans
        out[:] = 0
        trans[:] = 1
        for s in self.slots:
            pid = s["pid"]
            col = (s["col0"] + s["dcol"] * F32(ts)).astype(np.int64) % NA
            val = self.tex[s["ri"] + col]
            tr = trans[pid]
            out[pid] += tr * val * s["base"]
            trans[pid] = tr * (1 - s["alpha"] * np.minimum(val * 1.6, 1.0))
        out += trans * self.bg * 1.0
        out *= F32(self.exposure * intensity)
        # filmic tone map -> display
        np.multiply(out, -1.0, out=out)
        np.exp(out, out=out)
        np.subtract(1.0, out, out=out)
        out *= self.vig
        np.power(out, F32(0.82), out=out)
        np.multiply(out, 255.0, out=out)
        self.gray[:] = out.astype(np.uint8)
        return self.gray.reshape(self.p.height, self.p.width)
