"""Run a scripted, headless MAME session (apple2p) on a fresh KEDIT disk and collect screenshots.

  run(name, steps, seed=None) -> (disk_path, [png paths])

steps: one string per step: 'T text' (keys; <CK> <CA> <CR> <ES> <xNN>), 'E' (Return), 'S label' (screenshot),
'W frames', 'M addr count' (hex dump into work/<name>.steps.trace), 'K hh' (one key code, hex, put into K-HANGEUL's
type-ahead ring: for Ctrl-J, which MAME types as Return). 'X' (exit) is added.
The disk, written back by MAME, stays at work/mame/disks/<name>.dsk. Keys are posted only while KEDIT waits for a key
(the address of its getkey loop is taken from build/kdiary.lbl), and the frames each key took are logged."""
import os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAME = Path(r"D:\opt\classic\_emul\mame0289b_x64")
S = ROOT / "work" / "mame"
sys.path.insert(0, str(Path(__file__).parent))
import mkdisk, mkdiary, nbyte  # noqa: E402

for d in ("cfg", "nvram", "snap", "sta", "diff", "comments", "ini", "disks"):
    (S / d).mkdir(parents=True, exist_ok=True)


def acx(*a, inp=None):
    return subprocess.run(["acx", *map(str, a)], input=inp, capture_output=True)


LBL = ROOT / "src" / "kdiary" / "build" / "kdiary.lbl"      # the label file of the program under test (tests of KDEXPORT set it)


def label(name):
    for ln in LBL.read_text().splitlines():
        a = ln.split()
        if a[2] == "." + name:
            return int(a[1], 16)
    raise RuntimeError(name + " not in " + LBL.name)


def blank_disk(path):
    """A new blank DOS 3.3 disk image (AppleCommander): the tests never use disk/dos33blank.dsk (it is handy for the user's own tests)."""
    Path(path).unlink(missing_ok=True)
    r = acx("-dos140", path)
    if r.returncode:
        raise RuntimeError(r.stderr.decode("latin1"))
    return path


def put_text(disk, name, data):
    r = acx("-p", disk, name, "TXT", "0", inp=data)
    if r.returncode:
        raise RuntimeError(r.stderr.decode("latin1"))


def run(name, steps, seed=None, timeout=900, flop2=None):
    disk = S / "disks" / f"{name}.dsk"
    mkdiary.build(disk)
    if seed:
        seed(disk)
    sf = ROOT / "work" / f"{name}.steps"
    sf.write_text("\n".join(list(steps) + ["X"]) + "\n", encoding="utf8")
    for ext in (".idle", ".trace", ".pc"):
        Path(str(sf) + ext).unlink(missing_ok=True)
    snapdir = S / "snap" / "apple2p"
    snapdir.mkdir(parents=True, exist_ok=True)
    for old in snapdir.glob("*.png"):
        old.unlink()
    env = dict(os.environ, LTM_STEPS=str(sf), LTM_IDLE=f"{label('getkey'):X}-{label('gkend'):X}")
    args = [str(MAME / "mame.exe"), "apple2p", "-video", "none", "-skip_gameinfo", "-nothrottle", "-sound", "none",
            "-rompath", str(MAME / "roms"), "-inipath", f"{MAME / 'ini'};{S / 'ini'}", "-cfg_directory", str(S / "cfg"),
            "-nvram_directory", str(S / "nvram"), "-snapshot_directory", str(S / "snap"),
            "-state_directory", str(S / "sta"), "-diff_directory", str(S / "diff"),
            "-comment_directory", str(S / "comments"), "-flop1", str(disk), *(["-flop2", str(flop2)] if flop2 else []),
            "-autoboot_script", str(ROOT / "src" / "tools" / "session.lua")]
    args += os.environ.get("KEDIT_MAME_ARGS", "").split()      # e.g. "-sl0 ssram" for the Saturn 128K card
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = 0
    with open(ROOT / "work" / f"{name}.mame.log", "w") as log:
        p = subprocess.Popen(args, cwd=S, env=env, stdout=log, stderr=subprocess.STDOUT, startupinfo=si,
                             creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            p.kill()
            print("TIMEOUT", name)
    out = ROOT / "work" / "sess"
    out.mkdir(parents=True, exist_ok=True)
    pngs = []
    for i, png in enumerate(sorted(snapdir.glob("*.png"))):
        dst = out / f"{name}_{i:02d}.png"
        shutil.copy(png, dst)
        pngs.append(dst)
    return disk, pngs


def frames(name):
    f = ROOT / "work" / f"{name}.steps.idle"
    if not f.exists():
        return []
    return [int(ln.split()[1]) for ln in f.read_text().split("\n") if ln.strip()]


def trace(name):
    f = ROOT / "work" / f"{name}.steps.trace"
    return f.read_text() if f.exists() else ""


def read_file(disk, fname):
    r = acx("-g", disk, fname)
    return r.stdout.rstrip(b"\x00") if r.returncode == 0 else None


def hname_get(disk, keys):
    """Read a file whose DOS name is Hangul (Ctrl-K, key letters, Ctrl-A): rename it on a scratch copy, then get it."""
    raw = bytearray(Path(disk).read_bytes())
    old = (bytes([0x8B]) + bytes(ord(c) | 0x80 for c in keys) + bytes([0x81]) + bytes([0xA0]) * 30)[:30]
    new = (bytes(ord(c) | 0x80 for c in "ZZGET") + bytes([0xA0]) * 30)[:30]
    for sec in range(1, 16):
        base = 17 * 16 * 256 + sec * 256
        for i in range(11, 256 - 35 + 1, 35):
            if raw[base + i + 3:base + i + 33] == old:
                raw[base + i + 3:base + i + 33] = new
                tmp = Path(disk).with_suffix(".get.dsk")
                tmp.write_bytes(bytes(raw))
                return acx("-g", tmp, "ZZGET").stdout.rstrip(b"\x00")
    return None


def sheet(pngs, dest, cols=2):
    from PIL import Image
    ims = [Image.open(p).convert("RGB") for p in pngs]
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    W = Image.new("RGB", (w * cols, h * rows), (40, 40, 40))
    for k, im in enumerate(ims):
        W.paste(im, ((k % cols) * w, (k // cols) * h))
    W.save(dest)
    return dest


def hi(s):
    """ASCII text (with \\r, \\x0b, \\x01) -> file bytes (bit 7 set)."""
    return bytes(b | 0x80 for b in s.encode("latin1"))
