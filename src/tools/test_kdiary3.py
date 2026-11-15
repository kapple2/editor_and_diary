"""KDIARY second session on the disk of test 2: wrong password, right password, reopen an entry and add a line,
another month with a Hangul entry, list, delete. The disk is checked with dverify (independent decryption)."""
import shutil
import dsession as s
import dverify as v
from pathlib import Path

PW = b"SECRET"
steps = ["W 60", "S drive", "E", "W 30", "T BAD", "E", "W 60", "S wrongpw", "T x", "W 30",
         "T SECRET", "E", "W 30", "T 20261114", "E", "W 120",
         "E", "W 200", "S loaded",
         "T <x05>", "E", "T Third.", "T <ES>", "T WQ", "E", "W 400", "S saved2",
         "T <RT>", "W 30", "S day15",
         "T 20261201", "W 250", "S dec1",
         "E", "W 200", "T December.", "E", "T <CA>dkssud<CA>", "T <ES>", "T WQ", "E", "W 500", "S dec_saved",
         "T P", "W 250", "S back_nov",
         "T L", "W 400", "S list",
         "T <ES>", "W 250"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d2.dsk", disk)
    # run() rebuilds the disk first: keep the first run's disk, but with the program of this build
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    d, p = s.run("d3", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "d3_sheet.png", cols=3)
    raw = Path(d).read_bytes()
    nov, dec = v.month_prefix(26, 11), v.month_prefix(26, 12)
    print("nov flags", v.flags(raw, nov, PW, 26, 11).hex())
    assert v.entry(raw, nov, PW, 26, 11, 14) == s.hi("TODAY IS GOOD.\rSECOND LINE.\rTHIRD.")
    print("nov 14", v.entry(raw, nov, PW, 26, 11, 14))
    print("dec flags", v.flags(raw, dec, PW, 26, 12).hex())
    print("dec 1", v.entry(raw, dec, PW, 26, 12, 1))
