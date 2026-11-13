"""KEDIT in MAME, typing ahead: a key that arrives during a full redraw stops the redraw, and the screen is drawn
once after the last key. Three page-downs typed one by one (each waits for the screen) and three typed ahead must end
on the same screen; the file saved afterwards must be unchanged."""
import session as s
from test_kedit2 import seed, SRC

W = "W 60"
steps = [W, "T <ES>E DIARY", "E", "W 900",
         "T <x1A><x1A><x1A>", "W 400", "S one by one",
         W, "T <ES>G 1", "E", "W 400",
         "G off", "T <x1A><x1A><x1A>", "W 900", "G on", "W 100", "S typed ahead",
         "G off", "T <x17><x17>X<x14>", "W 900", "G on", "W 100", "S typed ahead 2",   # page up twice, type X, top
         W, "T <ES>W DIARY5", "E", "W 900",
         W, "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k5", steps, seed=seed)
    fr = s.frames("k5")
    print("frames per key:", fr)
    s.sheet(p, s.ROOT / "work" / "sess" / "k5.png", cols=3)
    same = p[0].read_bytes() == p[1].read_bytes()
    print("screens equal:", "OK" if same else "MISMATCH")
    got = s.read_file(d, "DIARY5") or b""
    L = SRC.split(b"\x8d")
    print("typed-ahead X is in the text:", "OK" if len(got) == len(SRC) + 1 and got.count(s.hi("X")) == SRC.count(s.hi("X")) + 1
          else f"MISMATCH {len(got)} vs {len(SRC) + 1}")
