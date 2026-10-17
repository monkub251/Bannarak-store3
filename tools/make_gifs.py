"""Generate the bundled sample GIFs (seamless loops, grayscale) with the real renderer."""
import os, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
from app import blackhole as bh

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "gifs")
VARIANTS = {
    "01_EVENT_HORIZON": dict(),
    "02_ORBIT_TILT": dict(elevation_deg=14.0, roll_deg=-22.0, tan_half_w=0.50),
    "03_EDGE_ON": dict(elevation_deg=0.9, roll_deg=0.0, tan_half_w=0.50),
    "04_PHOTON_RING": dict(elevation_deg=6.0, roll_deg=-10.0, tan_half_w=0.19),
}
W, H, N, DUR = 384, 224, 60, 60
tmp = tempfile.mkdtemp()
os.makedirs(OUT, exist_ok=True)
for name, kw in VARIANTS.items():
    p = bh.Params(width=W, height=H, **kw)
    data = bh.load_or_build(p, tmp)
    r = bh.BlackHoleRenderer(p, data, rigid_period=N * DUR / 1000.0)
    frames = [Image.fromarray(r.render(i * DUR / 1000.0).copy(), "L") for i in range(N)]
    path = os.path.join(OUT, name + ".gif")
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=DUR, loop=0, optimize=True)
    print(name, round(os.path.getsize(path) / 1e6, 2), "MB")
