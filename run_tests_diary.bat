@echo off
rem run_tests_diary.bat - build KDIARY, then run its MAME tests (test_kdiary1 ... test_kdiary11), one at a time.
rem Each test's output goes to work\testlogs\<test>.txt. A test FAILS when its log has MISMATCH or Traceback.
rem Needs MAME (see src\tools\session.py and dsession.py). Takes a while: each test runs the emulator.
rem Not included: dregress.py (compares against an older build; run it by hand: python src\tools\dregress.py).

setlocal
cd /d "%~dp0"
set PYTHONIOENCODING=utf8
if not exist work\testlogs mkdir work\testlogs

python src\kdiary\build.py
if errorlevel 1 (echo BUILD FAILED & exit /b 1)

set FAIL=0
set RUN=0
for %%t in (test_kdiary1 test_kdiary2 test_kdiary3 test_kdiary4 test_kdiary5 test_kdiary6 test_kdiary7 test_kdiary8 test_kdiary9 test_kdiary10 test_kdiary11) do call :run %%t

echo.
if %FAIL%==0 (echo DIARY TESTS: %RUN% RUN, NO MISMATCH) else (echo DIARY TESTS: %FAIL% OF %RUN% WITH A MISMATCH - see work\testlogs)
endlocal & exit /b %FAIL%

:run
set /a RUN+=1
echo === %1
pushd src\tools
python %1.py > "%~dp0work\testlogs\%1.txt" 2>&1
popd
findstr /C:"MISMATCH" /C:"Traceback" "%~dp0work\testlogs\%1.txt" >nul && (echo     FAILED: %1 & set /a FAIL+=1) || echo     ok
goto :eof
