#!/usr/bin/env python3
"""Draws the placeholder brand assets into assets/branding/.

* icon.png             1024x1024, opaque (App Store requires no alpha)
* icon_foreground.png  1024x1024, transparent, art inside the adaptive-icon
                       safe zone (Android)
* splash.png           768x768, transparent mark for the native splash

The design matches the in-app logo (lib/features/splash/splash_screen.dart):
a teal bazaar archway with stacked goods. Replace these PNGs with final art
and re-run `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create`.

Usage: python3 tool/make_brand_assets.py
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
SAFFRON = (244, 163, 0)
TEAL = (15, 124, 122)
TEAL_DEEP = (10, 85, 82)
TERRACOTTA = (200, 85, 61)
IVORY = (255, 246, 229)
NIGHT = (43, 27, 16)
SS = 4  # supersampling for smooth edges


def arch_mark(size, scale=1.0, background=None):
    s = size * SS
    img = Image.new("RGBA", (s, s), background + (255,) if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = s * scale
    ox = (s - w) / 2
    oy = (s - w) / 2

    def P(x, y):
        return (ox + x * w, oy + y * w)

    # Archway: rectangle + semicircle top.
    left, right, top, bottom = 0.12, 0.88, 0.06, 0.96
    radius = (right - left) / 2
    d.rectangle([P(left, top + radius), P(right, bottom)], fill=TEAL)
    d.pieslice([P(left, top), P(right, top + 2 * radius)], 180, 360, fill=TEAL)
    # Saffron outline.
    stroke = int(w * 0.045)
    d.arc([P(left, top), P(right, top + 2 * radius)], 180, 360, fill=SAFFRON, width=stroke)
    # Side posts drawn inside the arch's stroke so the joins are seamless.
    half = stroke / 2 / w
    d.rectangle([P(left, top + radius), P(left + 2 * half, bottom)], fill=SAFFRON)
    d.rectangle([P(right - 2 * half, top + radius), P(right, bottom)], fill=SAFFRON)
    # Inner shadow door.
    d.rounded_rectangle([P(0.24, 0.36), P(0.76, 0.96)], radius=w * 0.05, fill=TEAL_DEEP)
    # Stacked goods.
    for i, color in enumerate([SAFFRON, TERRACOTTA, IVORY]):
        y = 0.80 - i * 0.16
        d.rounded_rectangle([P(0.30, y), P(0.70, y + 0.13)], radius=w * 0.035, fill=color)
    # Little star above the arch.
    cx, cy, r = 0.5, 0.2, 0.045
    import math
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append(P(cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=SAFFRON)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    icon = arch_mark(1024, 0.78, background=NIGHT).convert("RGB")
    icon.save(os.path.join(OUT, "icon.png"))
    # Adaptive icon: art within the inner 66% safe zone.
    arch_mark(1024, 0.58).save(os.path.join(OUT, "icon_foreground.png"))
    arch_mark(768, 0.8).save(os.path.join(OUT, "splash.png"))
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
