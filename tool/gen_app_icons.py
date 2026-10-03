"""Builds the launcher-icon sources from the web repo's public/logo.png (the clean mark; NOT
logo-icon.png, which has an "ICON ONLY" label baked into its pixels). Proportions mirror the web
repo's app/icon-512.png and app/icon-512-maskable.png routes: the mark on #0B0B0F at 80% of the
canvas width for the full icon, 60% (after the tool's inset) for the Android adaptive foreground.

Run from the repo root: python tool/gen_app_icons.py  (needs Pillow), then
dart run flutter_launcher_icons
"""
from PIL import Image

BG = (0x0B, 0x0B, 0x0F, 255)
SIZE = 1024
src = Image.open('assets/icon/logo_source.png').convert('RGBA')


def place(canvas, width_fraction):
    w = round(SIZE * width_fraction)
    h = round(w * src.height / src.width)
    logo = src.resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(logo, ((SIZE - w) // 2, (SIZE - h) // 2))
    return canvas


# Full icon (iOS, legacy Android): opaque, no alpha channel (App Store rejects alpha).
place(Image.new('RGBA', (SIZE, SIZE), BG), 0.80).convert('RGB').save('assets/icon/icon.png')
# Adaptive foreground: transparent. flutter_launcher_icons wraps it in a 16% inset (68% of the
# canvas remains), so 0.88 here lands the mark at ~60% of the 108dp canvas, the same as the web
# repo's maskable icon and inside Android's 66dp safe zone.
place(Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0)), 0.88).save('assets/icon/icon_foreground.png')
print('wrote assets/icon/icon.png and icon_foreground.png')
