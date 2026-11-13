"""KEDIT in MAME, version 1.1 additions: cut a line (Ctrl-Y) and put it back elsewhere (Ctrl-P), put a line back as
it was (Ctrl-R, and again to redo), info, save under a Hangul file name with the Korean command, catalog."""
import session as s

W = "W 60"
steps = ["T AAA", "E", "T BBB", "E", "T CCC", "E",
         W, "T <ES>G 2", "E", "T <x19>",                 # cut BBB
         "T <x14><x10>",                                 # top of the file, paste: BBB AAA CCC
         W, "T <ES>G 2", "E", "T <x0E>XY", "T <x12>", "S undo",   # AAAXY -> AAA
         "T <x12>",                                      # AAAXY again
         "T <x12>",                                      # AAA
         "T Z",                                          # ZAAA (cursor went to the line start)
         "T <x12>",                                      # AAA
         "T <x12>",                                      # ZAAA
         "T <x10>", "S paste",                           # BBB above it: BBB BBB ZAAA CCC
         W, "T <ES>I", "E", "W 200", "S info",
         W, "T <ES><CA>WJWKD DLFRL<CA>", "E", "W 900", "S saved",   # 저장 일기
         W, "T <ES>LS", "E", "W 400", "S catalog", "T  ", "W 300", "S back",
         W, "T <ES>Q", "E", "W 900"]

if __name__ == "__main__":
    d, p = s.run("k4", steps)
    print("frames per key (max 8):", sorted(s.frames("k4"), reverse=True)[:8])
    s.sheet(p, s.ROOT / "work" / "sess" / "k4.png", cols=3)
    got = s.hname_get(d, "DLFRL")
    want = s.hi("BBB\rBBB\rZAAA\rCCC\r\r")
    print("saved:", got)
    print("OK" if got == want else f"MISMATCH want {want!r}")
