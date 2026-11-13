"""KEDIT in MAME, display and keys: a long Hangul line that wraps, cursor moves by syllable, a character typed
inside a Hangul run, lower case, help screen, quit refused with unsaved changes, one-row scroll at the bottom.
The files written must equal the typed text, and a file loaded and saved again must be unchanged."""
import session as s
from test_kedit2 import seed, SRC

W = "W 60"
HAN = "DLFRL" * 12                                 # 일기 x 12: 24 syllables, 48 columns: wraps
steps = [f"T <CA>{HAN}<CA>", "S wrap",
         "T <x02><x02><x02><x02><x02>", "S left5",       # five syllables back
         "T 7", "S split",                                # a digit inside the run splits it
         "T <x0E>", "E", "T <x11>abc<x11>XY", "S lower",  # lower case, then upper again
         W, "T <ES>H", "E", "W 300", "S help", "T <x0F>", "W 300",
         W, "T <ES>Q", "E", "W 200", "S unsaved",
         W, "T <ES>W HAN", "E", "W 900",
         W, "T <ES>E DIARY", "E", "W 900",
         "T <x1A>", "W 300", "S pgdn", "T <x0E><x15>", "W 300", "S scroll1",
         "T <x15><x15><x15>", "T <x0E><x15>", "W 300", "S scroll2",
         "T <x17>", "W 300", "S pgup",
         W, "T <ES>W DIARY3", "E", "W 900",
         W, "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k3", steps, seed=seed)
    print("frames per key (max 8):", sorted(s.frames("k3"), reverse=True)[:8])
    s.sheet(p[:4], s.ROOT / "work" / "sess" / "k3a.png", cols=2)
    s.sheet(p[4:], s.ROOT / "work" / "sess" / "k3b.png", cols=2)
    han = s.read_file(d, "HAN") or b""
    syl = ["DLF", "RL"] * 12
    run = lambda k: "\x0b" + k + "\x01"
    want = s.hi(run("".join(syl[:-5])) + "7" + run("".join(syl[-5:])) + "\rabcXY\r")
    print("HAN", "OK" if han == want else f"MISMATCH\n got  {han!r}\n want {want!r}")
    d3 = s.read_file(d, "DIARY3") or b""
    print("DIARY3", "OK" if d3 == SRC else f"MISMATCH {len(d3)} vs {len(SRC)}")
