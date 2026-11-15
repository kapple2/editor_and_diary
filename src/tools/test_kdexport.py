"""KDEXPORT, two scenarios (nbyte.py converts the plain text files that it writes):
 A: programs and diary on disk 1 (the disk of test 3), the files go to disk 2 (blank).
 B: programs on disk 1, the diary on disk 2 (the disk of test 6), the files go to disk 1."""
import shutil
import dsession as s
import nbyte
from pathlib import Path

s.LBL = s.ROOT / "src" / "kdiary" / "build" / "export.lbl"
KSTART = b"BRUN K-HANGEUL\nBRUN KDEXPORT\n"


def seed_from(src):
    def seed(disk):
        shutil.copy(s.S / "disks" / src, disk)
        s.acx("-d", disk, "KDIARY")
        s.acx("-d", disk, "KDEXPORT")
        s.acx("-p", disk, "KDEXPORT", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDEXPORT.bin").read_bytes())
        s.acx("-d", disk, "KSTART")
        s.acx("-pt", disk, "KSTART", inp=KSTART)
    return seed


def show(disk, label):
    print(label)
    print(s.acx("-l", disk).stdout.decode("latin1"))


if __name__ == "__main__":
    # A
    d2 = s.S / "disks" / "x_out.dsk"
    s.blank_disk(d2)
    d, p = s.run("x1", ["W 60", "S start", "E", "W 30", "T 2", "E", "W 30", "T SECRET", "E", "W 900", "S done", "T x", "W 200", "S exit", "G off", "T CATALOG", "E", "W 300", "S cat"],
                 seed_from("d3.dsk"), flop2=d2)
    s.sheet(p, s.ROOT / "work" / "sess" / "x1_sheet.png", cols=2)
    show(d2, "A: disk 2")
    for n in ("DIARY-2026-11", "DIARY-2026-12"):
        raw = s.acx("-g", d2, n).stdout.rstrip(b"\x00")
        print(n, ascii(nbyte.decode(raw)))
    # B
    d1 = s.S / "disks" / "x2.dsk"
    data = s.S / "disks" / "x_data.dsk"
    shutil.copy(s.S / "disks" / "d6_data.dsk", data)
    d, p = s.run("x2", ["W 60", "T S6,D2", "E", "W 30", "T D1", "E", "W 30", "T SECRET", "E", "W 900", "S done", "T x", "W 200", "S exit"],
                 seed_from("d6.dsk"), flop2=data)
    s.sheet(p, s.ROOT / "work" / "sess" / "x2_sheet.png", cols=2)
    show(d, "B: disk 1")
    raw = s.acx("-g", d, "DIARY-2026-11").stdout.rstrip(b"\x00")
    print("DIARY-2026-11", ascii(nbyte.decode(raw)))
