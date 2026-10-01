@echo off
setlocal enabledelayedexpansion
title Buhlovarka Auto Flasher
cd /d "%~dp0"

echo ===================================================================
echo     Buhlovarka / HelloDistiller Firmware Flasher
echo     Repository: github.com/geminibitok-oss/buhlovarka-release
echo ===================================================================
echo.

set "FW_DIR=%~dp0firmware_cache"
if not exist "%FW_DIR%" mkdir "%FW_DIR%"

echo [1/3] Downloading latest firmware files...
call :download_file "bootloader.bin"
call :download_file "partitions.bin"
call :download_file "firmware.bin"
call :download_file "littlefs.bin"
call :download_file "mega2560_firmware.hex"
call :download_file "version.txt"

rem Check if downloaded, otherwise check local project folders
if not exist "%FW_DIR%\firmware.bin" (
    if exist "%~dp0platformio_esp32c3\.pio\build\esp32c3\firmware.bin" (
        echo [INFO] Using locally compiled firmware from PlatformIO...
        copy /y "%~dp0platformio_esp32c3\.pio\build\esp32c3\*.bin" "%FW_DIR%\" >nul 2>nul
        if exist "%~dp0platformio_mega2560\.pio\build\megaatmega2560\firmware.hex" (
            copy /y "%~dp0platformio_mega2560\.pio\build\megaatmega2560\firmware.hex" "%FW_DIR%\mega2560_firmware.hex" >nul 2>nul
        )
    )
)

if not exist "%FW_DIR%\firmware.bin" (
    echo.
    echo ===================================================================
    echo [ERROR] Firmware files not found on GitHub or locally!
    echo Please make sure https://github.com/geminibitok-oss/buhlovarka-release
    echo has published releases or build files.
    echo ===================================================================
    echo.
    pause
    exit /b 1
)

set "VERSION=v2.8.X"
if exist "%FW_DIR%\version.txt" set /p VERSION=<"%FW_DIR%\version.txt"

:menu
cls
echo ===================================================================
echo     Buhlovarka Flasher - Current Version: %VERSION%
echo ===================================================================
echo.
echo Select action:
echo.
echo   [1] Flash ESP32-C3 COMPLETE (Full clean flash with Erase: Boot + Partitions + Firmware + Web)
echo   [2] Flash ESP32-C3 LittleFS ONLY (Web Interface)
echo   [3] Flash ESP32-C3 Firmware ONLY (C++ Code)
echo   [4] Flash Arduino Mega 2560 ONLY (mega2560_firmware.hex)
echo   [5] Flash EVERYTHING (ESP32-C3 clean, then Mega 2560)
echo   [6] ERASE ESP32-C3 Flash (Полная очистка памяти чипа)
echo   [7] Serial Monitor (Просмотр логов платы на 115200)
echo   [8] Exit
echo.

set "CHOICE="
set /p CHOICE="Enter choice [1-8]: "
if "%CHOICE%"=="1" goto flash_esp_full
if "%CHOICE%"=="2" goto flash_esp_web
if "%CHOICE%"=="3" goto flash_esp_fw
if "%CHOICE%"=="4" goto flash_mega
if "%CHOICE%"=="5" goto flash_both
if "%CHOICE%"=="6" goto erase_esp
if "%CHOICE%"=="7" goto serial_monitor
if "%CHOICE%"=="8" goto end
goto menu

:download_file
set "FNAME=%~1"
echo   Downloading %FNAME%...
curl -s -L -f -o "%FW_DIR%\%FNAME%" "https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/%FNAME%"
if not exist "%FW_DIR%\%FNAME%" (
    curl -s -L -f -o "%FW_DIR%\%FNAME%" "https://github.com/geminibitok-oss/buhlovarka-release/releases/latest/download/%FNAME%"
)
if not exist "%FW_DIR%\%FNAME%" (
    powershell -NoProfile -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/%FNAME%', '%FW_DIR%\%FNAME%')" >nul 2>nul
)
exit /b 0

:detect_ports
echo.
echo Available COM ports:
powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object"
echo.
set "PORT="
set /p PORT="Enter COM port (e.g. COM3 or COM4): "
if "%PORT%"=="" (
    echo [ERROR] No COM port entered!
    pause
    goto menu
)
exit /b 0

:find_esptool
set "ESPTOOL="
if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.exe" set "ESPTOOL=%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not defined ESPTOOL if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe" set "ESPTOOL=%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe"
if not defined ESPTOOL (
    where esptool.py >nul 2>nul
    if not errorlevel 1 set "ESPTOOL=esptool.py"
)
if not defined ESPTOOL (
    echo [INFO] Downloading official esptool flasher...
    curl -s -L -o "%FW_DIR%\esptool.zip" "https://github.com/espressif/esptool/releases/download/v4.7.0/esptool-v4.7.0-win64.zip"
    powershell -NoProfile -Command "Expand-Archive -Path '%FW_DIR%\esptool.zip' -DestinationPath '%FW_DIR%\esptool_pkg' -Force" >nul 2>nul
    if exist "%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe" (
        set "ESPTOOL=%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe"
    )
)
if not defined ESPTOOL (
    echo [ERROR] Could not find or download esptool!
    pause
    goto menu
)
exit /b 0

