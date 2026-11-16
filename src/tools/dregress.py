"""KDIARY regression run: the same key scripts on two builds of KDIARY, then compare every screenshot and every file
the program wrote. For changes that must not change what the program does (size and speed work).

  python src/tools/dregress.py run <tag> [KDIARY.bin kdiary.lbl]   run all scenarios with that binary (default: the
                                                                   current build in src/kdiary/build), results in
                                                                   work/regress/<tag>/
  python src/tools/dregress.py run <tag> -only C,D                 only those scenarios
  python src/tools/dregress.py cmp <tagA> <tagB>                   compare two runs: screens, files, frames per key

Scenarios (each starts from a fresh disk or from the disk an earlier one left):
  A first run, password, date, an entry          B (A's disk) wrong password, append, Hangul entry, calendar keys, list, delete
  C the editor: every key and command            D (B's disk) ESC commands, CHD, LS, help, data disk 2
  E a data disk without a diary, an orphan disk  F a long entry: scrolling, page keys, the 1,200-byte limit
  K the keys of F with another key map in the file KEYS (its screens must differ from F's: the map was read)
About 10 minutes for a run."""
import json, shutil, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import dsession as s
import dverify as v

REG = s.ROOT / "work" / "regress"
START = ["W 60", "E", "W 30"]                                     # the drive question: RETURN
FIRST = START + ["T Y", "W 30", "T SECRET", "E", "W 20", "T SECRET", "E", "W 30", "T 20261114", "E", "W 120"]
LOGIN = START + ["T SECRET", "E", "W 30", "T 20261114", "E", "W 120"]

A = ["W 60", "S drive", "E", "W 30", "S ask", "T Y", "W 30", "S pw1", "T SECRET", "E", "W 20", "T SECRE", "E", "W 60", "S diff",
     "T x", "W 30", "T SECRET", "E", "W 20", "T SECRET", "E", "W 30", "S date", "T 20261314", "E", "W 60", "S baddate", "T x", "W 30",
     "T 2026111<x13>14", "E", "W 120", "S cal",
     "E", "W 200", "S edit0", "T Today is good.", "E", "T Second line.", "W 20", "S edit1",
     "T <ES>", "T Q", "E", "W 60", "S unsaved", "T <ES>", "T W", "E", "W 400", "S saved", "T <ES>Q", "E", "W 400", "S cal2"]

B = ["W 60", "E", "W 30", "T BAD", "E", "W 60", "S wrongpw", "T x", "W 30", "T SECRET", "E", "W 30", "T 20261114", "E", "W 120",
     "E", "W 200", "S loaded", "T <x05>", "E", "T Third.", "T <ES>", "T WQ", "E", "W 400", "S saved2",
     "T <RT>", "W 30", "S day15", "T <LT>", "T <LT>", "W 30", "S day13", "T <CK>", "W 30", "S up", "K 0A", "W 30", "K 0A", "W 30", "S down",
     "T N", "W 250", "S next", "T P", "W 250", "T P", "W 250", "S prev", "T >", "W 250", "S year+", "T <", "W 250", "T ,", "W 250", "S year-",
     "T T", "W 250", "S today", "T 2026", "W 30", "S digits", "T <ES>", "W 250", "S digesc", "T 20269999", "W 120", "S baddate", "T x", "W 250",
     "T 20261130", "W 250", "T <RT>", "W 250", "S dec1",
     "E", "W 200", "T December.", "E", "T <CA>dkssud<CA>", "T <ES>", "T WQ", "E", "W 500", "S dec_saved",
     "T 20270105", "W 250", "E", "W 200", "T <CA>toago<CA> 2027", "T <ES>", "T WQ", "E", "W 500",
     "T 20261120", "W 250", "E", "W 200", "T Twenty.", "T <ES>", "T WQ", "E", "W 500", "S nov20",
     "T L", "W 900", "S list", "K 0A", "W 60", "S ldown", "K 0A", "W 60", "K 0A", "W 60", "K 0A", "W 60", "S lend",
     "T <CK>", "W 60", "T <CK>", "W 60", "S lup", "T >", "W 60", "S lpgdn", "T <", "W 300", "S lpgup",
     "T 20261201", "W 500", "S ljump", "T 2030", "W 30", "S ldig", "T 0101", "W 500", "S ljlast", "T <CK>", "W 60", "E", "W 300", "S lopen",
     "T <ES>", "T Q", "E", "W 400", "S lback",
     "T 20261120", "W 250", "T D", "W 60", "S askdel", "T N", "W 400", "S kept", "T D", "W 60", "T Y", "W 500", "S deleted",
     "T D", "W 60", "S nodel", "T Q", "W 200", "S end"]

