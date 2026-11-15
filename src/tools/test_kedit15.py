"""KEDIT in MAME: the left arrow / Ctrl-H ($08) moves the cursor left and does not delete (1.6 and later, every model).
ABC, left, X -> ABXC; then ABC, left twice, left, Y -> YABC (the cursor stops at the line start)."""
import session as s

steps = ["T ABC<x08>X", "E", "T ABC<x08><x08><x08><x08>Y", "S left",
         "W 60", "T <ES>W T15", "E", "W 900",
         "W 60", "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k15", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "k15.png", cols=2)
    got = s.read_file(d, "T15")
    want = s.hi("ABXC\rYABC\r")
    print("OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
