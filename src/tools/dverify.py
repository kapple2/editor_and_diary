"""Read the diary's files straight from a DOS 3.3 .dsk image (random-access files with holes) and decrypt entries."""
from pathlib import Path


def catalog(raw):
    out = []
    t, s = 17, 15 if False else 0
    # VTOC at track 17 sector 0: bytes 1,2 = first catalog track/sector
    vt = 17 * 16 * 256
    t, s = raw[vt + 1], raw[vt + 2]
    seen = 0
    while t and seen < 20:
        base = (t * 16 + s) * 256
        for i in range(11, 256 - 35 + 1, 35):
            ts_t, ts_s = raw[base + i], raw[base + i + 1]
            if ts_t in (0, 255):
                continue
            name = bytes(raw[base + i + 3:base + i + 33])
            out.append((name, ts_t, ts_s))
        t, s = raw[base + 1], raw[base + 2]
        seen += 1
    return out


def sectors(raw, ts_t, ts_s):
    """sector index -> 256 bytes (missing = hole)."""
    res = {}
    t, s = ts_t, ts_s
    while t:
        base = (t * 16 + s) * 256
        first = raw[base + 5] + 256 * raw[base + 6]
        for k in range(122):
            dt, ds = raw[base + 12 + 2 * k], raw[base + 13 + 2 * k]
            if dt:
                res[first + k] = bytes(raw[(dt * 16 + ds) * 256:(dt * 16 + ds) * 256 + 256])
        t, s = raw[base + 1], raw[base + 2]
    return res


def find(raw, prefix):
    for name, t, s in catalog(raw):
        if name.startswith(prefix):
            return sectors(raw, t, s)
    return None


def read(secs, pos, n):
    out = bytearray()
    for p in range(pos, pos + n):
        sec = secs.get(p // 256)
        out.append(sec[p % 256] if sec else 0)
    return bytes(out)


def crypt(data, pw, y, m, d):
    ca = (d * 7 + m * 3 + y) & 255
    out = bytearray()
    for i, b in enumerate(data):
        out.append(b ^ ((pw[i % len(pw)] + ca) & 255))
        ca = (ca + 29) & 255
    return bytes(out)


def entry(raw, prefix, pw, y, m, d):
    secs = find(raw, prefix)
    if secs is None:
        return None
    ln = read(secs, d * 1280, 2)
    n = ln[0] + 256 * ln[1]
    return crypt(read(secs, d * 1280 + 2, n), pw, y, m, d)


def flags(raw, prefix, pw, y, m):
    secs = find(raw, prefix)
    return crypt(read(secs, 0, 32), pw, y, m, 0) if secs else None


def month_prefix(y, m):
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src" / "tools"))
    import nbyte
    return nbyte.encode("일기") + b" " .translate(bytes(range(128)) + bytes(range(128))) if False else \
        (nbyte.encode("일기") + bytes([0xA0]) + f"{2000 + y}-{m:02d}".encode().translate(bytes(b | 0x80 for b in range(256))))