C = FIRST + ["E", "W 200",
     "T The quick brown fox jumps over the lazy dog and keeps running far away.", "E", "T Line two.", "E", "T Line three is here.", "S c1",
     "E", "T <CA>dkssudgktpdy rkatkgkqslek", "S c2", "T gksrmf", "T <x13>", "S c3", "T <x13>", "T <x13>", "S c4", "T <x7F>", "T <x13>", "T <x13>",
     "T <x13>", "S c5", "T <CA>", "T <x14>", "S top", "T <RT><RT><RT>", "K 0A", "S down", "T <x0E>", "S eol", "T <RT>", "S nextline",
     "T <LT>", "T <x02>", "S left", "T <x0F>", "S bol", "T <CK>", "T <CK>", "S up", "T <x05>", "S end",
     "T <x13>", "T <x13>", "S bsp", "T <x0F>", "T <x13>", "S join", "E", "S split", "T <x14>", "T <x0E>", "T <x04>", "S joinnext",
     "E", "T <x14>", "T <RT><RT><RT><RT>", "T <x18>", "S deol", "T <x04>", "T <x04>", "S delf",
     "K 0A", "T <x19>", "S delln", "T <x10>", "T <x10>", "S paste", "T <x07>", "S copied", "T <x05>", "T <x10>", "S paste2",
     "T <x11>", "T abc", "T <x11>", "T def", "K 09", "T x", "S case", "T <x0C>", "S redraw",
     "T <x05>", "T <x0F>", "T <RT><RT>", "T <x18>", "S deolhan", "T <CA>", "T dk", "T <CA>", "T z", "S mixed",
     "T <x05>", "T <LT><LT><LT>", "T <CA>rk<CA>", "T Q", "S inshan", "T <LT><LT>", "E", "S splithan",
     "T <ES>", "T NU", "E", "S nums", "T <ES>", "T G 3", "E", "S goto3", "T <ES>", "T 2", "E", "S goto2", "T <ES>", "T I", "E", "S info",
     "T <ES>", "T CP", "E", "T <ES>", "T PU", "E", "S cppu", "T <ES>", "T D 2", "E", "S d2", "T <ES>", "T DP", "E", "S dp",
     "T <ES>", "T FOO", "E", "S badcmd", "T <ES>", "T <CA>ehdna<CA>", "E", "W 300", "S help", "T x", "W 300", "S afterhelp",
     "T <ES>", "T H", "E", "W 300", "T <ES>", "T NU", "E", "S helpesc", "T <ES>", "T <CA>wjwkd<x13><x13><CA>X", "T <x18>", "S cmdbs", "T <ES>",
     "T <ES>", "T WQ", "E", "W 500", "S saved", "E", "W 300", "S reopen", "T <ES>", "T DA", "E", "S sure", "T <ES>", "T DA!", "E", "S empty",
     "T <ES>", "T W", "E", "W 500", "T <ES>", "T Q", "E", "W 400", "S gone"]

