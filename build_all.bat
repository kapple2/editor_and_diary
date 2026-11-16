@echo off
rem build_all.bat - build the two disks (cc65, Python 3 and AppleCommander acx on the PATH)
rem
rem   disk\kedit\KEDIT.dsk   : K-HANGEUL, fonts, KSTART, KEDIT (the editor), KEYS (key map: classic keys),
rem                            KEYCFG (Applesoft program that changes the keys), SAMPLE, SUTRA1, SUTRA2
rem   disk\kedit\            : KEDIT_MANUAL.md / .html / .pdf, RELEASE.txt (src\kedit), nbyte.py (copies, made here)
rem
rem   disk\kdiary\KDIARY.DSK : K-HANGEUL, fonts, KSTART, KDIARY (the diary), KEYS, KEYCFG
rem   disk\kdiary\           : DIARY_MANUAL.md / .html / .pdf, RELEASE.txt (src\kdiary), nbyte.py, kdiary_decrypt.py (copies)
rem
rem Sources: src\kedit (KEDIT), src\kdiary (KDIARY, KDEXPORT) and src\common (the editor code that both programs
rem assemble: a change there changes both, and this file builds both). The two build.py scripts are run by
rem mkdisk.py and mkdiary.py.
rem
rem   disk\khangeul-base.dsk is the base image the disks are built from (it stays in disk\).
rem
rem The manuals are copied from src\docs (remake them first with python src\tools\mkmanual.py [DIARY]).
rem If AppleWin holds a disk image open it cannot be written: close it first.

setlocal
cd /d "%~dp0"

python src\tools\mkdisk.py
if errorlevel 1 goto fail

python src\tools\mkdiary.py
if errorlevel 1 goto fail

copy /y "src\docs\KEDIT_MANUAL.md" "disk\kedit\" >nul
if errorlevel 1 goto fail
copy /y "src\docs\KEDIT_MANUAL.html" "disk\kedit\" >nul
if errorlevel 1 goto fail
copy /y "src\docs\KEDIT_MANUAL.pdf" "disk\kedit\" >nul
if errorlevel 1 goto fail
copy /y "src\kedit\RELEASE.txt" "disk\kedit\" >nul
if errorlevel 1 goto fail

copy /y "src\docs\DIARY_MANUAL.md" "disk\kdiary\" >nul
if errorlevel 1 goto fail
copy /y "src\docs\DIARY_MANUAL.html" "disk\kdiary\" >nul
if errorlevel 1 goto fail
copy /y "src\docs\DIARY_MANUAL.pdf" "disk\kdiary\" >nul
if errorlevel 1 goto fail
copy /y "src\kdiary\RELEASE.txt" "disk\kdiary\" >nul
if errorlevel 1 goto fail

echo.
echo Shared source: src\common (both programs were assembled from it)
echo BUILD OK: disk\kedit\ (KEDIT.dsk, manual, RELEASE.txt, nbyte.py) and disk\kdiary\ (KDIARY.DSK, manual, RELEASE.txt, nbyte.py, kdiary_decrypt.py)
endlocal
exit /b 0

:fail
echo.
echo BUILD FAILED
endlocal
exit /b 1
