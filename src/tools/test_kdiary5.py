"""KDIARY: help screen and its return, the all-entries list (page keys, date jump), on the disk of test 3."""
import shutil
import dsession as s

steps = ["W 60", "S drive", "E", "W 30", "T SECRET", "E", "W 30", "T 2026-11-14", "E", "W 120",
         "E", "W 250", "S editor", "T <ES>", "T H", "E", "W 300", "S help", "K 20", "W 120", "S afterhelp",
         "T <ES>", "T Q", "E", "W 400", "S cal",
         "T L", "W 900", "S list", "T >", "W 60", "T 20261201", "W 500", "S jump", "T <ES>", "W 300", "S back"]


def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())


if __name__ == "__main__":
    d, p = s.run("d5", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "d5_sheet.png", cols=3)
