"""KEDIT in MAME: the free bytes on the status bar, and N (new text) with unsaved changes.
The status bar is read from KEDIT's own copy of what it has drawn (osb), and compared with a screen redrawn by Ctrl-L,
which checks the partial redraw of the bar. N asks when there are unsaved changes: Y saves and starts a new text,
N drops the changes, any other key goes back to the text."""
import session as s

W = "W 60"


def bar(tag):
    return [f"M {s.label('osbn'):X} 1", f"M {s.label('osb'):X} 60", "S " + tag, "K 0C", "W 300", "S " + tag + " redrawn"]


steps = [W, "T A", W] + bar("one letter") + ["T BCDEFGHIJ", W] + bar("ten letters")
steps += ["T <CA>DKSSUD<CA>", W] + bar("hangul")                       # 안녕: Ctrl-K, 6 keys, Ctrl-A = 8 bytes
steps += ["T <x13><x13><x13>", W] + bar("after three backspaces")
steps += [W, "T <ES>W T10A", "E", "W 900", "T Z", W]                   # saved as T10A, then changed
steps += ["T <ES>N", "E", "W 200", "S asks", "T Q", "W 200"] + bar("other key: back to the text")
steps += ["T <ES>N", "E", "W 200", "T Y", "W 900"] + bar("Y: saved, new text")
steps += ["T NEW", W, "T <ES>N", "E", "W 200", "T N", "W 300"] + bar("N: dropped")
steps += ["T X", W, "T <ES>N", "E", "W 200", "T Y", "W 300"] + bar("Y without a name: refused")
steps += [W, "T <ES>W T10B", "E", "W 900", W, "T <ES>Q", "E", "W 600"]


def bars(name):
    """The status texts dumped by the M steps, as (text, free bytes or None)."""
    out, n = [], None
    for ln in s.trace(name).splitlines():
        b = bytes(int(x, 16) for x in ln.split(":")[1].split())
        if len(b) == 1:
            n = b[0]
        else:
            raw = b[:n]
            txt = s.nbyte.decode(raw) if hasattr(s.nbyte, "decode") else raw.decode("latin1")
            out.append(txt)
    return out


def free_of(txt):
    import re
    m = re.search(r"여유 (\d+)", txt)
    return int(m.group(1)) if m else None


def ok(label, cond, extra=""):
    print(label + ":", "OK" if cond else f"MISMATCH {extra}")


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf8", errors="replace")
    d, p = s.run("k10", steps)
    B = bars("k10")
    for b in B:
        print("  bar:", b)
    f = [free_of(b) for b in B]
    # typed: A (1 byte), BCDEFGHIJ (9), 안녕 (Ctrl-K, 6 keys, Ctrl-A = 8). Three backspaces after the Ctrl-A take the two
    # finished syllables whole (the run of 8 bytes) and the J: 9 bytes come back. Then Z (1 byte).
    ok("free bytes follow the typing", f[:5] == [f[0], f[0] - 9, f[0] - 17, f[0] - 8, f[0] - 9], str(f))
    ok("N asks; another key goes back to the text", f[4] == f[3] - 1 and "T10A" in B[4], B[4])
    ok("Y saves", B[5] == "저장했습니다", B[5])
    ok("N drops the changes: an empty text with no name", f[6] == f[0] + 1 and "이름 없음" in B[6] and "*" not in B[6], B[6])
    ok("Y without a file name is refused", B[7] == "파일 이름이 필요합니다", B[7])
    ok("T10A holds the text with the last change", s.read_file(d, "T10A") == s.hi("ABCDEFGHIZ" + chr(13)), repr(s.read_file(d, "T10A")))
    ok("the refused text was kept (saved afterwards as T10B)", s.read_file(d, "T10B") == s.hi("X" + chr(13)), repr(s.read_file(d, "T10B")))
    for i, j in ((0, 1), (2, 3), (4, 5), (6, 7), (9, 10), (13, 14)):       # status bars only; a message goes at the next key
        ok(f"{p[i].name} equals its redraw", p[i].read_bytes() == p[j].read_bytes())
    s.sheet(p, s.ROOT / "work" / "sess" / "k10.png", cols=2)
