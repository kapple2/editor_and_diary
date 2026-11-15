"""Build disk/kdiary/KDIARY.DSK: DOS 3.3, K-HANGEUL (driver and fonts), KDIARY (the diary program), KEYS (the key map shared
with KEDIT: classic keys) and KEYCFG (the Applesoft program that changes the keys).

Boot: HELLO (loads the fonts, then EXEC KSTART) -> KSTART: BRUN K-HANGEUL, BRUN KDIARY.
Same base image and driver sync as mkdisk.py (KEDIT.dsk is not touched).
Usage: python src/tools/mkdiary.py [output.dsk]"""
import shutil, subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import mkdisk  # noqa: E402

ROOT = mkdisk.ROOT
KSTART = b"BRUN K-HANGEUL\nBRUN KDIARY\n"


def build(dsk):
    import nbyte
    mkdisk.sync_base()
    mkdisk.publish_tools()
    subprocess.run([sys.executable, str(ROOT / "src" / "kdiary" / "build.py")], check=True)
    shutil.copy(mkdisk.BASE, dsk)
    acx = mkdisk.acx
    acx("-pt", dsk, "KSTART", inp=KSTART)
    acx("-p", dsk, "KDIARY", "bin", "0x4000", inp=(ROOT / "src" / "kdiary" / "build" / "KDIARY.bin").read_bytes())
    acx("-p", dsk, "KDEXPORT", "bin", "0x4000", inp=(ROOT / "src" / "kdiary" / "build" / "KDEXPORT.bin").read_bytes())
    acx("-p", dsk, "KEYS", "bin", "0x300", inp=mkdisk.KEYS)
    acx("-bas", dsk, "KEYCFG", inp=mkdisk.keycfg_source(nbyte))
    return dsk


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "disk" / "kdiary" / "KDIARY.DSK"
    build(out)
    print(mkdisk.acx("-l", out).decode("latin1").strip())
