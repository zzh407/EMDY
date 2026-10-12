#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""EMDY app icon generator.
Style: TikTok-style glitch note (cyan/magenta offset) + small cloud partner.
Outputs HarmonyOS layered icon: background.png + foreground.png (1024x1024 RGBA).
"""
from PIL import Image, ImageDraw, ImageFilter

S = 1024  # canvas size (matches existing assets)

# ---- palette ----
CYAN = (37, 244, 238, 255)      # #25F4EE douyin cyan
MAGENTA = (254, 44, 85, 255)    # #FE2C55 douyin magenta
WHITE = (245, 248, 255, 255)    # main note body
OFFSET = 26                     # glitch offset px


def cubic(p0, p1, p2, p3, n=48):
    """Sample a cubic bezier into a polyline."""
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def make_note(color: tuple) -> Image.Image:
    """Draw a TikTok-style single-flag note in one color on a transparent layer."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # tilted stem: from note head upper-right, leaning up to the right
    d.line([(478, 605), (602, 196)], fill=color, width=40)
    # single flowing flag: fly out right, sweep down, fly off with a tapered tip
    seg1 = cubic((604, 202), (764, 138), (848, 214), (858, 302))
    seg2 = cubic((858, 302), (850, 368), (784, 400), (710, 394))
    seg3 = cubic((710, 394), (668, 390), (638, 382), (618, 372))
    for pts, w in ((seg1, 32), (seg2, 26), (seg3, 14)):
        d.line(pts, fill=color, width=w, joint='curve')
    # round joints to hide width seams
    for p in (seg1[-1], seg2[-1], seg2[0]):
        d.ellipse([p[0] - 13, p[1] - 13, p[0] + 13, p[1] + 13], fill=color)
    # note head: tilted ellipse on its own layer, then rotate
    head = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head)
    hd.ellipse([390 - 176, 662 - 138, 390 + 176, 662 + 138], fill=color)
    head = head.rotate(-20, resample=Image.BICUBIC, center=(390, 662))
    img = Image.alpha_composite(img, head)
    return img


def make_cloud() -> Image.Image:
    """Small cloud partner in the top-right, soft translucent white."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fill = (235, 240, 250, 110)
    d.ellipse([858 - 50, 138 - 50, 858 + 50, 138 + 50], fill=fill)   # main puff
    d.ellipse([806 - 36, 166 - 36, 806 + 36, 166 + 36], fill=fill)   # left puff
    d.ellipse([902 - 32, 162 - 32, 902 + 32, 162 + 32], fill=fill)   # right puff
    d.rounded_rectangle([778, 166, 928, 204], radius=19, fill=fill)  # base bar
    return img


def paste_offset(base: Image.Image, layer: Image.Image, dx: int, dy: int) -> Image.Image:
    shifted = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    shifted.paste(layer, (dx, dy), layer)
    return Image.alpha_composite(base, shifted)


def make_background() -> Image.Image:
    """Near-black canvas with a subtle center glow."""
    small = Image.new('RGB', (128, 128))
    px = small.load()
    cx = cy = 63.5
    maxd = (cx**2 + cy**2) ** 0.5
    for y in range(128):
        for x in range(128):
            dist = ((x - cx)**2 + (y - cy)**2) ** 0.5 / maxd
            # 16,20,31 (center) -> 5,7,11 (edge)
            r = int(16 - (16 - 5) * dist)
            g = int(20 - (20 - 7) * dist)
            b = int(31 - (31 - 11) * dist)
            px[x, y] = (r, g, b)
    return small.resize((S, S), Image.BICUBIC).convert('RGBA')


def fit_safe(img: Image.Image, ratio: float = 0.88) -> Image.Image:
    """Scale content to fit the launcher safe zone and center it."""
    bbox = img.getbbox()
    if not bbox:
        return img
    content = img.crop(bbox)
    target = int(S * ratio)
    scale = min(target / content.width, target / content.height)
    new = content.resize((max(1, int(content.width * scale)), max(1, int(content.height * scale))),
                         Image.LANCZOS)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(new, ((S - new.width) // 2, (S - new.height) // 2), new)
    return out


def main():
    background = make_background()

    foreground = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    foreground = paste_offset(foreground, make_note(CYAN), -OFFSET, -OFFSET + 4)
    foreground = paste_offset(foreground, make_note(MAGENTA), OFFSET, OFFSET - 4)
    foreground = paste_offset(foreground, make_note(WHITE), 0, 0)
    foreground = Image.alpha_composite(foreground, make_cloud())
    foreground = fit_safe(foreground)

    # preview: how it looks composited on the device
    preview = Image.alpha_composite(background, foreground).resize((512, 512), Image.LANCZOS)

    background.save('AppScope/resources/base/media/background.png')
    foreground.save('AppScope/resources/base/media/foreground.png')
    preview.save('icon-design/preview.png')
    print('background.png / foreground.png updated, preview saved')


if __name__ == '__main__':
    main()
