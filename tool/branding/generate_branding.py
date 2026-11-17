#!/usr/bin/env python3
"""Generates every Inventrix branding asset (PNG + SVG) from one geometry.

Requires: Pillow, fonttools, and the Inter font (Inter-ExtraBold.otf).
Run from the project root:  python3 tool/branding/generate_branding.py
The generated files are committed, so this only needs re-running when the
mark or the colours change.
"""
import os, sys
from PIL import Image, ImageDraw, ImageChops
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'branding')
SRC = os.path.join(OUT, 'src')
FONT = os.environ.get('INVENTRIX_FONT', '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf')
SS = 4  # supersampling factor

# ---- brand colours ---------------------------------------------------------
INDIGO = '#4F46E5'        # primary, light backgrounds and icon tile
INDIGO_ON_DARK = '#8179F5'  # same hue, lifted for dark backgrounds
MINT = '#10B981'          # accent block on light backgrounds
MINT_ON_DARK = '#34D399'  # accent block on dark backgrounds / indigo tile
NAVY = '#0B1220'          # dark background and light-background wordmark
WHITE = '#FFFFFF'
SPLASH_LIGHT_BG = '#F4F6FB'

def rgb(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

# ---- the mark: three columns of 1, 2 and 3 blocks (stock growing) ----------
# Geometry on a 680-unit grid: block 200, gap 40, radius 44.
U_BLOCK, U_GAP, U_RAD, U_SIDE = 200, 40, 44, 680
def blocks(x, y, side):
    """Yield (x0, y0, x1, y1, radius, is_accent) for the 6 blocks."""
    u = side / U_SIDE
    for col in range(3):
        for row in range(col + 1):
            bx = x + col * (U_BLOCK + U_GAP) * u
            by = y + (U_SIDE - U_BLOCK - row * (U_BLOCK + U_GAP)) * u
            yield bx, by, bx + U_BLOCK * u, by + U_BLOCK * u, U_RAD * u, (col == 2 and row == 2)

def draw_symbol(d, x, y, side, body, accent):
    for x0, y0, x1, y1, r, acc in blocks(x * SS, y * SS, side * SS):
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=rgb(accent if acc else body))

def svg_symbol(x, y, side, body, accent):
    out = []
    for x0, y0, x1, y1, r, acc in blocks(x, y, side):
        out.append(f'<rect x="{x0:.2f}" y="{y0:.2f}" width="{x1-x0:.2f}" height="{y1-y0:.2f}" rx="{r:.2f}" fill="{accent if acc else body}"/>')
    return '\n  '.join(out)

# ---- wordmark from real glyph outlines -------------------------------------
font = TTFont(FONT); gs = font.getGlyphSet(); cmap = font.getBestCmap()
UPM = font['head'].unitsPerEm; CAP = font['OS/2'].sCapHeight
TRACK = 0.075  # em

class Flat(BasePen):
    def __init__(s, gset): super().__init__(gset); s.contours = []; s.cur = None
    def _moveTo(s, p): s.cur = [p]
    def _lineTo(s, p): s.cur.append(p)
    def _curveToOne(s, a, b, c):
        p0 = s._getCurrentPoint()
        for i in range(1, 17):
            t = i / 16; m = 1 - t
            s.cur.append((m**3*p0[0]+3*m*m*t*a[0]+3*m*t*t*b[0]+t**3*c[0],
                          m**3*p0[1]+3*m*m*t*a[1]+3*m*t*t*b[1]+t**3*c[1]))
    def _qCurveToOne(s, a, b):
        p0 = s._getCurrentPoint()
        for i in range(1, 17):
            t = i / 16; m = 1 - t
            s.cur.append((m*m*p0[0]+2*m*t*a[0]+t*t*b[0], m*m*p0[1]+2*m*t*a[1]+t*t*b[1]))
    def _closePath(s):
        if s.cur: s.contours.append(s.cur); s.cur = None
    _endPath = _closePath

def text_width(text, fs):
    return sum(gs[cmap[ord(c)]].width for c in text) * fs / UPM + TRACK * fs * (len(text) - 1)

