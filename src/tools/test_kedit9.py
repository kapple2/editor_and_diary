"""KEDIT in MAME, saving safely: the text goes to KEDIT.TMP first, then the old file is deleted and KEDIT.TMP renamed.
Run 1: save over an existing file; save over a locked file (refused: the file must be unchanged and KEDIT.TMP gone);
save that text under a new name. Run 2: a disk with no room for a second copy (the old file is deleted first, as
before 1.3). No run may leave KEDIT.TMP on the disk. Not tested: an I/O error in the middle of a save."""
import re
import session as s
from test_kedit2 import SRC

W = "W 60"
SMALL = s.hi("AB\rCD\r")


def free(disk):
    return int(re.search(rb"([\d,]+) bytes free", s.acx("-l", disk).stdout).group(1).replace(b",", b""))


def seed1(disk):
    s.put_text(disk, "DIARY", SRC)
    s.put_text(disk, "LOCKED", SMALL)
    s.acx("-k", disk, "LOCKED")


def seed2(disk):
    s.put_text(disk, "DIARY", SRC)
    n = 0
    while free(disk) > 5120:                       # leave 20 sectors or fewer: less than a copy of DIARY needs
        n += 1
        s.acx("-p", disk, f"FILL{n}", "bin", "0x2000", inp=bytes(min(30000, free(disk) - 4608)))


def names(disk):
    return s.acx("-l", disk).stdout.decode("latin1")


steps1 = [W, "T <ES>E DIARY", "E", "W 900", "T X", W, "T <ES>W", "E", "W 1500", "S saved over the old file",
          W, "T <ES>E LOCKED", "E", "W 600", "T Y", W, "T <ES>W", "E", "W 900", "S locked: refused",
          W, "T <ES>W FREE", "E", "W 900", "S saved under a new name",
          W, "T <ES>Q", "E", "W 600"]
steps2 = [W, "T <ES>E DIARY", "E", "W 900", "T X", W, "T <ES>W", "E", "W 2400", "S full disk: saved in place",
          W, "T <ES>Q", "E", "W 600"]


def ok(label, cond):
    print(label + ":", "OK" if cond else "MISMATCH")


if __name__ == "__main__":
    d, p = s.run("k9a", steps1, seed=seed1)
    ok("saved over the old file", s.read_file(d, "DIARY") == s.hi("X") + SRC)
    ok("locked file unchanged", s.read_file(d, "LOCKED") == SMALL)
    ok("saved under a new name", s.read_file(d, "FREE") == s.hi("Y") + SMALL)
    ok("no KEDIT.TMP left", "KEDIT.TMP" not in names(d))
    d2, p2 = s.run("k9b", steps2, seed=seed2)
    print("full disk: bytes free before the save were at most 5120, after:", free(d2))
    ok("full disk: saved in place", s.read_file(d2, "DIARY") == s.hi("X") + SRC)
    ok("full disk: no KEDIT.TMP left", "KEDIT.TMP" not in names(d2))
    s.sheet(p + p2, s.ROOT / "work" / "sess" / "k9.png", cols=2)
