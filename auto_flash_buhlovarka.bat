@echo off
title Buhlovarka Auto Flasher
cd /d "%~dp0"

echo ===================================================================
echo     Buhlovarka / HelloDistiller Firmware Flasher
echo     Repository: github.com/geminibitok-oss/buhlovarka-release
echo ===================================================================
echo.

set "FW_DIR=%~dp0firmware_cache"
if not exist "%FW_DIR%" mkdir "%FW_DIR%"

echo [1/3] Checking latest release from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/version.txt', '%FW_DIR%\remote_version.txt')" >nul 2>nul

set "NEED_UPDATE=0"
if exist "%FW_DIR%\remote_version.txt" (
    if not exist "%FW_DIR%\version.txt" (
        set "NEED_UPDATE=1"
    ) else (
        fc "%FW_DIR%\version.txt" "%FW_DIR%\remote_version.txt" >nul 2>nul
        if errorlevel 1 set "NEED_UPDATE=1"
    )
)

if "%NEED_UPDATE%"=="1" (
    echo [INFO] New version detected on GitHub! Downloading fresh binaries...
    if exist "%FW_DIR%\bootloader.bin" del /q "%FW_DIR%\*.bin" >nul 2>nul
    move /y "%FW_DIR%\remote_version.txt" "%FW_DIR%\version.txt" >nul 2>nul
) else (
    if exist "%FW_DIR%\remote_version.txt" del /q "%FW_DIR%\remote_version.txt" >nul 2>nul
)

echo [2/3] Checking firmware files...
call :download_file "bootloader.bin"
call :download_file "partitions.bin"
call :download_file "firmware.bin"
call :download_file "littlefs.bin"
call :download_file "mega2560_firmware.hex"

if not exist "%FW_DIR%\firmware.bin" (
    echo.
    echo ===================================================================
    echo [ERROR] Firmware files not found in %FW_DIR%
    echo ===================================================================
    echo Press any key to exit...
    pause >nul
    goto end
)

set "VERSION=v2.8.X"
if exist "%FW_DIR%\version.txt" set /p VERSION=<"%FW_DIR%\version.txt"

:menu
cls
echo ===================================================================
echo     Buhlovarka Flasher - Version: %VERSION%
echo ===================================================================
echo.
echo Select action:
echo.
echo   [1] Flash ESP32-C3 COMPLETE (Boot + Partitions + Firmware + Web)
echo   [2] Flash ESP32-C3 LittleFS ONLY (Web Interface)
echo   [3] Flash ESP32-C3 Firmware ONLY (C++ Code)
echo   [4] Flash Arduino Mega 2560 ONLY (mega2560_firmware.hex)
echo   [5] Flash EVERYTHING (ESP32-C3 clean, then Mega 2560)
echo   [6] ERASE ESP32-C3 Flash (Full Chip Erase)
echo   [7] Serial Monitor (View live board logs on 115200 baud)
echo   [8] Exit
echo.

choice /c 12345678 /n /m "Press key [1-8]: "
if errorlevel 8 goto end
if errorlevel 7 goto serial_monitor
if errorlevel 6 goto erase_esp
if errorlevel 5 goto flash_both
if errorlevel 4 goto flash_mega
if errorlevel 3 goto flash_esp_fw
if errorlevel 2 goto flash_esp_web
if errorlevel 1 goto flash_esp_full

goto menu

:download_file
set "FNAME=%~1"
if exist "%FW_DIR%\%FNAME%" (
    echo   [OK] %FNAME% (cached)
    exit /b 0
)
echo   Downloading %FNAME%...
where curl.exe >nul 2>nul
if not errorlevel 1 (
    curl.exe -L -k -A "Mozilla/5.0" -o "%FW_DIR%\%FNAME%" "https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/%FNAME%" >nul 2>nul
)
if not exist "%FW_DIR%\%FNAME%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/geminibitok-oss/buhlovarka-release/main/%FNAME%', '%FW_DIR%\%FNAME%')" >nul 2>nul
)
if exist "%FW_DIR%\%FNAME%" (
    echo   [OK] %FNAME%
) else (
    echo   [FAILED] %FNAME%
)
exit /b 0

:detect_ports
echo.
echo Detecting COM ports...
set "DETECTED_PORT="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames() | Select-Object -First 1"`) do set "DETECTED_PORT=%%P"
if defined DETECTED_PORT (
    set "DEFAULT_PORT=%DETECTED_PORT%"
) else (
    set "DEFAULT_PORT=COM3"
)
echo Available port: %DEFAULT_PORT%
set "PORT="
set /p PORT="Enter COM port (press Enter for %DEFAULT_PORT%): "
if "%PORT%"=="" set "PORT=%DEFAULT_PORT%"
echo Using port: %PORT%
echo.
exit /b 0