LONG = "0123456789 abcdefghij klmnopqrst uvwxyz ABCDEFGHIJ KLMNO"
F = FIRST + ["E", "W 200"] + [x for i in range(18) for x in (f"T {i:02d} {LONG}", "E")] + ["S f1",
     "T <x17>", "S pgup1", "T <x17>", "T <x17>", "S pgup3", "T <x1A>", "S pgdn", "T <x14>", "S top", "T <x1A>", "T <x1A>", "T <x1A>", "S pgdn3",
     "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "T <CK>", "S ups",
     "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "K 0A", "S downs",
     "T <x05>", "S end", "T <CA>gksrmfdmf Tmqslek dkssudgktpdy<CA>", "E", "T " + LONG, "T " + LONG, "S f2", "T " + LONG, "T " + LONG, "S full",
     "T xyz", "S full2", "T <x14>", "T <x19>", "T <x19>", "S dl", "T <x05>", "T <x10>", "S pst", "T <ES>", "T NU", "E", "S nums", "T <x17>", "S nupg",
     "T <ES>", "T G 12", "E", "S g12", "T <x13>", "T <x0F>", "T <x13>", "S joinl", "T <ES>", "T WQ", "E", "W 600", "S saved",
     "E", "W 300", "S reopen", "T <x05>", "S reend", "T <ES>", "T Q", "E", "W 300", "T L", "W 900", "S list", "E", "W 300", "S lopen",
     "T <ES>", "T Q", "E", "W 300", "T Q", "W 200", "S end"]

D = LOGIN + ["S cal1", "T <ES>", "T CHD D", "W 30", "S typing", "T <ES>", "W 60",
     "T <ES>", "T ?", "E", "W 100", "S help", "T <ES>", "W 60", "T D", "W 30", "S helpesc", "T <ES>", "W 100", "S afteresc",
     "T <ES>", "T ?", "E", "W 100", "T x", "W 100", "S afterhelp", "T <ES>", "T FOO", "E", "W 60", "S badcmd", "T x", "W 60",
     "T <ES>", "T LS", "E", "W 200", "S ls1", "T x", "W 200", "S ls2", "T x", "W 60",
     "T <ES>", "T LS S6,D2", "E", "W 200", "S ls3", "T x", "W 60", "T <ES>", "T <CA>ahrfhr<CA> D2", "E", "W 200", "S ls4", "T x", "W 60",
     "T <ES>", "T LS D9", "E", "W 100", "S lsbad", "T x", "W 60", "T <ES>", "T CHD", "E", "W 100", "S chdnone", "T x", "W 60",
     "T <ES>", "T CHD D2", "E", "W 150", "S pwask", "T BAD", "E", "W 60", "T x", "W 30", "T <ES>", "W 100", "S cancelled",
     "T <ES>", "T CHD S6,D2", "E", "W 150", "T SECRET", "E", "W 250", "S cal2", "E", "W 250", "S edit", "T <ES>", "T Q", "E", "W 300", "S back",
     "T L", "W 900", "S list2", "T <ES>", "W 250", "T <ES>", "T <CA>Rmx<CA>", "E", "W 200", "S end"]

E1 = ["W 60", "T S6,D2", "E", "W 120", "S nodiary", "T n", "W 60", "S again", "T 9", "E", "W 60", "S baddrv", "T x", "W 60",
      "T D2", "E", "W 120", "T Y", "W 60", "S newpw", "T <ES>", "W 200", "S esc"]
E2 = ["W 60", "T D2", "E", "W 150", "S orphan", "T x", "W 60", "S back", "T <ES>", "W 200", "S esc"]


def userfiles(disk):
    """name (hex) -> {sector index: bytes} of every file the program wrote (not the ones mkdiary puts on the disk)."""
    raw = Path(disk).read_bytes()
    skip = [bytes(ord(c) | 0x80 for c in n) for n in ("HELLO", "K-HANGEUL", "FONT", "KSTART", "KDIARY", "KDEXPORT", "KEYS", "KEYCFG")]
    out = {}
    for name, t, sec in v.catalog(raw):
        if not any(name.startswith(k) for k in skip):
            out[name.rstrip(b"\xa0").hex()] = {str(k): d.hex() for k, d in sorted(v.sectors(raw, t, sec).items())}
    return out


