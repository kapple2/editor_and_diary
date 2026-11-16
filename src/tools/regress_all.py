"""Regression run for KEDIT and KDIARY, all steps, no monitoring needed: writes work/regress/REPORT.txt.

  1. baseline: a copy of src (work/regress/baseline/src) with the key and command set from BEFORE the key/command change
     (Ctrl-C was a bell, copy/paste/delete were ESC words, 새/모두지움 names), built with build.py. Its sizes must be
     KEDIT.bin 12029 and KDIARY.bin 16488 (the builds before the change); if not, the report says so.
  2. current: the builds in src/kedit/build and src/kdiary/build.
  3. dregress.py run base / run cur / cmp  (KDIARY, scenarios A-K, screenshots and files)
  4. kregress.py run base / run cur / cmp  (KEDIT, test_kedit1-14, screenshots and printed results)
The differences that are expected (the changed keys and words) show up in cmp; read them there.
Logs of every step: work/regress/logs/. Usage: python src/tools/regress_all.py   (or run_regress.bat)"""
import os, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "work" / "regress"
BASE = REG / "baseline"
LOGS = REG / "logs"
PY = sys.executable
ENV = dict(os.environ, PYTHONIOENCODING="utf8")
REPORT = REG / "REPORT.txt"
lines = []


def say(msg=""):
    print(msg, flush=True)
    lines.append(msg)


def step(name, args, cwd=ROOT):
    """Run one step; its output goes to logs/<name>.txt. Returns the exit code."""
    LOGS.mkdir(parents=True, exist_ok=True)
    t = time.time()
    with open(LOGS / f"{name}.txt", "w", encoding="utf8", errors="replace") as f:
        rc = subprocess.run([PY, *args], cwd=cwd, env=ENV, stdout=f, stderr=subprocess.STDOUT).returncode
    say(f"[{'ok' if rc == 0 else 'rc=' + str(rc)}] {name}  ({time.time() - t:.0f} s)")
    return rc


def rep(path, pairs):
    """Exact replacements in a copied source file; each old text must occur exactly once."""
    s = path.read_text(encoding="utf8")
    for a, b in pairs:
        n = s.count(a)
        if n != 1:
            raise SystemExit(f"baseline edit: {n} matches in {path.name} for: {a[:70]!r}")
        s = s.replace(a, b)
    path.write_text(s, encoding="utf8")


CMD_D = """cmd_d:  jsr argnum
        lda T4
        beq @n
        lda #255
        sta T3
@n:     lda T3
        bne @c
        lda #1
@c:     sta dcnt
@l:     lda hascr
        pha
        jsr k_delln
        pla
        beq @x                  ; that was the last line
        dec dcnt
        bne @l
@x:     rts

"""


