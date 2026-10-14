"""painter.qa - export, SSIM gate and QA / naming sheets (ICON_STYLE.md section 6).

  save(cv, alpha, path_base, px)   tonemap -> RGBA, writes <base>.png (px) and <base>@2x.png (2*px)
  ssim_matrix(imgs, crop)          pairwise SSIM of 32 px greyscale copies
  gate(label, ids, imgs, limit)    prints the matrix, returns (ok, worst_pair_value, fails)
  qa_sheet(items, path, kind)      rows: native | 32 px colour | 32 px grey | squint (skills 24 px blurred,
                                   status 28 px grey); bars also write <path>_naming.png (64 px, numbered)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from painter.core import tonemap

BG = (15, 18, 26, 255)


def save(cv, alpha, path_base, px):
    rgb = tonemap(cv.c)
    a = np.clip(alpha, 0, 1)[..., None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), a], axis=2)
    img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    os.makedirs(os.path.dirname(path_base), exist_ok=True)
    img.resize((px * 2, px * 2), Image.LANCZOS).save(path_base + "@2x.png")
    small = img.resize((px, px), Image.LANCZOS)
    small.save(path_base + ".png")
    return small


def on_bg(img, size=None):
    bg = Image.new("RGBA", img.size, BG)
    bg.alpha_composite(img.convert("RGBA"))
    return bg if size is None else bg.resize((size, size), Image.LANCZOS)


def grey32(img, crop=0.0):
    im = on_bg(img)
    if crop:
        w = im.width
        c = int(w * crop)
        im = im.crop((c, c, w - c, w - c))
    return np.asarray(im.convert("L").resize((32, 32), Image.LANCZOS), np.float64) / 255.0


def _gconv(x, g):
    k = len(g)
    # separable valid convolution
    x = sum(g[i] * x[i:x.shape[0] - k + 1 + i, :] for i in range(k))
    return sum(g[i] * x[:, i:x.shape[1] - k + 1 + i] for i in range(k))


def ssim(a, b, win=7):
    """mean SSIM over a sliding Gaussian window (Wang et al. 2004), single scale"""
    g = np.exp(-((np.arange(win) - win // 2) ** 2) / (2 * 1.5 ** 2))
    g /= g.sum()
    C1, C2 = 0.01 ** 2, 0.03 ** 2
    ma, mb = _gconv(a, g), _gconv(b, g)
    va = _gconv(a * a, g) - ma * ma
    vb = _gconv(b * b, g) - mb * mb
    cab = _gconv(a * b, g) - ma * mb
    s = ((2 * ma * mb + C1) * (2 * cab + C2)) / ((ma * ma + mb * mb + C1) * (va + vb + C2))
    return float(s.mean())


def ssim_matrix(imgs, crop=0.0):
    g = [grey32(im, crop) for im in imgs]
    n = len(g)
    M = np.eye(n)
    for i in range(n):
        for j in range(i + 1, n):
            M[i, j] = M[j, i] = ssim(g[i], g[j])
    return M


def gate(label, ids, imgs, limit=0.60, crop=0.0, quiet=False):
    """pairwise SSIM gate. Returns (ok, worst, fails[(a, b, s)])"""
    M = ssim_matrix(imgs, crop)
    worst, fails = 0.0, []
    if not quiet:
        print("SSIM 32px greyscale, %s (fail > %.2f)" % (label, limit))
    for i in range(len(ids)):
        if not quiet:
            print("  %-44s %s" % (ids[i], " ".join("%.2f" % v for v in M[i])))
        for j in range(i + 1, len(ids)):
            worst = max(worst, M[i, j])
            if M[i, j] > limit:
                fails.append((ids[i], ids[j], round(float(M[i, j]), 3)))
    print("SSIM %-28s max pair %.3f -> %s" % (label, worst, "PASS" if not fails else "FAIL " + str(fails)))
    return not fails, float(worst), fails


def qa_sheet(items, path, kind="skill", per_row=9):
    """items: [(id, PIL image)]. kind: skill | status | emblem."""
    cell = 140
    cols = min(per_row, len(items))
    rows_blocks = (len(items) + cols - 1) // cols
    block_h = 520
    sheet = Image.new("RGBA", (cell * cols + 20, block_h * rows_blocks + 10), BG)
    d = ImageDraw.Draw(sheet)
    for k, (iid, img) in enumerate(items):
        bx, by = k % cols, k // cols
        x0 = 10 + bx * cell
        y0 = 10 + by * block_h
        shown = img if img.width <= 128 else img.resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(shown, (x0 + (cell - shown.width) // 2, y0 + (128 - shown.height) // 2))
        up = img.resize((32, 32), Image.LANCZOS).resize((96, 96), Image.NEAREST)
        sheet.alpha_composite(up, (x0 + 22, y0 + 140))
        sheet.alpha_composite(up.convert("LA").convert("RGBA"), (x0 + 22, y0 + 252))
        if kind == "skill":
            sq = on_bg(img, 24).filter(ImageFilter.GaussianBlur(0.8)).resize((96, 96), Image.NEAREST)
        else:
            sq = on_bg(img, 28).convert("L").convert("RGBA").resize((96, 96), Image.NEAREST)
        sheet.alpha_composite(sq, (x0 + 22, y0 + 364))
        d.text((x0 + 4, y0 + 466), str(iid).split(".")[-1][:22], fill=(150, 160, 178, 255))
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    sheet.save(path)
    if kind == "skill":
        nm = Image.new("RGBA", (len(items) * 84 + 12, 96), BG)
        dn = ImageDraw.Draw(nm)
        for i, (_, img) in enumerate(items):
            nm.alpha_composite(img.resize((64, 64), Image.LANCZOS), (12 + i * 84, 8))
            dn.text((12 + i * 84 + 28, 76), str(i + 1), fill=(220, 226, 236, 255))
        nm.save(os.path.splitext(path)[0] + "_naming.png")
