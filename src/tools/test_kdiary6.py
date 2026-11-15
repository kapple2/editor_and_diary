"""KDIARY with its data on drive 2 (programs on disk 1, a blank DOS 3.3 disk in drive 2): first run, write an entry."""
import shutil
import dsession as s
from pathlib import Path

D2 = s.S / "disks" / "d6_data.dsk"
steps = ["W 60", "S drive", "T S6,D2", "E", "W 120", "T Y", "W 30", "T secret", "E", "W 120", "T secret", "E", "W 120",
         "T 20261114", "E", "W 150", "E", "W 200", "T Drive two.", "T <ES>", "T WQ", "E", "W 600", "S saved"]

if __name__ == "__main__":
    s.blank_disk(D2)
    d, p = s.run("d6", steps, flop2=D2)
    s.sheet(p, s.ROOT / "work" / "sess" / "d6_sheet.png", cols=2)
    print(s.acx("-l", d).stdout.decode("latin1"))
    print(s.acx("-l", D2).stdout.decode("latin1"))
