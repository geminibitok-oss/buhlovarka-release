@echo off
setlocal
cd /d "%~dp0"
title Buhlovarka Auto Flasher

if not exist "%~dp0auto_flash.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/auto_flash.ps1' -OutFile '%~dp0auto_flash.ps1' -UseBasicParsing"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0auto_flash.ps1"
if errorlevel 1 pause
