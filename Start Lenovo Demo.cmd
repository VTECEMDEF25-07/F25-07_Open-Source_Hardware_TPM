@echo off
setlocal
cd /d "%~dp0"
py -3 "Testing\Host\lenovo_hash_panel.py" %*
if errorlevel 1 pause
