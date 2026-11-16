@echo off
rem run_tests_editor.bat - build KEDIT, then run its MAME tests (test_kedit1 ... test_kedit16), one at a time.
rem Each test's output goes to work\testlogs\<test>.txt. A test FAILS when its log has MISMATCH or Traceback.
rem Needs MAME (see src\tools\session.py). Takes a while: each test runs the emulator.

setlocal
cd /d "%~dp0"
set PYTHONIOENCODING=utf8
if not exist work\testlogs mkdir work\testlogs

python src\kedit\build.py
if errorlevel 1 (echo BUILD FAILED & exit /b 1)

set FAIL=0
set RUN=0
for %%t in (test_kedit1 test_kedit2 test_kedit3 test_kedit4 test_kedit5 test_kedit6 test_kedit7 test_kedit8 test_kedit9 test_kedit10 test_kedit11 test_kedit12 test_kedit13 test_kedit14 test_kedit15 test_kedit16) do call :run %%t

echo.
if %FAIL%==0 (echo EDITOR TESTS: %RUN% RUN, NO MISMATCH) else (echo EDITOR TESTS: %FAIL% OF %RUN% WITH A MISMATCH - see work\testlogs)
endlocal & exit /b %FAIL%

:run
set /a RUN+=1
echo === %1
pushd src\tools
python %1.py > "%~dp0work\testlogs\%1.txt" 2>&1
popd
findstr /C:"MISMATCH" /C:"Traceback" "%~dp0work\testlogs\%1.txt" >nul && (echo     FAILED: %1 & set /a FAIL+=1) || echo     ok
goto :eof
