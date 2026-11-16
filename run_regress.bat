@echo off
rem run_regress.bat - regression run: baseline (before the key/command change) against the current build,
rem for KEDIT (kregress.py) and KDIARY (dregress.py). Takes about 40 minutes (MAME, one run at a time).
rem Result: work\regress\REPORT.txt (the comparisons are included). Logs: work\regress\logs\.
setlocal
cd /d "%~dp0"
python src\tools\regress_all.py
set RC=%errorlevel%
echo.
echo Report: %cd%\work\regress\REPORT.txt
endlocal & exit /b %RC%
