@echo off
echo ===================================================
echo    Buhlovarka ESP32 Classic 1-Click Flasher
echo ===================================================
echo.
set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe"
if not exist %ESPTOOL% set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not exist %ESPTOOL% set ESPTOOL=esptool.py
%ESPTOOL% --chip esp32 write_flash -z 0x1000 esp32_bootloader.bin 0x8000 esp32_partitions.bin 0x10000 esp32_firmware.bin 0x290000 esp32_littlefs.bin
pause
