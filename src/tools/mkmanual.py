"""Make src/docs/KEDIT_MANUAL.html and KEDIT_MANUAL.pdf from KEDIT_MANUAL.md (the .md is the source; do not edit the others).
HTML: pandoc. PDF: Chrome or Edge, headless, printing that HTML. Usage: python src/tools/mkmanual.py [KEDIT|DIARY]   (default KEDIT; DIARY makes DIARY_MANUAL.html and .pdf)"""
import subprocess, sys, tempfile
from pathlib import Path

DOCS = Path(__file__).resolve().parents[1] / "docs"
NAME = (sys.argv[1] if len(sys.argv) > 1 else "KEDIT").upper()
MD, HTML, PDF = DOCS / f"{NAME}_MANUAL.md", DOCS / f"{NAME}_MANUAL.html", DOCS / f"{NAME}_MANUAL.pdf"
BROWSERS = [Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
            Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")]

CSS = """<style>
:root { --fg: #1c1c1c; --bg: #ffffff; --line: #c9c9c9; --soft: #f3f3f1; --code: #f0efec; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #e6e6e6; --bg: #181818; --line: #4a4a4a; --soft: #232323; --code: #2a2a2a; }
}
@media print { :root { --fg: #000; --bg: #fff; --line: #999; --soft: #f3f3f1; --code: #f0efec; } }
html { background: var(--bg); }
body { color: var(--fg); background: var(--bg); max-width: 50em; margin: 0 auto; padding: 24px 16px 48px;
  font-family: "Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans KR", sans-serif; font-size: 15px; line-height: 1.65; }
h1 { font-size: 1.7em; border-bottom: 2px solid var(--fg); padding-bottom: 0.25em; }
h2 { font-size: 1.3em; margin-top: 1.9em; border-bottom: 1px solid var(--line); padding-bottom: 0.2em; }
h3 { font-size: 1.08em; margin-top: 1.5em; }
h2, h3 { page-break-after: avoid; }
table { border-collapse: collapse; margin: 0.8em 0; width: 100%; }
th, td { border: 1px solid var(--line); padding: 5px 9px; text-align: left; vertical-align: top; }
th { background: var(--soft); }
tr { page-break-inside: avoid; }
code { font-family: Consolas, "D2Coding", monospace; font-size: 0.93em; background: var(--code); padding: 1px 4px;
  border-radius: 3px; }
pre { background: var(--code); padding: 10px 12px; border-radius: 4px; overflow-x: auto; page-break-inside: avoid; }
pre code { background: none; padding: 0; }
@page { size: A4; margin: 16mm 15mm; }
@media print { body { max-width: none; padding: 0; font-size: 10.5pt; } }
</style>
"""


def main():
    title = MD.read_text(encoding="utf8").splitlines()[0].lstrip("# ").strip()
    with tempfile.TemporaryDirectory() as tmp:
        head = Path(tmp) / "head.html"
        head.write_text(CSS, encoding="utf8")
        subprocess.run(["pandoc", str(MD), "-f", "gfm", "-t", "html5", "-s", "--metadata", f"pagetitle={title}",
                        "-V", "lang=ko", "-H", str(head), "-o", str(HTML)], check=True)
    browser = next((b for b in BROWSERS if b.exists()), None)
    if not browser:
        sys.exit("no Chrome or Edge found: the PDF was not made")
    with tempfile.TemporaryDirectory() as prof:
        subprocess.run([str(browser), "--headless", "--disable-gpu", f"--user-data-dir={prof}", "--no-pdf-header-footer",
                        f"--print-to-pdf={PDF}", HTML.as_uri()], check=True, capture_output=True)
    print(f"{HTML.name} {HTML.stat().st_size} bytes, {PDF.name} {PDF.stat().st_size} bytes")


if __name__ == "__main__":
    main()
