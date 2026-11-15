"""KDIARY 1.07: Ctrl-R (undo the cursor line) and Ctrl-F / F (find, wrapping). On the disk of test 3, new day 2026-11-15.
Undo: ONE, RETURN, TWO, Ctrl-R (line 2 back to empty), Ctrl-R (TWO again): expect ONE RETURN TWO.
Find: ALPHA / BETA / GAMMA / ALPHA, then ESC F ALPHA RETURN (wraps to line 1), X: expect XALPHA / BETA / GAMMA / ALPHA."""
import shutil
import dsession as s
import dverify as v
from pathlib import Path

PW = b"SECRET"
undo_steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 20261115", "E", "W 120",
              "E", "W 250", "S editor", "T ONE", "E", "T TWO", "S typed", "T <x12>", "W 30", "S undo1",
              "T <x12>", "W 30", "S undo2", "T <ES>", "T W", "E", "W 300", "T <ES>", "T Q", "E", "W 300", "S back"]
find_steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 20261115", "E", "W 120",
              "E", "W 250", "S editor", "T ALPHA", "E", "T BETA", "E", "T GAMMA", "E", "T ALPHA", "S typed",
              "T <ES>", "T F ALPHA", "E", "W 120", "S found", "T X", "W 30", "S inserted",
              "T <ES>", "T W", "E", "W 300", "T <ES>", "T Q", "E", "W 300", "S back"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    for name, steps, want in (("d10u", undo_steps, "ONE\rTWO"), ("d10f", find_steps, "XALPHA\rBETA\rGAMMA\rALPHA")):
        d, p = s.run(name, steps, seed)
        s.sheet(p, s.ROOT / "work" / "sess" / f"{name}_sheet.png", cols=3)
        raw = Path(d).read_bytes()
        got = v.entry(raw, v.month_prefix(26, 11), PW, 26, 11, 15)
        print(name, "OK" if got == s.hi(want) else f"MISMATCH\n got  {got!r}\n want {s.hi(want)!r}")
