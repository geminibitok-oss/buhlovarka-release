@echo off
echo ===================================================
echo    Buhlovarka ESP32-C3 1-Click Firmware Flasher
echo ===================================================
echo.
set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe"
if not exist %ESPTOOL% set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not exist %ESPTOOL% set ESPTOOL=esptool.py
%ESPTOOL% --chip esp32c3 write_flash -z 0x0 bootloader.bin 0x8000 partitions.bin 0x10000 firmware.bin 0x290000 littlefs.bin
pause
