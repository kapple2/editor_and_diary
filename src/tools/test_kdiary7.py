"""KDIARY: a data disk that has no diary (ask before creating one; another key goes back), and a data disk with month
files but no PWCHK (refused)."""
import shutil
import dsession as s

BLANK = s.ROOT / "disk" / "dos33blank.dsk"
steps = ["W 60", "T S6,D2", "E", "W 120", "S nodiary", "T n", "W 60", "S again",
         "T D2", "E", "W 120", "T Y", "W 60", "S newpw"]
steps2 = ["W 60", "T D2", "E", "W 150", "S orphan", "T x", "W 60", "S back"]

if __name__ == "__main__":
    d2 = s.S / "disks" / "d7_data.dsk"
    s.blank_disk(d2)
    d, p = s.run("d7", steps, flop2=d2)
    s.sheet(p, s.ROOT / "work" / "sess" / "d7_sheet.png", cols=2)
    d3 = s.S / "disks" / "d7_orphan.dsk"
    shutil.copy(s.S / "disks" / "d3.dsk", d3)
    s.acx("-d", d3, "PWCHK")
    d, p = s.run("d7b", steps2, flop2=d3)
    s.sheet(p, s.ROOT / "work" / "sess" / "d7b_sheet.png", cols=2)
    print(s.acx("-ls", d3).stdout.decode("latin1")[-200:])
