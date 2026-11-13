"""KEDIT in MAME, scrolling one row at a time: moving the cursor below the bottom row or above the top row must scroll
the text rows (K-HANGEUL scrolls: Return at the bottom, Ctrl-V at the top) and draw one row, not redraw the screen.
Checked three ways: the frames each key took, the screen against the same screen redrawn with Ctrl-L, and the file
saved afterwards (unchanged). Ctrl-J and Ctrl-K are sent with the K step: MAME's keyboard types Ctrl-J as Return."""
import session as s
from test_kedit2 import seed, SRC

W = "W 60"
DOWN, UP, REDRAW, PGDN = "K 0A", "K 0B", "K 0C", "K 1A"
LIMIT = 90          # frames: a one-row scroll takes about 30, a full redraw 160 or more


def check(label):
    return ["W 200", "S " + label, REDRAW, "W 400", "S " + label + " redrawn"]


steps = [W, "T <ES>E DIARY", "E", "W 900"]
steps += [DOWN] * 22 + check("down")                 # 14 moves on the screen, then 8 scrolls up
steps += [UP] * 20 + check("up")                     # 14 moves, then 6 scrolls down
steps += [UP] * 6 + check("top")                     # to the first line and 4 more (nothing to do)
steps += [W, "T <ES>NU", "E", "W 400", PGDN, "W 400", PGDN, "W 600"]
steps += [UP] * 20 + check("numbers up")             # the same with line numbers shown
steps += [DOWN] * 20 + check("numbers down")
steps += [W, "T <ES>W OUT", "E", "W 900", W, "T <ES>Q", "E", "W 600"]

if __name__ == "__main__":
    d, p = s.run("k8", steps, seed=seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "k8.png", cols=2)
    for i in range(0, len(p), 2):
        print(p[i].name, "equals its redraw:", "OK" if p[i].read_bytes() == p[i + 1].read_bytes() else "MISMATCH")
    # one log entry per key, in step order: every Ctrl-J / Ctrl-K must be quick
    fr = s.frames("k8")
    keys = []
    for st in steps:
        if st[0] == "T":
            keys += ["T"] * len(st[2:].replace("<ES>", "e"))
        elif st[0] in "EK":
            keys.append(st)
    slow = [(i, f) for i, (k, f) in enumerate(zip(keys, fr)) if k in (DOWN, UP) and f > LIMIT]
    print("frames per key:", fr)
    # (the Return of the last command, Q, is not logged: KEDIT has ended)
    print("log entries:", "OK" if len(fr) == len(keys) - 1 else f"MISMATCH {len(fr)} entries for {len(keys)} keys")
    print("cursor keys never redraw the screen (limit %d frames, slowest %d):" % (LIMIT, max(f for k, f in zip(keys, fr) if k in (DOWN, UP))),
          "OK" if not slow else f"MISMATCH {slow}")
    print("file unchanged:", "OK" if s.read_file(d, "OUT") == SRC else "MISMATCH")
