"""KDIARY: delete an entry (D, Y) on the disk of test 3, then a cancelled delete (D, N) on December 1."""
import shutil
import dsession as s
import dverify as v
from pathlib import Path

PW = b"SECRET"
steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 20261114", "E", "W 120",
         "T D", "W 60", "S askdel", "T Y", "W 500", "S deleted",
         "T 20261201", "W 250", "T D", "W 60", "T N", "W 400", "S kept"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    d, p = s.run("d4", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "d4_sheet.png", cols=2)
    raw = Path(d).read_bytes()
    nov, dec = v.month_prefix(26, 11), v.month_prefix(26, 12)
    f1, f2 = v.flags(raw, nov, PW, 26, 11), v.flags(raw, dec, PW, 26, 12)
    print("nov 14 deleted:", "OK" if f1[14] == 0 and f1[0] == 0x5A else f"MISMATCH {f1.hex()}")
    print("dec 1 kept:", "OK" if f2[1] == 1 and v.entry(raw, dec, PW, 26, 12, 1).startswith(s.hi("DECEMBER.")) else f"MISMATCH {f2.hex()}")
