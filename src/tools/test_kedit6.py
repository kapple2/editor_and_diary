"""KEDIT in MAME, version 1.2: delete commands (DP paragraph, D n lines, DA! everything), Ctrl-X (to the end of the
line, also inside a Hangul run), the left arrow deleting backward, Ctrl-B moving left, Ctrl-O line start, HELP."""
import session as s

W = "W 60"
steps = ["T A1", "E", "T A2", "E", "E", "T B1", "E", "T B2", "E", "T B3", "E", "E", "T C1", "E", "T C2", "E", "T C3Q<x13>",
         W, "T <ES>G 1", "E", W, "T <ES>DP", "E",              # A1 A2 go; the cursor is on the empty line
         W, "T <ES>G 2", "E", W, "T <ES>D 2", "E", "S lines",   # B1 B2 go
         W, "T <ES>G 4", "E", "T <x0E><x02><x18>",              # C1: end, left, delete to the end -> C
         W, "T <ES>G 5", "E", "T <x0E><CA>GKSRMF<CA><x02><x18>",   # C2한글: left one syllable, delete to the end -> C2한
         "T <x0F>#", "S deol",                                  # line start, type # -> #C2한
         W, "T <ES>HELP", "E", "W 300", "S help", "T  ", "W 300",
         W, "T <ES>W T6", "E", "W 900",
         W, "T <ES>DA", "E", "W 100", "S refused",
         W, "T <ES>DA!", "E", "T Z",
         W, "T <ES>SAVE T7", "E", "W 900", "S all",
         W, "T <ES>QUIT", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k6", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "k6.png", cols=3)
    for name, want in (("T6", "\rB3\r\rC\r#C2\x0bGKS\x01\rC3\r"), ("T7", "Z\r")):
        got = s.read_file(d, name)
        print(name, "OK" if got == s.hi(want) else f"MISMATCH\n got  {got!r}\n want {s.hi(want)!r}")
