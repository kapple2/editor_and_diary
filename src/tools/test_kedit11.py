"""KEDIT in MAME: the catalog (목록 / LS) lets you choose a file and open it; E and the catalog ask before dropping
unsaved changes; Ctrl-G copies a line and Ctrl-P pastes it (also the commands CP and PU); the full width of 46 columns.
Ctrl-J and Ctrl-K are sent with the K step (MAME types Ctrl-J as Return)."""
import session as s

W = "W 60"
UP, DOWN = "K 0B", "K 0A"
A, B, C = s.hi("ALPHA\r"), s.hi("BRAVO\rBRAVO2\r"), s.hi("CHARLIE\r")


def seed(disk):
    # the sample files SUTRA1, SUTRA2 (on the boot disk since 2026-11-13) would move the rows of the catalog: take them off here
    for name in ("SUTRA1", "SUTRA2"):
        s.acx("-d", disk, name)
    s.put_text(disk, "AAA", A)
    s.put_text(disk, "BBB", B)
    s.put_text(disk, "CCC", C)


steps = [W, "T <ES>LS", "E", "W 300", "S list",
         DOWN, "W 100", "S second row", DOWN, "W 100", "S third row", UP, "W 100", UP, "W 100", UP, "W 100", "S back at the top",
         "T <ES>", "W 200", "S ESC back to the text",
         # open from the list: select AAA (a text that is not changed opens at once)
         W, "T <ES>LS", "E", "W 300"] + [DOWN] * 7 + ["W 100", "S AAA selected", "E", "W 600", "S AAA open",
         # changed text: the list asks; another key cancels, N drops, Y saves
         "T XY", W, "T <ES>LS", "E", "W 300"] + [DOWN] * 8 + ["E", "W 200", "S asks", "T Q", "W 200", "S cancelled",
         W, "T <ES>LS", "E", "W 300"] + [DOWN] * 8 + ["E", "W 200", "T N", "W 600", "S BBB open (the change to AAA dropped)",
         # E with a changed text asks too; Y saves it
         "T Z", W, "T <ES>E CCC", "E", "W 200", "S E asks", "T Y", "W 900", "S CCC open",
         # copy a line and paste it twice, with the keys and with the commands
         "T <x07>", W, "T <x10>", W, "T <x10>", W, "T <ES>CP", "E", W, "T <ES>PU", "E", W,
         "S copied and pasted", "T <ES>W", "E", "W 900", W, "T <ES>Q!", "E", "W 600"]


def ok(label, cond, extra=""):
    print(label + ":", "OK" if cond else f"MISMATCH {extra}")


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf8", errors="replace")
    d, p = s.run("k11", steps, seed=seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "k11.png", cols=3)
    print("screens:", [x.name for x in p])
    ok("AAA unchanged (the change to it was dropped)", s.read_file(d, "AAA") == A, repr(s.read_file(d, "AAA")))
    ok("BBB: the change typed in it was saved by Y before CCC opened", s.read_file(d, "BBB") == s.hi("Z") + B, repr(s.read_file(d, "BBB")))
    got = s.read_file(d, "CCC")
    # CCC opened from E; Ctrl-G, Ctrl-P twice, CP, PU: the line and three pastes
    ok("CCC: the line copied and pasted three times", got == C * 4, repr(got))
