"""Generate build/gen.inc for KEDIT: Korean messages and help text as N-byte strings, the command table,
and the jamo key tables used by the syllable segmenter.
N-byte: Ctrl-K ($8B) + two-set key letters + Ctrl-A ($81), everything with bit 7 set (K-HANGEUL text format).
Usage: python gen.py   (writes build/gen.inc next to this file)"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src" / "tools"))   # nbyte.py (also copied to disk/ by the build)
import nbyte  # K-HANGEUL's own encoder

HERE = Path(__file__).parent
OUT = HERE / "build" / "gen.inc"

# The version: <major>.<minor><bug fix>, two digits after the point (v1.00, v1.50, v1.51). Change it here (and in README.md,
# HANDOVER.md) with every change of the program; it is shown in the footer of the start screens.
VERSION = "1.13"
FOOT = "캐플 2026  v" + VERSION

MSGS = {
    "m_han": "한 ",                # the status bar: 한 ABC 줄 1/2 칸 3 여유 1100 * [S6,D1]
    "m_eng": "영 ",
    "m_line": " 줄 ",
    "m_col": " 칸 ",
    "m_hello": "ESC: 저장 W  끝 Q  저장끝 WQ",
    "m_saved": "저장했습니다",
    "m_askempty": "비었습니다: Y:지움 다른 키:저장 안 함",
    "m_notsaved": "저장하지 않았습니다",
    "m_full": "메모리가 가득 찼습니다",
    "m_unsaved": "저장 안 했습니다 (Q! 로 나가기)",
    "m_badcmd": "모르는 명령어입니다",
    "m_diskerr": "디스크 오류 ",
    "m_locked": "파일이 잠겨 있습니다",
    "m_wprot": "쓰기 금지된 디스크입니다",
    "m_dfull": "디스크가 가득 찼습니다",
    "m_ioerr": "입출력 오류",
    "m_nofile": "파일이 없습니다",
    "m_anykey": "아무 키나 누르세요",
    "m_bytes": " 바이트, 여유 ",
    "m_cmd": "명령:",
    "m_free": " 여유 ",
    "m_copied": "복사했습니다",
    "m_sure": "모두 지우려면 DA!",
    # the diary shell
    # A {x,y} in a text is a position: puts goes to column x of row y (row -1 = the top line). The blanks at the end of
    # a question bring the cursor to the column where the answer is typed.
    "m_title": "일기 ",
    "s_welcome": "{8,3}일기장에 오신 것을 환영합니다",
    "s_first": "{2,5}처음이시므로 비밀번호를 정해야 합니다{2,7}비밀번호를 잊으면 읽을 수 없습니다"
               "{2,8}(1~16 글자, 영문과 숫자){2,10}비밀번호를 정하세요:  ",
    "s_again": "{13,11}한 번 더:  ",
    "s_pwask": "{2,6}비밀번호:   ",
    "s_date": "{0,-1}일기{2,4}오늘 날짜 (예 2026-11-14): ",
    "s_drv": "{2,5}일기 데이터 디스크의 드라이브는?{2,6}예: D2 또는 S6,D2 (2, 62 도 됨)"
             "{2,7}RETURN: 괄호 안의 지금 드라이브{2,9}",
    "s_new": " 에는 일기가 없습니다{2,7}새 일기를 만들까요?{2,8}Y: 만듦  다른 키: 다시 고르기",
    "s_orph": "일기 파일은 있는데 PWCHK 가 없습니다{2,6}새로 만들면 읽을 수 없게 됩니다{2,8}",
    "m_foot": " " * ((46 - 9 - len(VERSION) - 3) // 2) + FOOT,
    "m_pwdiff": "서로 다릅니다. 다시 정하세요",
    "m_pwbad": "비밀번호가 틀렸습니다",
    "m_baddate": "날짜가 올바르지 않습니다",
    "m_yr": "년 ",
    "m_noentry": "(일기 없음)",
    "m_barcal": "RET쓰기 P/N달 </>해 T오늘 L목록 D지움 ESC명령",
    "m_yoil": "요일",
    "m_reading": "일기 목록을 읽는 중입니다...",
    "m_barlist": "위아래/좌우줄 </>쪽 RET열기 0-9날짜 ESC뒤로",
    "m_askdel": "지울까요? Y:지움 다른 키:취소",
    "m_listhdr": "전체 일기 목록",
    "m_nolist": "쓴 일기가 없습니다",
    "m_goto": "날짜: ",
    "m_wd0": "일",
    "m_wd1": "월",
    "m_wd2": "화",
    "m_wd3": "수",
    "m_wd4": "목",
    "m_wd5": "금",
    "m_wd6": "토",
    "m_baddrv": "드라이브를 알 수 없습니다",
    "m_lshdr": "목록 ",
    "m_lsbar": "아무 키: 다음 쪽   ESC: 끝",
    "m_notfound": "찾지 못했습니다",
}

HELP = [
    "일기 도움말",
    "^B ->  왼쪽/오른쪽   ^K ^J  위/아래 줄",
    "^O ^N  줄 처음/끝    ^W ^Z  쪽 위/아래",
    "^T ^E  파일 처음/끝  ^L  화면 다시 그림",
    "^S/DEL 앞 글자 지움  ^D  글자 지움",
    "^X  줄 끝까지 지움   ^Y  줄 지움 (^P 넣기)",
    "^G  줄 복사 (^P 넣기)",
    "^R  줄 되돌리기      ^F  다시 찾기",
    "^A  한글/영문        ^Q  대문자/소문자",
    "ESC 명령 (한글이나 영문, RETURN 실행):",
    " 저장 W  끝 Q  끝! Q!  저장끝 WQ",
    " 찾기 F  줄 G 번호  번호 NU",
]

# The help has a slot {n} wherever a key is named (the keys can be changed). n is the action number (the
# default key's control code); KEDIT fills the slot with the key that runs it. A slot is 2 characters wide, like "^B".
HELPU = [
    "일기 도움말",
    "{2} {21}  왼쪽/오른쪽   {11} {10}  위/아래 줄",
    "{15} {14}  줄 처음/끝    {23} {26}  쪽 위/아래",
    "{20} {5}  파일 처음/끝  {12}  화면 다시 그림",
    "{19}/DEL 앞 글자 지움  {4}  글자 지움",
    "{24}  줄 끝까지 지움   {25}  줄 지움 ({16} 넣기)",
    "{7}  줄 복사 ({16} 넣기)   {3}  문단 지움",
    "{18}  줄 되돌리기      {6}  다시 찾기",
    "^A  한글/영문   {17}  대문자/소문자  {9}  탭",
] + HELP[9:]
HELP = HELPU


def msgbytes(text):
    """N-byte text; {x,y} becomes the two bytes x + 1, y + 2 (bit 7 clear: a position, see puts in shell.s)."""
    out = b""
    for i, part in enumerate(re.split(r"\{(-?\d+),(-?\d+)\}", text)):
        if i % 3 == 0:
            out += nbyte.encode(part)
        elif i % 3 == 1:
            out += bytes([int(part) + 1])
        else:
            out += bytes([int(part) + 2])
    return out


def helpbytes(text):
    """N-byte text; {n} becomes the single byte n (bit 7 clear: a slot)."""
    import re
    out = b""
    for i, part in enumerate(re.split(r"\{(\d+)\}", text)):
        out += bytes([int(part)]) if i % 2 else nbyte.encode(part)
    return out


# command words: Korean word, English aliases, handler label
CMDS = [
    ("저장", ["W"], "save"),
    ("끝", ["Q"], "cmd_q"),
    ("저장끝", ["WQ", "X"], "cmd_wq"),
    ("도움", ["H", "?"], "cmd_h"),
    ("찾기", ["F", "FIND"], "cmd_f"),
    ("줄", ["G"], "cmd_g"),
    ("번호", ["NU"], "cmd_nu"),
    ("정보", ["I"], "cmd_i"),
    ("다지움", ["DA"], "cmd_da"),
]
CALCMDS = [("끝", ["Q"], "ccmd_q"), ("도움", ["?", "H"], "ccmd_h"), ("디스크", ["CHD"], "ccmd_chd"), ("목록", ["LS"], "ccmd_ls")]
CHELP = ["일기 달력 도움말",
         "",
         "{2} {21} : 하루 앞/뒤    {11} {10} : 한 주 앞/뒤",
         "P N : 한 달    < > : 한 해    T : 오늘",
         "숫자 8개 : 그 날로 (20261201)",
         "RETURN : 쓰기, 고치기    D : 지우기",
         "L : 모든 일기 목록       Q : 끝",
         "ESC : 명령 (쓰고 RETURN)",
         "  목록 S6,D1   그 디스크의 파일 목록 (LS)",
         "  디스크 S6,D2   데이터 디스크 (CHD)",
         "  도움 (?)    끝 (Q)"]
CMDS_LETTERS = []                                      # (the English words are aliases in CMDS now)

CONS = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"       # class 1..19
VOWS = "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅛㅜㅠㅡㅣ"                 # class $81..$8E
VCOMB = [("ㅗ", "ㅏ"), ("ㅗ", "ㅐ"), ("ㅗ", "ㅣ"), ("ㅜ", "ㅓ"), ("ㅜ", "ㅔ"), ("ㅜ", "ㅣ"), ("ㅡ", "ㅣ")]
CLUST = [("ㄱ", "ㅅ"), ("ㄴ", "ㅈ"), ("ㄴ", "ㅎ"), ("ㄹ", "ㄱ"), ("ㄹ", "ㅁ"), ("ㄹ", "ㅂ"), ("ㄹ", "ㅅ"),
         ("ㄹ", "ㅌ"), ("ㄹ", "ㅍ"), ("ㄹ", "ㅎ"), ("ㅂ", "ㅅ")]
NOFINAL = "ㄸㅃㅉ"


def cls(j):
    return CONS.index(j) + 1 if j in CONS else 0x81 + VOWS.index(j)


def hexb(bs):
    return ",".join(f"${b:02X}" for b in bs)


def main():
    OUT.parent.mkdir(exist_ok=True)
    L = ["; generated by gen.py: do not edit"]
    for name, text in MSGS.items():
        L.append(f"{name}: .byte {hexb(msgbytes(text))},0")
    L.append("helptxt:")                                 # the lines follow each other (helpx walks them)
    for i, text in enumerate(HELP):
        L.append(f"  .byte {hexb(helpbytes(text))},0")
    L.append(f"HELPN = {len(HELP)}")
    # command table: length, bytes (key letters of the Korean word, or the English word), handler
    L.append("cmdtab:")
    for word, aliases, label in CMDS:
        keys = bytes(b for b in nbyte.encode(word) if b not in (0x8B, 0x81))
        for w in [keys] + [bytes(ord(c) | 0x80 for c in a) for a in aliases]:
            L.append(f"  .byte {len(w)},{hexb(w)}")
            L.append(f"  .addr {label}")
    for a, label in CMDS_LETTERS:
        w = bytes(ord(c) | 0x80 for c in a)
        L.append(f"  .byte {len(w)},{hexb(w)}")
        L.append(f"  .addr {label}")
    L.append("  .byte 0")
    L.append("caltab:")
    for word, aliases, label in CALCMDS:
        keys = [bytes(b for b in nbyte.encode(word) if b not in (0x8B, 0x81))] if word else []
        for w in keys + [bytes(ord(c) | 0x80 for c in a) for a in aliases]:
            L.append(f"  .byte {len(w)},{hexb(w)}")
            L.append(f"  .addr {label}")
    L.append("  .byte 0")
    for i, line in enumerate(CHELP):
        raw = b""                                        # {n} = a slot: the key that runs action n (see helpx)
        for k, part in enumerate(re.split(r"\{(\d+)\}", line)):
            raw += bytes([int(part)]) if k % 2 else bytes(b | 0x80 if b < 0x80 else b for b in nbyte.encode(part))
        s = hexb(raw)
        L.append(f"{'chelptxt:' if i == 0 else ''}  .byte {s + ',' if s else ''}0")
    L.append(f"CHN = {len(CHELP)}")
    # key class table for bytes $A0-$FF
    tab = [0] * 96
    for j in CONS:
        tab[(ord(nbyte.CONSONANT_KEY[j]) | 0x80) - 0xA0] = cls(j)
    for j in VOWS:
        tab[(ord(nbyte.VOWEL_KEY[j]) | 0x80) - 0xA0] = cls(j)
    L.append(f"ktab: .byte {hexb(tab)}")
    L.append(f"vcomb1: .byte {hexb(cls(a) for a, b in VCOMB)}")
    L.append(f"vcomb2: .byte {hexb(cls(b) for a, b in VCOMB)}")
    L.append(f"NVCOMB = {len(VCOMB)}")
    L.append(f"clus1: .byte {hexb(cls(a) for a, b in CLUST)}")
    L.append(f"clus2: .byte {hexb(cls(b) for a, b in CLUST)}")
    L.append(f"NCLUS = {len(CLUST)}")
    L.append(f"nofin: .byte {hexb(cls(j) for j in NOFINAL)}")
    # Shift + R E Q T W O P in Hangul mode -> the tense/compound keys - = * < > ; +
    L.append(f"shk: .byte {hexb(ord(c) for c in 'REQTWOP')}")
    L.append(f"shv: .byte {hexb(ord(c) for c in '-=*<>;+')}")
    # hi-res addresses of the last byte (39) of pixel lines 180-191, the 12 lines of text row 15 (the status bar)
    addr = [0x2000 + ((y & 7) << 10) + (((y >> 3) & 7) << 7) + (y >> 6) * 40 + 39 for y in range(180, 192)]
    # ... and of pixel lines 0-11 (the top line): entries 12-23 of the same tables
    addr += [0x2000 + ((y & 7) << 10) + (((y >> 3) & 7) << 7) + (y >> 6) * 40 + 39 for y in range(0, 12)]
    L.append(f"stripl: .byte {hexb(a & 255 for a in addr)}")
    L.append(f"striph: .byte {hexb(a >> 8 for a in addr)}")
    import art
    nb, x0, h, data, _ = art.make()
    sp = [f"SPW = {nb}", f"SPX = {x0}", f"SPH = {h}", f"spdata: .byte {hexb(data)}"]
    (HERE / "build" / "splash.inc").write_text(chr(10).join(sp) + chr(10), encoding="ascii")
    pre = nbyte.encode("일기") + b" "
    L.append(f"MNPL = {len(pre)}")
    # the month file's name, 30 bytes: mkname puts the digits of the year and the month into it
    name = bytes(b | 0x80 for b in pre) + bytes(ord(c) | 0x80 for c in "2000-00")
    L.append(f"mname: .byte {hexb(name + bytes([0xA0]) * (30 - len(name)))}")
    OUT.write_text("\n".join(L) + "\n", encoding="ascii")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
