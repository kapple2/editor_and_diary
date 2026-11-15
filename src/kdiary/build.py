"""Build KDIARY: generate the tables and messages, assemble, link. Output: build/KDIARY.bin (load address $4000).

Usage: python src/kdiary/build.py"""

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

run(CC65 / "ca65.exe", "-t", "none", "-g", "-l", "build/kdiary.lst", "-o", "build/kdiary.o", "kdiary.s")

run(CC65 / "ld65.exe", "-C", "kdiary.cfg", "-m", "build/kdiary.map", "-Ln", "build/kdiary.lbl", "-o", "build/KDIARY.bin", "build/kdiary.o")

size = (HERE / "build" / "KDIARY.bin").stat().st_size

# KDEXPORT: the converter (a separate program)

sys.path.insert(0, str(HERE.parent / "tools"))

import nbyte

EXPORT_VERSION = "0.31"
MSG = {
    "m_banner": f"KDEXPORT v{EXPORT_VERSION}  일기 내보내기||일기를 암호 없는 글 파일로 만듭니다.|(한 달에 파일 하나)|만든 파일은 암호가 없으니 조심하세요.||",
    "m_hint": "RETURN: 괄호 안 그대로|예: D2 또는 S6,D2   (2, 62 도 됩니다)||",
    "m_data": "일기가 들어 있는 디스크의 드라이브는?|",
    "m_out": "파일을 만들 디스크의 드라이브는?|",
    "m_prompt": " ? ",
    "m_cur0": "[S",
    "m_cur1": ",D",
    "m_slot": "  => 슬롯 ",
    "m_drive": ", 드라이브 ",
    "m_pw": "비밀번호: ",
    "m_bad": "비밀번호가 틀렸습니다|",
    "m_none": "일기 파일이 없습니다|",
    "m_nopw": "이 디스크에는 일기가 없습니다 (PWCHK 없음)|",
    "m_baddisk": "슬롯 1-7, 드라이브 1-2 만 됩니다|",
    "m_file": "만드는 중: ",
    "m_err": "디스크 오류 ",
    "m_locked": "파일이 잠겨 있습니다 (UNLOCK 으로 풀어 주세요)|",
    "m_wprot": "쓰기 금지된 디스크입니다|",
    "m_dfull": "디스크가 가득 찼습니다|",
    "m_done1": "|끝났습니다: 일기 ",
    "m_done2": "개, 파일 ",
    "m_done3": "개|만든 파일:|",
    "m_stop": "중단했습니다|",
    "m_anykey": "아무 키나 누르세요",
}
MSG = {k: v.replace("|", chr(10)) for k, v in MSG.items()}
pre = nbyte.encode("일기") + b" "

lines = [f"MNPL = {len(pre)}", "mnpre: .byte " + ",".join(f"${b | 0x80 if b < 0x80 else b:02X}" for b in pre)]

for k, v in MSG.items():

    lines.append(f"{k}: .byte " + ",".join(f"${b:02X}" for b in nbyte.encode(v)) + ",0")

(HERE / "build" / "export_gen.inc").write_text(chr(10).join(lines) + chr(10), encoding="ascii")

run(CC65 / "ca65.exe", "-t", "none", "-g", "-l", "build/export.lst", "-o", "build/export.o", "export.s")

run(CC65 / "ld65.exe", "-C", "kdexport.cfg", "-m", "build/export.map", "-Ln", "build/export.lbl", "-o", "build/KDEXPORT.bin", "build/export.o")

print("KDEXPORT.bin", (HERE / "build" / "KDEXPORT.bin").stat().st_size, "bytes")

lbl = {ln.split()[2].lstrip("."): int(ln.split()[1], 16) for ln in (HERE / "build" / "kdiary.lbl").read_text().splitlines()}

buf = lbl["__BSS_RUN__"] + lbl["__BSS_SIZE__"]

print(f"KDIARY.bin {size} bytes (${0x4000:04X}-${0x4000 + size - 1:04X}), variables to ${buf - 1:04X}, "

      f"text space {0x9400 - buf} bytes (${buf:04X}-$93FF)")

