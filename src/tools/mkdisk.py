"""Build disk/KEDIT.dsk: DOS 3.3, K-HANGEUL (driver and fonts), KEDIT. No K-BASIC on the disk.

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
SAMPLE = "KEDIT 견본\n한글과 English 를 함께 씁니다.\nESC 를 누르고 H 를 치면 도움말이 나옵니다.\n"


def acx(*a, inp=None):
    r = subprocess.run(["acx", *map(str, a)], input=inp, capture_output=True)
    if r.returncode:
        sys.exit(f"acx {a}: {r.stdout.decode('latin1')}{r.stderr.decode('latin1')}")
    return r.stdout


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


def build(dsk):
    sys.path.insert(0, str(ROOT / "disk"))
    import nbyte
    sync_base()
    subprocess.run([sys.executable, str(ROOT / "src" / "kedit" / "build.py")], check=True)
    shutil.copy(BASE, dsk)
    acx("-pt", dsk, "KSTART", inp=KSTART)
    acx("-p", dsk, "KEDIT", "bin", "0x4000", inp=(ROOT / "src" / "kedit" / "build" / "KEDIT.bin").read_bytes())
    acx("-p", dsk, "SAMPLE", "TXT", "0", inp=nbyte.encode(SAMPLE))
    return dsk


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "disk" / "KEDIT.dsk"
    build(out)
    print(acx("-l", out).decode("latin1").strip())