def draw_text(img, text, x, baseline, fs, color):
    """Rasterise [text] with its left edge at x and the baseline at [baseline] (px, pre-SS)."""
    sc = fs * SS / UPM
    mask = Image.new('L', img.size, 0)
    cx = x * SS
    for ch in text:
        name = cmap[ord(ch)]; g = gs[name]
        pen = Flat(gs); g.draw(pen)
        gm = Image.new('L', img.size, 0)
        for c in pen.contours:
            pts = [(cx + px * sc, baseline * SS - py * sc) for px, py in c]
            t = Image.new('L', img.size, 0); ImageDraw.Draw(t).polygon(pts, fill=255)
            gm = ImageChops.difference(gm, t)  # even-odd so counters stay open
        mask = ImageChops.lighter(mask, gm)
        cx += g.width * sc + TRACK * fs * SS
    img.paste(Image.new('RGB', img.size, rgb(color)), (0, 0), mask)

def svg_text(text, x, baseline, fs, color):
    sc = fs / UPM; cx = x; parts = []
    for ch in text:
        g = gs[cmap[ord(ch)]]
        sp = SVGPathPen(gs); g.draw(TransformPen(sp, (sc, 0, 0, -sc, cx, baseline)))
        parts.append(sp.getCommands()); cx += g.width * sc + TRACK * fs
    return f'<path fill="{color}" d="{" ".join(parts)}"/>'

# ---- canvas helpers ---------------------------------------------------------
def canvas(w, h, bg=None):
    mode = 'RGBA' if bg is None else 'RGB'
    return Image.new(mode, (w * SS, h * SS), (0, 0, 0, 0) if bg is None else rgb(bg))

def finish(img, path, w, h, flatten=False):
    out = img.resize((w, h), Image.LANCZOS)
    if flatten and out.mode == 'RGBA': out = out.convert('RGB')
    out.save(os.path.join(OUT, path), optimize=True)

def rgba_text(w, h, text, x, base, fs, color):
    """Transparent canvas with [text] drawn (text uses an RGB mask pass)."""
    rgbimg = Image.new('RGB', (w * SS, h * SS), (0, 0, 0))
    mask_holder = Image.new('RGB', rgbimg.size)
    # draw onto a black RGB, then derive alpha from luminance of a white pass
    draw_text(rgbimg, text, x, base, fs, '#FFFFFF')
    alpha = rgbimg.convert('L')
    solid = Image.new('RGBA', rgbimg.size, rgb(color) + (0,)); solid.putalpha(alpha)
    return solid

def lockup(w_pad, body, accent, word, mono=None):
    """Horizontal lockup: symbol + wordmark. Returns (img, w, h, layout)."""
    H = 240; GAP = 72; FS = 150; PAD = w_pad
    tw = text_width('INVENTRIX', FS); W = int(PAD * 2 + H + GAP + tw + 0.5); Ht = H + PAD * 2
    img = canvas(W, Ht)
    draw_symbol(ImageDraw.Draw(img), PAD, PAD, H, mono or body, mono or accent)
    cap = CAP * FS / UPM; base = PAD + H / 2 + cap / 2
    txt = rgba_text(W, Ht, 'INVENTRIX', PAD + H + GAP, base, FS, mono or word)
    img = Image.alpha_composite(img, txt)
    return img, W, Ht, dict(H=H, GAP=GAP, FS=FS, PAD=PAD, base=base, tw=tw)

