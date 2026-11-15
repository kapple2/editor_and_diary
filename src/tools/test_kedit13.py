"""KEDIT without a usable KEYS file: the start-up message says so and the classic keys work. Three disks in turn:
no KEYS file, a KEYS file of the wrong size, a KEYS file with an action number above 31. The classic key Ctrl-K (up)
must still move the cursor up (type AB, Return, CD, Ctrl-K, X -> ABX / CD)."""
import session as s

W = "W 60"
steps = [W, "S start", "T AB", "E", "T CD", "K 0B", "T X", W, "S up",
         "T <ES>W T13", "E", "W 900", "T <ES>Q", "E", "W 600"]


def none(disk):
    s.acx("-d", disk, "KEYS")


def short(disk):
    s.acx("-d", disk, "KEYS")
    s.acx("-p", disk, "KEYS", "bin", "0x300", inp=bytes(range(20)))


def junk(disk):
    s.acx("-d", disk, "KEYS")
    s.acx("-p", disk, "KEYS", "bin", "0x300", inp=bytes([99]) + bytes(range(1, 32)))


if __name__ == "__main__":
    for tag, seed in (("no KEYS", none), ("KEYS of 20 bytes", short), ("KEYS with a bad number", junk)):
        d, p = s.run("k13", steps, seed)
        s.sheet(p[:1], s.ROOT / "work" / "sess" / f"k13_{seed.__name__}.png", cols=1)
        got = s.read_file(d, "T13")
        want = s.hi("ABX\rCD\r")
        print(tag, "OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
