"""KDIARY v1.01: in the entry list the right arrow / Ctrl-U moves down one entry, the left arrow / Ctrl-H moves up
(they used to turn pages). Screens: list, after Ctrl-U, after Ctrl-U again, after Ctrl-H, after Ctrl-J. Look at the sheet."""
import shutil
import dsession as s

steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 2026-11-14", "E", "W 120",
         "E", "W 250", "S editor", "T <ES>", "T Q", "E", "W 400", "S cal",
         "T L", "W 900", "S list", "T <x15>", "W 90", "S right1", "T <x15>", "W 90", "S right2",
         "T <x08>", "W 90", "S left", "K 0A", "W 90", "S ctrlj", "T <ES>", "W 300", "S back"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    d, p = s.run("d9", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "d9_sheet.png", cols=3)
