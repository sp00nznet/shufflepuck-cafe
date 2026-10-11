@echo off
rem QA for netlab: the conformance run, or SKIP where there is no game data
rem (the test VMs have none; they get the exe, never work\).
if not exist "%~dp0..\work\unpacked\CODE_2.dec.bin" (echo SKIP: no game data in work\ & exit /b 0)
py -3 "%~dp0conformance.py"
exit /b %errorlevel%