:find_avrdude
set "AVRDUDE="
set "AVRCONF="
for /d %%D in ("%USERPROFILE%\.platformio\packages\tool-avrdude*") do (
    if exist "%%D\bin\avrdude.exe" (
        set "AVRDUDE=%%D\bin\avrdude.exe"
        if exist "%%D\etc\avrdude.conf" set "AVRCONF=%%D\etc\avrdude.conf"
    )
)
if not defined AVRDUDE (
    for /d %%D in ("%LOCALAPPDATA%\Arduino15\packages\arduino\tools\avrdude\*") do (
        if exist "%%D\bin\avrdude.exe" (
            set "AVRDUDE=%%D\bin\avrdude.exe"
            if exist "%%D\etc\avrdude.conf" set "AVRCONF=%%D\etc\avrdude.conf"
        )
    )
)
if not defined AVRDUDE (
    if exist "C:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe" (
        set "AVRDUDE=C:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe"
        set "AVRCONF=C:\Program Files (x86)\Arduino\hardware\tools\avr\etc\avrdude.conf"
    )
)
if not defined AVRDUDE (
    where avrdude >nul 2>nul
    if not errorlevel 1 set "AVRDUDE=avrdude"
)
if not defined AVRDUDE (
    echo [ERROR] avrdude flasher not found! Please install Arduino IDE or PlatformIO.
    pause
    goto menu
)
exit /b 0

:flash_esp_full
call :find_esptool
call :detect_ports
echo.
echo Flashing ESP32-C3 Complete with Flash Erase on %PORT% (DIO 40MHz)...
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 --flash_mode dio --flash_freq 40m --flash_size 4MB write_flash --erase-all -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"
echo.
if errorlevel 1 (
    echo [ERROR] Flashing failed! Check cable and port.
) else (
    echo ===================================================
    echo [SUCCESS] ESP32-C3 successfully flashed!
    echo.
    echo IMPORTANT STEP:
    echo 1. Unplug the USB cable from PC for 2 seconds and plug back in!
    echo    (Or press the RST button on ESP32-C3)
    echo 2. Connect to Wi-Fi: Buhlovarka_C3 (pass: 12345678)
    echo 3. Open browser: http://192.168.4.1
    echo ===================================================
)
echo.
pause
goto menu

:flash_esp_web
call :find_esptool
call :detect_ports
echo.
echo Flashing ESP32-C3 Web Interface (LittleFS) on %PORT%...
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 write_flash -z 0x290000 "%FW_DIR%\littlefs.bin"
echo.
if errorlevel 1 (
    echo [ERROR] Flashing LittleFS failed!
) else (
    echo [SUCCESS] Web interface successfully updated!
)
echo.
pause
goto menu

:flash_esp_fw
call :find_esptool
call :detect_ports
echo.
echo Flashing ESP32-C3 Firmware C++ on %PORT%...
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 --flash_mode dio --flash_freq 40m write_flash -z 0x10000 "%FW_DIR%\firmware.bin"
echo.
if errorlevel 1 (
    echo [ERROR] Flashing firmware failed!
) else (
    echo [SUCCESS] C++ firmware successfully updated!
)
echo.
pause
goto menu

:flash_mega
call :find_avrdude
call :detect_ports
echo.
echo Flashing Arduino Mega 2560 on %PORT%...
set "CONF_FLAG="
if defined AVRCONF set "CONF_FLAG=-C "%AVRCONF%""
"%AVRDUDE%" %CONF_FLAG% -v -p atmega2560 -c wiring -P %PORT% -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i
echo.
if errorlevel 1 (
    echo [ERROR] Flashing Arduino Mega 2560 failed!
) else (
    echo ===================================================
    echo [SUCCESS] Arduino Mega 2560 successfully flashed!
    echo ===================================================
)
echo.
pause
goto menu

:flash_both
call :find_esptool
call :find_avrdude
echo.
echo --- STEP 1: Flash ESP32-C3 ---
call :detect_ports
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 --flash_mode dio --flash_freq 40m --flash_size 4MB write_flash --erase-all -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"

echo.
echo --- STEP 2: Flash Arduino Mega 2560 ---
echo Please connect USB cable to Arduino Mega 2560...
call :detect_ports
set "CONF_FLAG="
if defined AVRCONF set "CONF_FLAG=-C "%AVRCONF%""
"%AVRDUDE%" %CONF_FLAG% -v -p atmega2560 -c wiring -P %PORT% -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i
echo.
echo ===================================================
echo [ALL DONE] Both controllers successfully flashed!
echo ===================================================
echo.
pause
goto menu
:erase_esp
call :find_esptool
call :detect_ports
echo.
echo Erasing entire ESP32-C3 flash memory on %PORT%...
"%ESPTOOL%" --chip esp32c3 --port %PORT% erase_flash
echo.
if errorlevel 1 (
    echo [ERROR] Flash erase failed!
) else (
    echo [SUCCESS] Flash memory successfully erased clean!
    echo Now select [1] to flash fresh firmware and web interface.
)
echo.
pause
goto menu

:serial_monitor
call :detect_ports
echo.
echo ===================================================
echo   ESP32-C3 Serial Monitor on %PORT% (115200 baud)
echo   Press Ctrl+C to exit monitor
echo ===================================================
if exist "%USERPROFILE%\.platformio\penv\Scripts\python.exe" (
    "%USERPROFILE%\.platformio\penv\Scripts\python.exe" -m serial.tools.miniterm %PORT% 115200
    goto menu
)
powershell -NoProfile -Command "$p = New-Object System.IO.Ports.SerialPort '%PORT%', 115200; $p.DtrEnable = $true; $p.RtsEnable = $true; $p.Open(); Write-Host '--- Monitor Connected (Press Ctrl+C to exit) ---' -ForegroundColor Green; while($true){ if($p.BytesToRead -gt 0){ [Console]::Write($p.ReadExisting()) } Start-Sleep -Milliseconds 50 }"
pause
goto menu

:end
exit /b 0
