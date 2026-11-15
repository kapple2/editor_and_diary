"""The splash art of the diary (top 20% of the title screens): a diary book, "일기" and a script "Diary".
make() -> (width in bytes, x offset in bytes, height, rle bytes). Hi-res: 7 pixels per byte, bit 0 = leftmost.
Each line is stored as its difference (xor) from the line above, then RLE per line: a byte < $80 is a literal,
$80+n = n zero bytes."""
from PIL import Image, ImageDraw, ImageFont

H = 36
FONTS = r"C:\Windows\Fonts"


def book():
    S = 4
    im = Image.new("L", (36 * S, H * S), 0)
    d = ImageDraw.Draw(im)
    def r(x0, y0, x1, y1, **k):
        d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], **k)
    r(3, 2, 33, 34, outline=255, width=S)            # cover
    r(3, 2, 9, 34, fill=255)                        # spine
    for y in (8, 13, 18, 23):                        # a title label and lines
        pass
    r(14, 7, 29, 17, outline=255, width=S)           # label
    r(17, 11, 26, 13, fill=255)
    for y in (22, 26, 30):
        r(14, y, 29, y + 1, fill=255)
    r(24, 34, 28, 36, fill=255)                      # ribbon
    return im.resize((36, H), Image.LANCZOS)


def text(s, font, size, w, h, stroke=0):
    S = 4
    f = ImageFont.truetype(font, size * S)
    im = Image.new("L", (w * S, h * S), 0)
    d = ImageDraw.Draw(im)
    bb = d.textbbox((0, 0), s, font=f)
    d.text(((w * S - (bb[2] - bb[0])) // 2 - bb[0], (h * S - (bb[3] - bb[1])) // 2 - bb[1]), s, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
    return im.resize((w, h), Image.LANCZOS)


def glyph(ch, h):
    """One character, scaled to the ink height h (natural width), with a heavier stroke."""
    f = ImageFont.truetype(FONTS + "/batang.ttc", 200)
    im = Image.new("L", (300, 300), 0)
    ImageDraw.Draw(im).text((30, 20), ch, font=f, fill=255, stroke_width=4, stroke_fill=255)
    im = im.crop(im.getbbox())
    w = round(im.width * h / im.height)
    return im.resize((w, h), Image.LANCZOS)


def compose():
    W = 140
    img = Image.new("L", (W, H), 0)
    x = 2
    for ch in "日記帳":
        g = glyph(ch, 34)
        img.paste(g, (x + (44 - g.width) // 2, 1), g)
        x += 46
    return img.point(lambda v: 255 if v >= 110 else 0).convert("1")


def make():
    img = compose()
    W = img.width
    nb = (W + 6) // 7
    x0 = (40 - nb) // 2
    px = img.load()
    out = bytearray()
    prev = [0] * nb
    for y in range(H):
        row = []
        for b in range(nb):
            v = 0
            for k in range(7):
                x = b * 7 + k
                if x < W and px[x, y]:
                    v |= 1 << k
            row.append(v)
        cur = row
        row = [a ^ b for a, b in zip(cur, prev)]
        prev = cur
        i = 0
        while i < nb:
            if row[i] == 0:
                j = i
                while j < nb and row[j] == 0 and j - i < 127:
                    j += 1
                out.append(0x80 | (j - i))
                i = j
            else:
                out.append(row[i])
                i += 1
    return nb, x0, H, bytes(out), img


if __name__ == "__main__":
    nb, x0, h, data, img = make()
    print(nb, x0, h, len(data))
    img.convert("L").resize((img.width * 4, img.height * 4), Image.NEAREST).save("art_preview.png")
