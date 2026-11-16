@echo off
set "FILE=%APPDATA%\Godot\app_userdata\MTD\mtd_progress.cfg"

if exist "%FILE%" (
    del /f /q "%FILE%"
    echo Cleared: %FILE%
) else (
    echo Not found: %FILE%
    pause
)
