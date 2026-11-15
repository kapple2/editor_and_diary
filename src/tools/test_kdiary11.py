"""KDIARY 1.08: saving trims the text. (1) day 2026-11-16: "AB   ", a line of spaces, "CD  ", then two empty lines:
the file holds "AB", an empty line (the spaces removed), "CD", and ends with one Return: "AB\r\rCD\r".
The editor still shows the spaces. (2) day 2026-11-17: "X" saved, Ctrl-S removes it, ESC W: the question; N = not
saved (the entry stays); ESC W again, Y = the entry is deleted (its flag is 0)."""
import shutil
import dsession as s
import dverify as v
from pathlib import Path

PW = b"SECRET"
steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 20261116", "E", "W 120",
         "E", "W 250", "S editor", "T AB   ", "E", "T    ", "E", "T CD  ", "E", "E", "E", "W 30",
         "T <ES>", "T W", "E", "W 300", "S saved1", "T <ES>", "T Q", "E", "W 300", "S back1",
         "T 20261117", "E", "W 120", "E", "W 250", "T X", "W 30", "T <ES>", "T W", "E", "W 300",
         "T <x13>", "W 30", "S emptied", "T <ES>", "T W", "E", "W 120", "S askempty", "T N", "W 120", "S notsaved",
         "T <ES>", "T W", "E", "W 120", "T Y", "W 300", "S deleted", "T <ES>", "T Q", "E", "W 300", "S back2"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    d, p = s.run("d11", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "d11_sheet.png", cols=3)
    raw = Path(d).read_bytes()
    m = v.month_prefix(26, 11)
    got = v.entry(raw, m, PW, 26, 11, 16)
    print("trim:", "OK" if got == s.hi("AB\rCD\r".replace("AB\rCD", "AB\r\rCD")) else f"MISMATCH got {got!r}")
    f = v.flags(raw, m, PW, 26, 11)
    print("17 deleted:", "OK" if f[17] == 0 else f"MISMATCH flag {f[17]}")
