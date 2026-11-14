"""KEDIT in MAME, Backspace in Hangul: the syllable being typed loses one key at a time; a finished syllable goes
whole. 1: 안녕, 3 x Backspace -> 안. 2: 안녕, 4 x -> nothing. 3: 갑사, 3 x -> nothing (사 key by key, then 갑 whole).
4: 안녕, cursor left and right (typing is over), Backspace -> 안."""
import session as s

steps = ["T <CA>DKSSUD<x13><x13><x13>", "E", "S one",
         "T DKSSUD<x13><x13><x13><x13>", "E",
         "T RKQTK<x13><x13>", "S two", "T <x13>", "E",
         "T DKSSUD<x02><x15><x13><CA>Z", "E",          # Z must land where the deleted character was
         "T ABC<x13>D", "E",                           # ABD
         "T ABC<x02><x02><x04>X", "S four",            # left twice, Ctrl-D, X: AXC
         "W 60", "T <ES>W T8", "E", "W 900",
         "W 60", "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k7", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "k7.png", cols=3)
    got = s.read_file(d, "T8")
    run = chr(0x0B) + "DKS" + chr(0x01)
    want = s.hi(run + "\r\r\r" + run + "Z\rABD\rAXC\r")
    print("OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
