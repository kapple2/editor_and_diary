"""KEDIT in MAME on a real file (testdata/sample.kbas in K-HANGEUL's N-byte form): page down, line numbers, go to
line, Hangul search, edits (append Hangul, delete a unit, Hangul backspace, join lines, delete a line), insert a file,
save under a new name. The saved bytes are compared with the same edits done in Python."""
import session as s
from session import nbyte

_ALL = nbyte.encode((s.ROOT / "src" / "tools" / "testdata" / "sample.kbas").read_text(encoding="utf8"))
SRC = _ALL[:_ALL.rindex(bytes([0x8D]), 0, 6500) + 1]      # whole lines, about 6,500 bytes: it must fit the text space
INS = s.hi("AB\rCD\r")


def seed(disk):
    s.put_text(disk, "DIARY", SRC)
    s.put_text(disk, "INS", INS)


def expected():
    L = SRC.rstrip(b"\x8d").split(b"\x8d")
    L[0] += b"\xa0\x8b\xad\xcd\xd8\x81"            # " 끝"
    L[1] = L[1][1:]                                # first unit of line 2 (a digit)
    L[2] += b"\xa0\x8b\xc7\xcb\xc6\x81"            # " 할" (typed G K S, backspace, F)
    L[3] += L[4]; del L[4]                         # join lines 4 and 5
    del L[4]                                       # delete the line after it
    L[-1] += b"\xc1\xc2"; L.append(b"\xc3\xc4")    # insert "AB<CR>CD" at the end
    return b"\x8d".join(L) + b"\x8d"


W = "W 60"
steps = [W, "T <ES>E DIARY", "E", "W 900", "S loaded",
         "T <x1A><x1A>", "W 300", "S pgdn",
         W, "T <ES>NU", "E", "W 300", "S nums",
         W, "T <ES>G 30", "E", "W 300", "S goto30",
         W, "T <ES>/<CA>DLFRL<CA>", "E", "W 300", "S find",
         "T <x06>", "W 300", "S find2",
         W, "T <ES>NU", "E",
         W, "T <ES>G 1", "E", "T <x0E> <CA>-MX<CA>",
         W, "T <ES>G 2", "E", "T <x0F><x04>",
         W, "T <ES>G 3", "E", "T <x0E> <CA>GKS<x13>F<CA>",
         W, "T <ES>G 5", "E", "T <x0F><x13>",
         W, "T <ES>G 5", "E", "T <x19>", "W 300", "S edited",     # (MAME types $0A as Return, so no Ctrl-J here)
         "T <x05>", W, "T <ES>R INS", "E", "W 900", "S inserted",
         W, "T <ES>W DIARY2", "E", "W 1200", "S saved",
         W, "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k2", steps, seed=seed)
    print("source", len(SRC), "bytes; frames per key (max 12):", sorted(s.frames("k2"), reverse=True)[:12])
    got = s.read_file(d, "DIARY2") or b""
    want = expected()
    print("saved", len(got), "bytes, expected", len(want))
    if got == want:
        print("OK")
    else:
        g, w = got.split(b"\x8d"), want.split(b"\x8d")
        for i, (a, b) in enumerate(zip(g, w)):
            if a != b:
                print("MISMATCH: first different line", i + 1, "\n got ", nbyte.decode(a), "\n want", nbyte.decode(b))
                break
        else:
            print("MISMATCH: line counts", len(g), len(w))
    s.sheet(p, s.ROOT / "work" / "sess" / "k2.png", cols=3)
