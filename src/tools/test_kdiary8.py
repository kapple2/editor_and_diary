"""KDIARY: ESC on the calendar = command: change the data disk (D2). The disk is shown at the top of the calendar and in the
editor's status bar. Cancel with ESC at the password question (the old disk stays), then change for real."""
import shutil
import dsession as s

def seed(disk):
    shutil.copy(s.S / "disks" / "d3.dsk", disk)
    s.acx("-d", disk, "KDIARY")
    s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=(s.ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())

steps = ["W 60", "E", "W 30", "T SECRET", "E", "W 30", "T 20261114", "E", "W 150", "S cal1",
         "T <ES>", "T CHD D", "W 30", "S typing", "T <ES>", "W 60",
         "T <ES>", "T ?", "E", "W 100", "S help", "T <ES>", "W 60", "T D", "W 30", "S helpesc", "T <ES>", "W 100", "S afteresc",
         "T <ES>", "T ?", "E", "W 100", "T x", "W 100", "S afterhelp",
         "T <ES>", "T FOO", "E", "W 60", "S badcmd", "T x", "W 60",
         "T <ES>", "T LS", "E", "W 200", "S ls1", "T x", "W 200", "S ls2", "T x", "W 60",
         "T <ES>", "T LS S6,D2", "E", "W 200", "S ls3", "T x", "W 60",
         "T <ES>", "T <CA>ahrfhr<CA> D2", "E", "W 200", "S ls4", "T x", "W 60",
         "T <ES>", "T CHD D2", "E", "W 150", "S pwask", "T BAD", "E", "W 60", "T x", "W 30",
         "T <ES>", "W 100", "S cancelled",
         "T <ES>", "T CHD S6,D2", "E", "W 150", "T SECRET", "E", "W 250", "S cal2",
         "E", "W 250", "S edit", "T <ES>", "T Q", "E", "W 300", "S back",
         "T <ES>", "T Q", "E", "W 200", "S end"]

if __name__ == "__main__":
    d2 = s.S / "disks" / "d8_data.dsk"
    shutil.copy(s.S / "disks" / "d6_data.dsk", d2)
    d, p = s.run("d8", steps, seed, flop2=d2)
    s.sheet(p, s.ROOT / "work" / "sess" / "d8_sheet.png", cols=3)
