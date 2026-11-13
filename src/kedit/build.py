"""Build KEDIT: generate the tables and messages, assemble, link. Output: build/KEDIT.bin (load address $4000).
Usage: python src/kedit/build.py"""
import subprocess, sys
from pathlib import Path

HERE = Path(__file__).parent
CC65 = Path(r"D:\opt\devtools\asm\cc65\bin")


def run(*a):
    r = subprocess.run([str(x) for x in a], cwd=HERE, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    return r.stdout


(HERE / "build").mkdir(exist_ok=True)
run(sys.executable, "gen.py")
run(CC65 / "ca65.exe", "-t", "none", "-g", "-l", "build/kedit.lst", "-o", "build/kedit.o", "kedit.s")
run(CC65 / "ld65.exe", "-C", "kedit.cfg", "-m", "build/kedit.map", "-Ln", "build/kedit.lbl", "-o", "build/KEDIT.bin", "build/kedit.o")
size = (HERE / "build" / "KEDIT.bin").stat().st_size
lbl = {ln.split()[2].lstrip("."): int(ln.split()[1], 16) for ln in (HERE / "build" / "kedit.lbl").read_text().splitlines()}
buf = lbl["__BSS_RUN__"] + lbl["__BSS_SIZE__"]
print(f"KEDIT.bin {size} bytes (${0x4000:04X}-${0x4000 + size - 1:04X}), variables to ${buf - 1:04X}, "
      f"text space {0x9400 - buf} bytes (${buf:04X}-$93FF)")
