"""KEDIT user-definable keys in MAME: KEDIT reads the file KEYS at start. The test puts the IJKL key map on its disk:
Ctrl-I up, Ctrl-J left, Ctrl-K down, Ctrl-L right; Tab is Ctrl-V, redraw Ctrl-C, Ctrl-B is free (a bell). The help screen
must show the keys in use. Keys go through K steps (the ring), as MAME types Ctrl-J as Return. Then a KEYCFG session on
the same disk rewrites KEYS. Run:  python src\tools\test_kedit12.py"""
import session as s

IJKL = bytes(11 if k == 9 else 2 if k == 10 else 10 if k == 11 else 21 if k == 12 else 9 if k == 22 else
             12 if k == 3 else 0 if k == 2 else k for k in range(32))


def seed(disk):
    s.acx("-d", disk, "KEYS")
    s.acx("-p", disk, "KEYS", "bin", "0x300", inp=IJKL)


W = "W 60"
steps = [W, "T ABC", "E", "T DEF", "E", "T GHI", W,
         "K 09", "T 1", W,          # Ctrl-I: up (line 2, column 3), type 1 -> DEF1
         "K 0A", "T 2", W,          # Ctrl-J: left -> DEF21
         "K 0B", "T 3", W,          # Ctrl-K: down (to the end of GHI) -> GHI3
         "K 0F", "K 0C", "T 4", W,  # Ctrl-O line start, Ctrl-L right -> G4HI3
         "K 16", "T Z", W,          # Ctrl-V: Tab (a space) -> G4HI3 Z
         "K 02", "T Y", W,          # Ctrl-B is free now: nothing moves -> ...ZY
         "K 03", W, "S keys",       # Ctrl-C: redraw the screen
         "T <ES>H", "E", "W 400", "S help", "T  ", "W 300",
         "T <ES>W T12", "E", "W 900", "T <ES>Q", "E", "W 600",
         # then the Applesoft key setup: KEYCFG on the same disk (keys are posted after a 15 s pause: KEDIT has ended)
         "T RUN KEYCFG", "E", "W 600", "S cfg1", "T NN", "W 250", "S cfg3",       # action 3: cursor up
         "T <x0E>", "W 250", "S cfg3set", "T S", "W 250", "S cfgwarn",            # Ctrl-N takes it: line end has no key
         "T Y", "W 600", "S cfgsaved"]

if __name__ == "__main__":
    d, p = s.run("k12", steps, seed)
    s.sheet(p, s.ROOT / "work" / "sess" / "k12.png", cols=2)
    got = s.read_file(d, "T12")
    want = s.hi("ABC\rDEF21\rG4 ZYHI3\r")
    print("T12", "OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
    got = s.read_file(d, "KEYS")
    want = bytes(IJKL[k] if k != 14 else 11 for k in range(32))      # Ctrl-N now moves up
    print("KEYS", "OK" if got == want else f"MISMATCH\n got  {got!r}\n want {want!r}")
