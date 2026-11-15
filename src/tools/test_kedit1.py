"""KEDIT in MAME: the disk boots straight into the editor (no BASIC program, no K-BASIC). Type English and Hangul,
save, quit; check the saved bytes. Usage: python src/tools/test_kedit1.py"""
import session as s

if __name__ == "__main__":
    steps = ["S open",
             "T 10 PRINT 1", "E",
             "T <CA>GKSRMF<CA> 123", "E",
             "S typed",
             "T <x0C>",
             "W 60", "T <ES>W TEST", "E", "W 600", "S saved",
             "W 60", "T <ES>Q", "E", "W 900", "S quit"]
    d, p = s.run("k1", steps)
    print("frames per key:", s.frames("k1"))
    got = s.read_file(d, "TEST")
    want = s.hi("10 PRINT 1\r\x0bGKSRMF\x01 123\r")  # (KEDIT 1.12: the empty line at the end is not saved)
    print("saved:", got)
    print("OK" if got == want else f"MISMATCH want {want!r}")
    s.sheet(p, s.ROOT / "work" / "sess" / "k1.png")
