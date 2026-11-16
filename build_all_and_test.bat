@echo off
rem build_all_and_test.bat - build both disks (build_all.bat), then run the editor and diary tests
rem (run_tests_editor.bat, run_tests_diary.bat). Writes the report to work\test_report.txt.
rem The report has the date, each step's result, the per-test lines and the totals.

setlocal
cd /d "%~dp0"
if not exist work mkdir work
set REP=work\test_report.txt

echo Report of %date% %time% > "%REP%"
echo.>> "%REP%"

echo === Build (build_all.bat)
call "%~dp0build_all.bat" > work\build_run.txt 2>&1
set BLD=%errorlevel%
type work\build_run.txt
echo BUILD: %BLD% (0 = ok)>> "%REP%"
if not %BLD%==0 (
  echo.>> "%REP%"
  echo BUILD FAILED: no tests were run. See work\build_run.txt.>> "%REP%"
  echo BUILD FAILED. See %REP%
  endlocal & exit /b 1
)

echo === Editor tests
call "%~dp0run_tests_editor.bat" > work\editor_run.txt 2>&1
set EDR=%errorlevel%
type work\editor_run.txt

echo === Diary tests
call "%~dp0run_tests_diary.bat" > work\diary_run.txt 2>&1
set DIR=%errorlevel%
type work\diary_run.txt

rem the report: the child logs in full
(
  echo.
  echo ---- Editor tests ^(run_tests_editor.bat^) ----
  type work\editor_run.txt
  echo.
  echo ---- Diary tests ^(run_tests_diary.bat^) ----
  type work\diary_run.txt
  echo.
  echo ---- Totals ----
  if %EDR%==0 (echo Editor: all tests passed) else (echo Editor: %EDR% test^(s^) with a mismatch)
  if %DIR%==0 (echo Diary:  all tests passed) else (echo Diary:  %DIR% test^(s^) with a mismatch)
  echo.
  echo Per-test logs: work\testlogs\
) >> "%REP%"

echo.
echo Report written to %REP%
if not %EDR%==0 goto somefail
if not %DIR%==0 goto somefail
echo ALL PASSED
endlocal & exit /b 0

:somefail
echo SOME TESTS FAILED - see %REP%
endlocal & exit /b 1