def make_baseline():
    if BASE.exists():
        shutil.rmtree(BASE)
    BASE.mkdir(parents=True)
    shutil.copytree(ROOT / "src", BASE / "src",
                    ignore=shutil.ignore_patterns("build", "__pycache__", "*.pdf", "*.png", "*.DSK", "*.dsk"))
    b = BASE / "src"
    # the key map: Ctrl-C was a bell
    rep(b / "common" / "keys.s", [("k_left-1, cmd_dp-1, k_delf-1", "k_left-1, bell-1, k_delf-1")])
    # the ESC words D, DP and their routine
    rep(b / "common" / "edit.s", [
        ("; ---- delete lines: DP (Ctrl-C: to the next empty line), DA! (everything; ESC command) ----\ncmd_dp: lda lbn",
         "; ---- delete lines: D [n], DP (to the next empty line), DA! (everything) ----\n" + CMD_D + "cmd_dp: lda lbn")])
    # KEDIT: the words and the help as before
    rep(b / "kedit" / "gen.py", [
        ('    ("새로", ["N", "NEW"], "cmd_n"),\n',
         '    ("새", ["N", "NEW"], "cmd_n"),\n    ("복사", ["CP", "COPY"], "k_copy"),\n    ("붙임", ["PU", "PASTE"], "k_paste"),\n'),
        ('    ("정보", ["I"], "cmd_i"),\n    ("다지움", ["DA"], "cmd_da"),',
         '    ("정보", ["I"], "cmd_i"),\n    ("지움", ["D"], "cmd_d"),\n    ("문단지움", ["DP"], "cmd_dp"),\n    ("모두지움", ["DA"], "cmd_da"),'),
        ('    "^G  줄 복사 (^P 넣기)   ^C  문단 지움",', '    "^G  줄 복사 (^P 넣기)",'),
        (' 열기 E 이름  넣기 R 이름  새로 N  정보 I",', ' 열기 E 이름  넣기 R 이름  새 N  정보 I",'),
        (' 다지움 DA!",', ' 지움 D DP DA!  복사 CP  붙임 PU",'),
        ('    "{7}  줄 복사 ({16} 넣기)   {3}  문단 지움",', '    "{7}  줄 복사 ({16} 넣기)",'),
        ('또는 다지움!"', '또는 모두지움!"'),
    ])
    # KDIARY: the words as before
    rep(b / "kdiary" / "gen.py", [
        ('    ("정보", ["I"], "cmd_i"),\n    ("다지움", ["DA"], "cmd_da"),',
         '    ("복사", ["CP", "COPY"], "k_copy"),\n    ("붙임", ["PU", "PASTE"], "k_paste"),\n'
         '    ("정보", ["I"], "cmd_i"),\n    ("지움", ["D"], "cmd_d"),\n    ("문단지움", ["DP"], "cmd_dp"),\n    ("모두지움", ["DA"], "cmd_da"),'),
        ('    "{7}  줄 복사 ({16} 넣기)   {3}  문단 지움",', '    "{7}  줄 복사 ({16} 넣기)",'),
    ])
    say("baseline source: made and edited (" + str(BASE / "src") + ")")


def build_check(name, bin_path, want=None):
    got = Path(bin_path).stat().st_size if Path(bin_path).exists() else None
    if want is None:
        say(f"  {name}: {got} bytes")
    else:
        tag = "as before the change" if got == want else f"NOT {want} bytes as before the change"
        say(f"  {name}: {got} bytes ({tag})")


def include(name):
    """Put a step's log (the comparison) into the report."""
    say(f"--- {name} ---")
    text = (LOGS / f"{name}.txt").read_text(encoding="utf8", errors="replace") if (LOGS / f"{name}.txt").exists() else "(no log)"
    for ln in text.splitlines():
        say("  " + ln)
    say("")


def compare_only():
    """Only the two comparisons and the report (the runs and builds are already in work/regress)."""
    if REPORT.exists():
        REPORT.unlink()
    say(f"Comparison only {time.strftime('%Y-%m-%d %H:%M:%S')}")
    say("")
    step("dregress_cmp", ["src/tools/dregress.py", "cmp", "base", "cur"])
    include("dregress_cmp")
    step("kregress_cmp", ["src/tools/kregress.py", "cmp", "base", "cur"])
    include("kregress_cmp")
    analyze()
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf8")
    print("REPORT", REPORT, flush=True)


def analyze():
    """Automatic checks on the two runs (base = before the change, cur = now). Written into the report.
    1. KEDIT printed output of each test, with every number masked (free bytes, sector counts and so on are numbers):
       identical or not. A difference here is a text difference, not a size difference.
    2. Screens that differ: whether the difference is only in the bottom status row (free bytes, line count), or
       above it (the text on the screen: help, catalog, typed text). Above-status screens are listed by name.
    The verdict only says which checks passed; it does not replace reading the listed screens."""
    import json, re, difflib
    from PIL import Image, ImageChops
    say("AUTOMATIC CHECKS")
    # 1. printed output, numbers masked
    same, nums, text = [], [], []
    for n in range(1, 15):
        a, b = REG / "base" / f"k{n}.json", REG / "cur" / f"k{n}.json"
        if not (a.exists() and b.exists()):
            continue
        oa = json.loads(a.read_text(encoding="utf8"))["out"]
        ob = json.loads(b.read_text(encoding="utf8"))["out"]
        if oa == ob:
            same.append(f"k{n}")
        elif re.sub(r"\d+", "#", oa) == re.sub(r"\d+", "#", ob):
            nums.append(f"k{n}")
        else:
            d = [x for x in difflib.unified_diff(re.sub(r"\d+", "#", oa).splitlines(),
                                                 re.sub(r"\d+", "#", ob).splitlines(), lineterm="", n=0)
                 if x[:1] in "+-" and not x.startswith(("+++", "---"))]
            text.append((f"k{n}", d[:4]))
    say(f"  printed output identical: {' '.join(same) or '-'}")
    say(f"  differs only in numbers:  {' '.join(nums) or '-'}")
    say(f"  text differs (masked):    {' '.join(n for n, _ in text) or '-'}")
    for n, d in text:
        for x in d:
            say(f"      {n}: {x[:140]}")
    # 2. screens
    status_only, above = 0, []
    for pa in sorted((REG / "base").glob("*.png")):
        pb = REG / "cur" / pa.name
        if not pb.exists():
            above.append((pa.name, "missing in cur"))
            continue
        a, b = Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")
        if a.size != b.size:
            above.append((pa.name, "size"))
            continue
        bb = ImageChops.difference(a, b).getbbox()
        if bb is None:
            continue
        if bb[1] >= a.size[1] - 16:
            status_only += 1
        else:
            above.append((pa.name, str(bb)))
    say(f"  screens differing only in the status row: {status_only}")
    say(f"  screens differing above the status row:   {len(above)}")
    for name, bb in above:
        say(f"      {name} {bb}")
    say("")


