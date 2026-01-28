@echo off
title Tutorial Recorder Setup
echo.
echo ============================================================
echo   OBS Tutorial Recorder - Windows Setup
echo ============================================================
echo.
echo This will install all dependencies and configure the app.
echo.
pause

cd /d "%~dp0"
python setup.py

echo.
echo Setup complete!
pause
