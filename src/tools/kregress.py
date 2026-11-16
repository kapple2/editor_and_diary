"""KEDIT regression run: all the test_kedit*.py scripts with a given build of KEDIT, keeping every screenshot and what
the tests print; then compare two such runs. For changes that must not change what the program does.

  python src/tools/kregress.py run <tag> [KEDIT.bin kedit.lbl]   (default: the current build in src/kedit/build)
  python src/tools/kregress.py run <tag> -only 2,11
  python src/tools/kregress.py cmp <tagA> <tagB>

Results in work/regress/<tag>/ (k<N>.json, k<N>_<run>_<nn>.png). Saturn card: set KEDIT_MAME_ARGS=-sl0 ssram.
About 6 minutes for a run."""
import contextlib, io, json, runpy, shutil, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import session as s

REG = s.ROOT / "work" / "regress"


def run_all(tag, binp, lbl, only=None):
    out = REG / tag
    out.mkdir(parents=True, exist_ok=True)
    binb = Path(binp).read_bytes()
    labels = {ln.split()[2].lstrip("."): int(ln.split()[1], 16) for ln in Path(lbl).read_text().splitlines()}
    build0, run0 = s.mkdisk.build, s.run

    def build(disk):
        r = build0(disk)
        s.acx("-d", disk, "KEDIT")                           # the program under test
        s.acx("-p", disk, "KEDIT", "bin", "0x4000", inp=binb)
        return r

    s.mkdisk.build = build
    s.label = lambda name: labels[name]
    for n in range(1, 15):
        if only and str(n) not in only:
            continue
        shots, frames = [], []

        def run(name, steps, *a, **k):
            disk, pngs = run0(name, steps, *a, **k)
            for i, p in enumerate(pngs):
                dst = out / f"k{n}_{name}_{i:02d}.png"
                shutil.copy(p, dst)
                shots.append(dst.name)
            frames.extend(s.frames(name))
            return disk, pngs

        s.run = run
        for old in out.glob(f"k{n}_*.png"):
            old.unlink()
        buf = io.StringIO()
        buf.reconfigure = lambda **k: None                   # (some tests set the encoding of stdout)
        try:
            with contextlib.redirect_stdout(buf):
                runpy.run_path(str(Path(__file__).parent / f"test_kedit{n}.py"), run_name="__main__")
        except BaseException as e:                           # a failed assert in a test is a result too
            buf.write(f"\nEXCEPTION {type(e).__name__}: {e}\n")
        text = buf.getvalue().replace(str(s.ROOT), "")
        (out / f"k{n}.json").write_text(json.dumps({"shots": shots, "frames": frames, "out": text}))
        bad = [w for w in ("MISMATCH", "EXCEPTION", "TIMEOUT") if w in text]
        print(f"{tag} test {n}: {len(shots)} screens, {sum(frames)} frames{' ' + ' '.join(bad) if bad else ''}", flush=True)


def compare(a, b):
    from PIL import Image, ImageChops
    bad = 0
    import re
    for ja in sorted((p for p in (REG / a).glob("k*.json") if re.fullmatch(r"k\d+", p.stem)), key=lambda p: int(p.stem[1:])):
        jb = REG / b / ja.name
        if not jb.exists():
            continue
        ra, rb = json.loads(ja.read_text()), json.loads(jb.read_text())
        notes = []
        if ra["shots"] != rb["shots"]:
            notes.append("the screens are not the same set")
        if ra["out"] != rb["out"]:
            notes.append("the printed results DIFFER")
        for w in ("MISMATCH", "EXCEPTION", "TIMEOUT"):
            if w in rb["out"]:
                notes.append(w + " in " + b)
        for name in ra["shots"]:
            pa, pb = REG / a / name, REG / b / name
            if pb.exists() and ImageChops.difference(Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")).getbbox():
                notes.append(name + " DIFFERS")
        bad += len(notes)
        print(f"{ja.stem}: {'same' if not notes else '; '.join(notes)}   frames {sum(ra['frames'])} -> {sum(rb['frames'])}")
    print("ALL THE SAME" if not bad else f"{bad} DIFFERENCES")


if __name__ == "__main__":
    if sys.argv[1] == "run":
        args = sys.argv[3:]
        only = None
        if "-only" in args:
            i = args.index("-only")
            only = args[i + 1].split(",")
            del args[i:i + 2]
        b = s.ROOT / "src" / "kedit" / "build"
        run_all(sys.argv[2], *(args[:2] if args else (b / "KEDIT.bin", b / "kedit.lbl")), only=only)
    else:
        compare(sys.argv[2], sys.argv[3])