def write_svg(name, w, h, inner, bg=None):
    bgr = f'<rect width="{w}" height="{h}" fill="{bg}"/>\n  ' if bg else ''
    open(os.path.join(SRC, name), 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n  {bgr}{inner}\n</svg>\n')

def main():
    os.makedirs(SRC, exist_ok=True)

    # 1) Launcher icon, full bleed (iOS + legacy Android): indigo tile, white blocks, mint accent.
    N = 1024; img = canvas(N, N, INDIGO)
    side = 520; draw_symbol(ImageDraw.Draw(img), (N - side) / 2, (N - side) / 2 + 6, side, WHITE, MINT_ON_DARK)
    finish(img, 'inventrix_icon.png', N, N, flatten=True)
    write_svg('inventrix_icon.svg', N, N, svg_symbol((N - side) / 2, (N - side) / 2 + 6, side, WHITE, MINT_ON_DARK), bg=INDIGO)

    # 2) Android adaptive foreground (safe zone: all of the mark inside the central 61 %), transparent.
    side = 420; img = canvas(N, N)
    draw_symbol(ImageDraw.Draw(img), (N - side) / 2, (N - side) / 2 + 4, side, WHITE, MINT_ON_DARK)
    finish(img, 'inventrix_icon_foreground.png', N, N)

    # 3) Android 13 themed icon: single-colour silhouette.
    img = canvas(N, N); draw_symbol(ImageDraw.Draw(img), (N - side) / 2, (N - side) / 2 + 4, side, WHITE, WHITE)
    finish(img, 'inventrix_icon_monochrome.png', N, N)

    # 4) Symbol only, transparent, for light and dark backgrounds.
    side = 800
    for nm, body, acc in (('inventrix_symbol.png', INDIGO, MINT), ('inventrix_symbol_dark.png', INDIGO_ON_DARK, MINT_ON_DARK)):
        img = canvas(N, N); draw_symbol(ImageDraw.Draw(img), (N - side) / 2, (N - side) / 2, side, body, acc); finish(img, nm, N, N)
    write_svg('inventrix_symbol.svg', U_SIDE, U_SIDE, svg_symbol(0, 0, U_SIDE, INDIGO, MINT))
    write_svg('inventrix_symbol_dark.svg', U_SIDE, U_SIDE, svg_symbol(0, 0, U_SIDE, INDIGO_ON_DARK, MINT_ON_DARK))

    # 5) Native splash images (centre symbol, brand colours, transparent).
    S = 768; side = 440
    for nm, body, acc in (('inventrix_splash.png', INDIGO, MINT), ('inventrix_splash_dark.png', INDIGO_ON_DARK, MINT_ON_DARK)):
        img = canvas(S, S); draw_symbol(ImageDraw.Draw(img), (S - side) / 2, (S - side) / 2, side, body, acc); finish(img, nm, S, S)
    # Android 12+: 960 px canvas, only the central 640 px circle is shown, so keep the mark inside it.
    S = 960; side = 380
    for nm, body, acc in (('inventrix_splash_android12.png', INDIGO, MINT), ('inventrix_splash_android12_dark.png', INDIGO_ON_DARK, MINT_ON_DARK)):
        img = canvas(S, S); draw_symbol(ImageDraw.Draw(img), (S - side) / 2, (S - side) / 2, side, body, acc); finish(img, nm, S, S)

    # 6) Wordmark only (native splash branding image, iOS / pre-Android-12).
    FS = 150; tw = text_width('INVENTRIX', FS); W = int(tw + 80); Ht = 220
    for nm, col in (('inventrix_wordmark.png', NAVY), ('inventrix_wordmark_dark.png', WHITE)):
        img = canvas(W, Ht); img = Image.alpha_composite(img, rgba_text(W, Ht, 'INVENTRIX', 40, Ht / 2 + CAP * FS / UPM / 2, FS, col)); finish(img, nm, W, Ht)

    # 7) Lockups.
    variants = [
        ('inventrix_logo_light.png', 'inventrix_logo_light.svg', INDIGO, MINT, NAVY, None, None),
        ('inventrix_logo_dark.png', 'inventrix_logo_dark.svg', INDIGO_ON_DARK, MINT_ON_DARK, WHITE, None, None),
        ('inventrix_logo_mono.png', 'inventrix_logo_mono.svg', None, None, None, NAVY, None),
        ('inventrix_logo_mono_white.png', 'inventrix_logo_mono_white.svg', None, None, None, WHITE, None),
    ]
    for png, svg, body, acc, word, mono, _ in variants:
        img, W, Ht, L = lockup(48, body, acc, word, mono)
        finish(img, png, W, Ht)
        col = mono
        inner = svg_symbol(L['PAD'], L['PAD'], L['H'], col or body, col or acc) + '\n  ' + svg_text('INVENTRIX', L['PAD'] + L['H'] + L['GAP'], L['base'], L['FS'], col or word)
        write_svg(svg, W, Ht, inner)
    # Primary logo = the light-background lockup.
    Image.open(os.path.join(OUT, 'inventrix_logo_light.png')).save(os.path.join(OUT, 'inventrix_logo.png'), optimize=True)
    import shutil; shutil.copy(os.path.join(SRC, 'inventrix_logo_light.svg'), os.path.join(SRC, 'inventrix_logo.svg'))
    print('branding written to', os.path.abspath(OUT))

if __name__ == '__main__':
    main()