def run_all(tag, binp, lbl, only=None):
    out = REG / tag
    out.mkdir(parents=True, exist_ok=True)
    template = REG / "template.dsk"
    if not template.exists():
        s.mkdiary.build(template)
    s.mkdiary.build = lambda disk: shutil.copy(template, disk)      # the same disk for every run; the program is put on below
    s.LBL = Path(lbl)
    binb = Path(binp).read_bytes()
    disks = s.S / "disks"

    def prog(disk):
        s.acx("-d", disk, "KDIARY")
        s.acx("-p", disk, "KDIARY", "bin", "0x4000", inp=binb)

    def seeded(src):
        def f(disk):
            shutil.copy(disks / src, disk)
            prog(disk)
        return f

    def data2(name, src=None):
        d2 = disks / name
        if src:
            shutil.copy(disks / src, d2)
        else:
            s.blank_disk(d2)
        return d2

    def altkeys(disk):
        """Another key map (KEYS): page up/down and left/right change places."""
        prog(disk)
        km = list(range(32))
        km[23], km[26], km[2], km[21] = 26, 23, 21, 2
        s.acx("-d", disk, "KEYS")
        s.acx("-p", disk, "KEYS", "bin", "0x300", inp=bytes(km))

    def orphan():
        d = data2("rgE2_data.dsk", "rgB.dsk")
        s.acx("-d", d, "PWCHK")
        return d

    plan = [("A", A, prog, None), ("K", F, altkeys, None), ("B", B, seeded("rgA.dsk"), None), ("C", C, prog, None), ("F", F, prog, None),
            ("D", D, seeded("rgB.dsk"), lambda: data2("rgD_data.dsk", "rgA.dsk")),
            ("E1", E1, prog, lambda: data2("rgE1_data.dsk")), ("E2", E2, prog, orphan)]
    for name, steps, seed, d2f in plan:
        if only and name not in only:
            continue
        d2 = d2f() if d2f else None
        disk, pngs = s.run("rg" + name, steps, seed, flop2=d2, timeout=1800)
        for old in out.glob(f"{name}_*.png"):
            old.unlink()
        labels = [x[2:] for x in steps if x.startswith("S ")]
        for i, p in enumerate(pngs):
            shutil.copy(p, out / f"{name}_{i:02d}_{labels[i] if i < len(labels) else 'x'}.png")
        res = {"shots": len(pngs), "expected": len(labels), "frames": s.frames("rg" + name), "files": userfiles(disk)}
        if d2:
            res["files2"] = userfiles(d2)
        (out / f"{name}.json").write_text(json.dumps(res))
        print(f"{tag} {name}: {len(pngs)}/{len(labels)} screens, {len(res['frames'])} keys, {sum(res['frames'])} frames", flush=True)


def compare(a, b):
    from PIL import Image, ImageChops
    bad = 0
    import re
    for ja in sorted(p for p in (REG / a).glob("*.json") if re.fullmatch(r"[A-Z][A-Z0-9]*", p.stem)):   # (not the KEDIT k<N>.json of kregress.py)
        jb = REG / b / ja.name
        if not jb.exists():
            print(f"{ja.stem}: not in {b}")
            continue
        ra, rb = json.loads(ja.read_text()), json.loads(jb.read_text())
        notes = []
        for k in ("shots", "files", "files2"):
            if ra.get(k) != rb.get(k):
                notes.append(f"{k} DIFFER")
        if ra["shots"] != ra["expected"]:
            notes.append(f"only {ra['shots']} of {ra['expected']} screens")
        for pa in sorted((REG / a).glob(f"{ja.stem}_*.png")):
            pb = REG / b / pa.name
            if not pb.exists():
                notes.append(f"{pa.name} missing")
            elif ImageChops.difference(Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")).getbbox():
                notes.append(f"{pa.name} DIFFERS")
        fa, fb = ra["frames"], rb["frames"]
        bad += len(notes)
        print(f"{ja.stem}: {'same' if not notes else '; '.join(notes)}   keys {len(fa)}/{len(fb)}, frames {sum(fa)} -> {sum(fb)}")
    print("ALL THE SAME" if not bad else f"{bad} DIFFERENCES")


if __name__ == "__main__":
    if sys.argv[1] == "run":
        args = sys.argv[3:]
        only = None
        if "-only" in args:
            i = args.index("-only")
            only = args[i + 1].split(",")
            del args[i:i + 2]
        b = s.ROOT / "src" / "kdiary" / "build"
        run_all(sys.argv[2], *(args[:2] if args else (b / "KDIARY.bin", b / "kdiary.lbl")), only=only)
    else:
        compare(sys.argv[2], sys.argv[3])
