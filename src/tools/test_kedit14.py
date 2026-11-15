"""KEDIT 1.8: CHD (디스크) and LS [disk]: the current disk for E, R, W, LS. Programs on disk 1, a blank disk 2 with a text
file NOTE. CHD D2, LS lists disk 2, E NOTE opens it, a change is saved back to disk 2 (W). Then LS S6,D1 is disk 1 again."""
import session as s
from pathlib import Path

D2 = s.S / "disks" / "k14_data.dsk"
steps = ["W 60", "S start", "T <ES>CHD D2", "E", "W 60", "S chd",
         "T <ES>LS", "E", "W 250", "S ls2", "T <ES>", "W 60",
         "T <ES>E NOTE", "E", "W 250", "S note", "T X", "T <ES>W", "E", "W 400", "S saved",
         "T <ES>LS S6,D1", "E", "W 250", "S ls1", "T <ES>", "W 60",
         "T <ES>CHD Z9", "E", "W 60", "S bad",
         "T <ES>H", "E", "W 250", "S khelp", "T <ES>", "T CHD D1", "W 30", "S khelpcmd", "E", "W 60", "S khelpdone",
         "T <ES>H", "E", "W 250", "T x", "W 100", "S khelpback",
         "T <ES>Q!", "E", "W 300"]

if __name__ == "__main__":
    s.acx("-dos140", D2) if not D2.exists() else None
    D2.unlink(missing_ok=True)
    s.acx("-dos140", D2)
    s.acx("-p", D2, "NOTE", "TXT", "0", inp=s.hi("HELLO ON DISK TWO.\r"))
    d, p = s.run("k14", steps, flop2=D2)
    s.sheet(p, s.ROOT / "work" / "sess" / "k14_sheet.png", cols=2)
    got = s.acx("-g", D2, "NOTE").stdout.rstrip(b"\x00")
    print("NOTE on disk 2:", got)