:find_esptool
set "ESPTOOL="
if exist "%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe" set "ESPTOOL=%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe"
if not defined ESPTOOL if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.exe" set "ESPTOOL=%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not defined ESPTOOL (
    where esptool.py >nul 2>nul
    if not errorlevel 1 set "ESPTOOL=esptool.py"
)
if not defined ESPTOOL (
    echo [INFO] Downloading official esptool flasher...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://github.com/espressif/esptool/releases/download/v4.7.0/esptool-v4.7.0-win64.zip', '%FW_DIR%\esptool.zip'); Expand-Archive -Path '%FW_DIR%\esptool.zip' -DestinationPath '%FW_DIR%\esptool_pkg' -Force; Remove-Item '%FW_DIR%\esptool.zip' -Force" >nul 2>nul
    if exist "%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe" (
        set "ESPTOOL=%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe"
    )
)
if not defined ESPTOOL (
    echo [ERROR] Could not find or download esptool flasher.
    pause
    goto menu
)
exit /b 0

:find_avrdude
set "AVRDUDE="
set "AVRCONF="
if exist "%USERPROFILE%\.platformio\packages\tool-avrdude\bin\avrdude.exe" (
    set "AVRDUDE=%USERPROFILE%\.platformio\packages\tool-avrdude\bin\avrdude.exe"
    set "AVRCONF=%USERPROFILE%\.platformio\packages\tool-avrdude\etc\avrdude.conf"
)
if not defined AVRDUDE (
    where avrdude >nul 2>nul
    if not errorlevel 1 set "AVRDUDE=avrdude"
)
if not defined AVRDUDE (
    echo [INFO] Downloading official avrdude for Arduino Mega 2560...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://github.com/avrdudes/avrdude/releases/download/v7.2/avrdude-v7.2-windows-x64.zip', '%FW_DIR%\avrdude.zip'); Expand-Archive -Path '%FW_DIR%\avrdude.zip' -DestinationPath '%FW_DIR%\avrdude_pkg' -Force; Remove-Item '%FW_DIR%\avrdude.zip' -Force" >nul 2>nul
    if exist "%FW_DIR%\avrdude_pkg\avrdude.exe" (
        set "AVRDUDE=%FW_DIR%\avrdude_pkg\avrdude.exe"
        if exist "%FW_DIR%\avrdude_pkg\avrdude.conf" set "AVRCONF=%FW_DIR%\avrdude_pkg\avrdude.conf"
    )
)
if not defined AVRDUDE (
    echo [ERROR] Could not find or download avrdude flasher.
    pause
    goto menu
)
exit /b 0

:flash_esp_full
call :find_esptool
call :detect_ports
echo.
echo ===================================================
echo Flashing ESP32-C3 SuperMini on %PORT%...
echo ===================================================
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB --erase-all -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"
echo.
if errorlevel 1 (
    echo [ERROR] Flashing failed. Check cable and port.
) else (
    echo ===================================================
    echo [SUCCESS] ESP32-C3 successfully flashed!
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
    echo [ERROR] Flashing LittleFS failed.
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
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 write_flash --flash_mode dio --flash_freq 40m -z 0x10000 "%FW_DIR%\firmware.bin"
echo.
if errorlevel 1 (
    echo [ERROR] Flashing firmware failed.
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
    echo [ERROR] Flashing Arduino Mega 2560 failed.
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
"%ESPTOOL%" --chip esp32c3 --port %PORT% --baud 460800 write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB --erase-all -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"

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
    echo [ERROR] Flash erase failed.
) else (
    echo [SUCCESS] Flash memory successfully erased clean!
    echo Now press [1] in menu to flash fresh firmware.
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
powershell -NoProfile -Command "$p = New-Object System.IO.Ports.SerialPort '%PORT%', 115200; $p.DtrEnable = $true; $p.RtsEnable = $true; $p.Open(); Write-Host '--- Monitor Connected (Press Ctrl+C to exit) ---' -ForegroundColor Green; while($true){ if($p.BytesToRead -gt 0){ [Console]::Write($p.ReadExisting()) } Start-Sleep -Milliseconds 50 }"
echo.
echo [Serial Monitor closed]
pause
goto menu

:end
echo.
echo Closing flasher... Press any key.
pause >nul
exit
