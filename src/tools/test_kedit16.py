"""KEDIT 1.12: the saved file is trimmed: the spaces at the end of each line are not written, and the empty lines after
the last line with text are not written; a Return stays at the end of each line that has text. Text "AB   ", a line of
spaces, "CD  ", two empty lines -> the file holds "AB", an empty line, "CD" + Return: "AB\r\rCD\r" (the editor still
shows the spaces). A text with no characters (only spaces and empty lines) is not saved: a message, no file."""
import session as s

steps = ["W 60", "S start", "T AB   ", "E", "T    ", "E", "T CD  ", "E", "E", "E", "S typed",
         "T <ES>W T16", "E", "W 400", "S saved", "T <ES>", "W 60"]
steps_blank = ["W 60", "S start", "T    ", "E", "E", "S typed", "T <ES>W T17", "E", "W 300", "S refused",
               "T <ES>", "W 60"]

if __name__ == "__main__":
    d, p = s.run("k16", steps)
    s.sheet(p, s.ROOT / "work" / "sess" / "k16.png", cols=3)
    got = s.read_file(d, "T16")
    want = s.hi("AB\r\rCD\r")
    print("trim:", "OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
    d2, p2 = s.run("k16b", steps_blank)
    s.sheet(p2, s.ROOT / "work" / "sess" / "k16b.png", cols=3)
    got2 = s.read_file(d2, "T17")
    print("refused:", "OK" if not got2 else f"MISMATCH file {got2!r}")
