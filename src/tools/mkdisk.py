"""Build disk/kedit/KEDIT.dsk: DOS 3.3, K-HANGEUL (driver and fonts), KEDIT, KEYS (the key map, classic keys), KEYCFG (the
Applesoft program that changes the keys). No K-BASIC on the disk.

Boot: HELLO (K-HANGEUL's own three-line loader: fonts, then EXEC KSTART) -> KSTART: BRUN K-HANGEUL, BRUN KEDIT.
The base image disk/khangeul-base.dsk holds HELLO, K-HANGEUL, FONT12, FONT6X10.
Before every build, K-HANGEUL, FONT12 and FONT6X10 on the base image are compared with those on the K-HANGEUL
project's own disk (KHDISK below) and replaced if they differ, so a rebuilt driver gets onto KEDIT.dsk without a manual
step. HELLO is not replaced: the base's HELLO ends with EXEC KSTART, K-HANGEUL's with BRUN K-HANGEUL. If the K-HANGEUL
project is not on this machine, the base image is used as it is.
Usage: python src/tools/mkdisk.py [output.dsk]"""
import shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "disk" / "khangeul-base.dsk"
KHDISK = ROOT.parent / "proj-apple2-korean-high-resolution" / "DIST-github" / "disk" / "K-HANGEUL.DSK"
DRIVER = (("K-HANGEUL", "0x0F94"), ("FONT12", "0x6000"), ("FONT6X10", "0x7200"))       # file, load address
KSTART = b"BRUN K-HANGEUL\nBRUN KEDIT\n"
KEYS = bytes(range(32))     # the classic keys: every key runs its own action (KEYCFG, R, 2 gives the IJKL set)
SAMPLE = "KEDIT 견본\n한글과 English 를 함께 씁니다.\nESC 를 누르고 H 를 치면 도움말이 나옵니다.\n"
SUTRA_SRC = ROOT / "src" / "tools" / "samples" / "sutra.txt"    # two sample texts split by a line of =====


def acx(*a, inp=None):
    r = subprocess.run(["acx", *map(str, a)], input=inp, capture_output=True)
    if r.returncode:
        sys.exit(f"acx {a}: {r.stdout.decode('latin1')}{r.stderr.decode('latin1')}")
    return r.stdout


def keycfg_source(nbyte):
    """keycfg.bas is kept in UTF-8; each run of Hangul becomes what a K-HANGEUL program holds in a string: Ctrl-K, the
    two-set keys as 7-bit codes, Ctrl-A (the same bytes as LIST shows in DEMO or MIXED)."""
    import re
    def run(m):
        b = nbyte.encode(m.group(0))
        return bytes(c & 0x7F for c in b).decode("latin1")
    text = re.sub("[가-힣]+(?: [가-힣]+)*", run, (ROOT / "src" / "kedit" / "keycfg.bas").read_text(encoding="utf8"))
    return text.encode("latin1")


def sync_base():
    """Bring the driver and the fonts on the base image up to date with the K-HANGEUL project's disk.
    Returns the names of the files replaced."""
    if not KHDISK.exists():
        print(f"mkdisk: {KHDISK} not found; using {BASE.name} as it is")
        return []
    changed = []
    for name, addr in DRIVER:
        new = acx("-g", KHDISK, name)
        if new != acx("-g", BASE, name):
            acx("-d", BASE, name)
            acx("-p", BASE, name, "bin", addr, inp=new)
            changed.append(name)
    if changed:
        print(f"mkdisk: {BASE.name} updated from {KHDISK}: {', '.join(changed)}. Run all the tests, on both cards.")
    # the font lines of the two HELLO programs must agree (the last line differs on purpose)
    ours, theirs = (acx("-e", d, "HELLO").split(b"30 ")[0] for d in (BASE, KHDISK))
    if ours != theirs:
        print("mkdisk: WARNING: K-HANGEUL's HELLO loads its fonts differently from the base image's HELLO; "
              "update the HELLO on the base image")
    return changed


KEDIT_DIR = ROOT / "disk" / "kedit"       # the KEDIT disk and its files
KDIARY_DIR = ROOT / "disk" / "kdiary"     # the diary disk and its files


def publish_tools():
    """The PC tools that read the files taken off the disks (AppleCommander): nbyte.py goes with both programs,
    kdiary_decrypt.py with the diary. The base image (disk/khangeul-base.dsk) stays in disk/."""
    KEDIT_DIR.mkdir(parents=True, exist_ok=True)
    KDIARY_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "src" / "tools" / "nbyte.py", KEDIT_DIR / "nbyte.py")
    shutil.copy(ROOT / "src" / "tools" / "nbyte.py", KDIARY_DIR / "nbyte.py")
    shutil.copy(ROOT / "src" / "tools" / "kdiary_decrypt.py", KDIARY_DIR / "kdiary_decrypt.py")


def build(dsk):
    import nbyte
    sync_base()
    publish_tools()
    subprocess.run([sys.executable, str(ROOT / "src" / "kedit" / "build.py")], check=True)
    shutil.copy(BASE, dsk)
    acx("-pt", dsk, "KSTART", inp=KSTART)
    acx("-p", dsk, "KEDIT", "bin", "0x4000", inp=(ROOT / "src" / "kedit" / "build" / "KEDIT.bin").read_bytes())
    acx("-p", dsk, "KEYS", "bin", "0x300", inp=KEYS)
    acx("-bas", dsk, "KEYCFG", inp=keycfg_source(nbyte))
    acx("-p", dsk, "SAMPLE", "TXT", "0", inp=nbyte.encode(SAMPLE))
    for name, text in zip(("SUTRA1", "SUTRA2"), SUTRA_SRC.read_text(encoding="utf8").split("=====\n")):
        lines = [ln.rstrip() for ln in text.split("\n")]
        while lines and not lines[-1]:
            lines.pop()
        text = "\n".join(lines).replace("ㆍ", ".") + "\n"    # the middle dot U+318D has no key form: a full stop
        acx("-p", dsk, name, "TXT", "0", inp=nbyte.encode(text))
    return dsk


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "disk" / "kedit" / "KEDIT.dsk"
    build(out)
    print(acx("-l", out).decode("latin1").strip())
