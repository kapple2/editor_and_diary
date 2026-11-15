#!/usr/bin/env python
"""Decrypt the KDIARY diary straight from a DOS 3.3 disk image (.dsk) and convert it to UTF-8 text (Hangul as syllables,
through nbyte.py, which must be in the same folder).

  python kdiary_decrypt.py KDIARY.DSK                       asks for the password, prints every entry
  python kdiary_decrypt.py KDIARY.DSK -p SECRET -o diary.txt
  python kdiary_decrypt.py KDIARY.DSK --month 2026-11       only that month
  python kdiary_decrypt.py KDIARY.DSK --list                only dates and titles

Several disk images can be given (a diary on several disks). The password is checked against the file PWCHK of the
disk (and the day flags of each month). The Apple II Plus types capitals, so the password is tried in capitals first,
then as typed (--exact: only as typed).

Why the image and not files taken off it with AppleCommander: a month file is a random-access file with holes (day d
starts at sector 5 * d), and `acx -g` (14.1) returns the first sectors of the T/S list with zeros for the holes instead
of the sectors that were written, so the entries are missing from its copy. As a fallback the tool also reads a month file
that was copied some other way (not a 143,360-byte image): a full-size copy (holes as zeros) or one with the holes left
out; the year and month then come from the file name (YYYY-MM) or --month, and --pwchk FILE verifies the password.

The scheme (src/kdiary/README.md): slot d (1-31): 2 bytes length (little endian, plain), then the text (N-byte form: bit 7
set, Hangul runs Ctrl-K .. Ctrl-A, lines end with $8D), byte i XORed with (pw[i mod n] + d*7 + month*3 + year + 29*i)
mod 256. Slot 0 (the first sector): $5A, then 31 day flags (1 = an entry), encrypted with d = 0. A casual-viewer lock,
not strong cryptography.
"""
import argparse
import getpass
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nbyte  # noqa: E402  (N-byte Hangul -> Unicode)

MAGIC = 0x5A
PHRASE = bytes(b | 0x80 for b in b"KDIARY!!")
MAXTXT = 1200


def crypt(data, pw, y, m, d):
    ca = (d * 7 + m * 3 + y) & 255
    out = bytearray()
    for i, b in enumerate(data):
        out.append(b ^ ((pw[i % len(pw)] + ca) & 255))
        ca = (ca + 29) & 255
    return bytes(out)


SECTORS = 16
PREFIX = nbyte.encode("일기") + bytes([0xA0])          # the start of a month file's name


def sec(raw, t, s):
    base = (t * SECTORS + s) * 256
    return raw[base:base + 256]


def catalog(raw):
    """[(name bytes, track, sector of the T/S list)]"""
    out = []
    vt = sec(raw, 17, 0)
    t, s = vt[1], vt[2]
    seen = 0
    while t and seen < 64:
        data = sec(raw, t, s)
        for i in range(11, 256 - 34, 35):
            if data[i] in (0, 255):
                continue
            out.append((bytes(data[i + 3:i + 33]), data[i], data[i + 1]))
        t, s = data[1], data[2]
        seen += 1
    return out


def file_sectors(raw, t, s):
    """file sector index -> 256 bytes (the holes of a random-access file are missing)"""
    res, seen = {}, 0
    while t and seen < 256:
        data = sec(raw, t, s)
        first = data[5] + 256 * data[6]
        for k in range(122):
            dt, ds = data[12 + 2 * k], data[13 + 2 * k]
            if dt:
                res[first + k] = sec(raw, dt, ds)
        t, s = data[1], data[2]
        seen += 1
    return res


def full_copy(secs):
    """the file as bytes, holes as zeros"""
    if not secs:
        return b""
    return b"".join(secs.get(k, bytes(256)) for k in range(max(secs) + 1))


def disk_files(raw):
    """({(year, month): file bytes}, PWCHK's first 8 bytes or None)"""
    mon, chk = {}, None
    for name, t, s in catalog(raw):
        name = name.rstrip(bytes([0xA0, 0x20]))
        if name == bytes(b | 0x80 for b in b"PWCHK"):
            chk = full_copy(file_sectors(raw, t, s))[:8]
        elif name.startswith(PREFIX):
            tail = bytes(b & 0x7F for b in name[len(PREFIX):]).decode("ascii", "replace")
            try:
                mon[(int(tail[0:4]), int(tail[5:7]))] = full_copy(file_sectors(raw, t, s))
            except ValueError:
                pass
    return mon, chk