def main():
    if "--compare-only" in sys.argv:
        return compare_only()
    t0 = time.time()
    if REPORT.exists():
        REPORT.unlink()
    REG.mkdir(parents=True, exist_ok=True)
    say(f"Regression run {time.strftime('%Y-%m-%d %H:%M:%S')}")
    say("")

    make_baseline()
    bsrc = BASE / "src"
    step("baseline_build_kedit", [str(bsrc / "kedit" / "build.py")], cwd=bsrc / "kedit")
    step("baseline_build_kdiary", [str(bsrc / "kdiary" / "build.py")], cwd=bsrc / "kdiary")
    step("current_build_kedit", [str(ROOT / "src" / "kedit" / "build.py")], cwd=ROOT / "src" / "kedit")
    step("current_build_kdiary", [str(ROOT / "src" / "kdiary" / "build.py")], cwd=ROOT / "src" / "kdiary")
    say("binary sizes:")
    build_check("baseline KEDIT.bin", bsrc / "kedit" / "build" / "KEDIT.bin", 12029)
    build_check("baseline KDIARY.bin", bsrc / "kdiary" / "build" / "KDIARY.bin", 16488)
    build_check("current KEDIT.bin", ROOT / "src" / "kedit" / "build" / "KEDIT.bin")
    build_check("current KDIARY.bin", ROOT / "src" / "kdiary" / "build" / "KDIARY.bin")
    say("")

    kb, kl = bsrc / "kedit" / "build" / "KEDIT.bin", bsrc / "kedit" / "build" / "kedit.lbl"
    dbin, dl = bsrc / "kdiary" / "build" / "KDIARY.bin", bsrc / "kdiary" / "build" / "kdiary.lbl"
    kc, kcl = ROOT / "src" / "kedit" / "build" / "KEDIT.bin", ROOT / "src" / "kedit" / "build" / "kedit.lbl"
    dc, dcl = ROOT / "src" / "kdiary" / "build" / "KDIARY.bin", ROOT / "src" / "kdiary" / "build" / "kdiary.lbl"

    say("DIARY (dregress.py):")
    step("dregress_base", ["src/tools/dregress.py", "run", "base", str(dbin), str(dl)])
    step("dregress_cur", ["src/tools/dregress.py", "run", "cur", str(dc), str(dcl)])
    step("dregress_cmp", ["src/tools/dregress.py", "cmp", "base", "cur"])
    include("dregress_cmp")
    say("EDITOR (kregress.py):")
    step("kregress_base", ["src/tools/kregress.py", "run", "base", str(kb), str(kl)])
    step("kregress_cur", ["src/tools/kregress.py", "run", "cur", str(kc), str(kcl)])
    step("kregress_cmp", ["src/tools/kregress.py", "cmp", "base", "cur"])
    include("kregress_cmp")
    analyze()
    say(f"Done in {(time.time() - t0) / 60:.0f} min. Full logs: work/regress/logs/")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf8")
    print("REPORT", REPORT, flush=True)


if __name__ == "__main__":
    main()