def entry_at(data, pos, pw, y, m, d):
    """The decrypted text of the entry that starts at byte pos, or None if nothing plausible is there."""
    if pos + 2 > len(data):
        return None
    n = data[pos] + 256 * data[pos + 1]
    if not 0 < n <= MAXTXT or pos + 2 + n > len(data):
        return None
    plain = crypt(data[pos + 2:pos + 2 + n], pw, y - 2000, m, d)
    if any(b < 0x80 for b in plain):
        return None
    return plain


def flags_of(data, pw, y, m):
    f = crypt(data[:32], pw, y - 2000, m, 0)
    return f if len(f) == 32 and f[0] == MAGIC and all(x < 2 for x in f[1:]) else None


def month_entries(data, pw, y, m):
    """[(day, N-byte text or None)] for the flagged days; None = the entry could not be found."""
    f = flags_of(data, pw, y, m)
    if f is None:
        return None
    days = [d for d in range(1, 32) if f[d] == 1]
    if not days:
        return []
    if len(data) >= days[-1] * 1280 + 2:                       # a full-size copy: the positions are right
        got = [(d, entry_at(data, d * 1280, pw, y, m, d)) for d in days]
        if all(t is not None for _, t in got):
            return got
    out, sector = [], 1                                          # sector 0 is slot 0
    for d in days:
        found = None
        while sector * 256 < len(data):
            t = entry_at(data, sector * 256, pw, y, m, d)
            if t is not None:
                found = t
                sector += (2 + len(t) + 255) // 256
                break
            sector += 1
        out.append((d, found))
    return out


def main():
    ap = argparse.ArgumentParser(description="Decrypt the KDIARY diary on a disk image to UTF-8.")
    ap.add_argument("files", nargs="+", help="disk image(s) .dsk (or month files copied some other way)")
    ap.add_argument("-p", "--password", help="the password (default: ask)")
    ap.add_argument("--pwchk", help="a PWCHK file (only for month files; a disk image has its own)")
    ap.add_argument("--month", help="YYYY-MM: only this month (for a month file: its month)")
    ap.add_argument("-o", "--output", help="write the text to this file (UTF-8) instead of the screen")
    ap.add_argument("--list", action="store_true", help="only dates and titles")
    ap.add_argument("--exact", action="store_true", help="use the password exactly as typed (no capitals)")
    a = ap.parse_args()

    jobs, chk = [], None
    for name in a.files:
        raw = Path(name).read_bytes()
        if len(raw) == 143360:                                     # a disk image
            mon, c = disk_files(raw)
            if not mon:
                print(f"{name}: no diary month files (일기 20YY-MM) on this disk", file=sys.stderr)
            chk = chk or c
            jobs += [(y, m, data) for (y, m), data in mon.items() if not a.month or a.month == f"{y}-{m:02d}"]
            continue
        mm = re.search(r"([0-9]{4})-([0-9]{2})", a.month if a.month and len(a.files) == 1 else Path(name).name)
        if not mm or not 1 <= int(mm.group(2)) <= 12 or not 2001 <= int(mm.group(1)) <= 2099:
            sys.exit(f"{name}: not a disk image, and no year and month (YYYY-MM) in the file name: give --month YYYY-MM")
        jobs.append((int(mm.group(1)), int(mm.group(2)), raw))
    if a.pwchk:
        chk = Path(a.pwchk).read_bytes()[:8]
    if not jobs:
        sys.exit("nothing to read")
    jobs.sort(key=lambda j: j[:2])

    password = a.password if a.password is not None else getpass.getpass("Password: ")
    tries = [password] if a.exact else [password.upper(), password]
    pw = None
    for cand in tries:
        b = cand.encode("ascii", "replace")
        if chk:
            ok = crypt(chk, b, 0, 0, 0) == PHRASE
        else:
            ok = any(flags_of(data, b, y, m) is not None for y, m, data in jobs)
        if ok:
            pw = b
            break
    if pw is None:
        sys.exit("wrong password (or not a KDIARY month file)")

    lines = []
    for y, m, data in jobs:
        res = month_entries(data, pw, y, m)
        if res is None:
            print(f"{y}-{m:02d}: not readable with this password (skipped)", file=sys.stderr)
            continue
        for d, body in res:
            date = f"{y}-{m:02d}-{d:02d}"
            if body is None:
                print(f"{date}: the entry was not found in the file (a copy with holes left out?)", file=sys.stderr)
                continue
            text = nbyte.decode(body)
            if a.list:
                lines.append(f"{date}  {text.splitlines()[0] if text else ''}")
            else:
                lines += [f"=== {date} ===", text, ""]
    out = "\n".join(lines) + "\n"
    if a.output:
        Path(a.output).write_text(out, encoding="utf-8")
        print(f"wrote {a.output}")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
