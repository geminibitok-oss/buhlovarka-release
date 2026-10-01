@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
title Buhlovarka Flasher

echo ===================================================================
echo     Бухловарка / HelloDistiller — Автоматическая прошивка
echo     Репозиторий: geminibitok-oss/buhlovarka-release
echo ===================================================================
echo.

set FW_DIR=%~dp0firmware_cache
if not exist "%FW_DIR%" mkdir "%FW_DIR%"

echo [1/3] Загрузка файлов прошивки из GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $r='geminibitok-oss/buhlovarka-release'; $files=@('version.txt','bootloader.bin','partitions.bin','firmware.bin','littlefs.bin','mega2560_firmware.hex'); foreach($f in $files){ try { (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/' + $r + '/main/' + $f, '%FW_DIR%\' + $f); Write-Host ('  Скачано: ' + $f) } catch { try { (New-Object Net.WebClient).DownloadFile('https://github.com/' + $r + '/releases/latest/download/' + $f, '%FW_DIR%\' + $f); Write-Host ('  Скачано: ' + $f) } catch {} } }"

rem Если не удалось скачать из интернета, проверяем локальную сборку
if not exist "%FW_DIR%\firmware.bin" (
    if exist "%~dp0platformio_esp32c3\.pio\build\esp32c3\firmware.bin" (
        echo [ИНФО] Использование локально собранных файлов...
        copy /y "%~dp0platformio_esp32c3\.pio\build\esp32c3\*.bin" "%FW_DIR%\" >nul
        if exist "%~dp0platformio_mega2560\.pio\build\megaatmega2560\firmware.hex" copy /y "%~dp0platformio_mega2560\.pio\build\megaatmega2560\firmware.hex" "%FW_DIR%\mega2560_firmware.hex" >nul
    )
)

if not exist "%FW_DIR%\firmware.bin" (
    echo.
    echo [ОШИБКА] Файлы прошивки не найдены ни на GitHub, ни локально!
    echo Убедитесь, что репозиторий https://github.com/geminibitok-oss/buhlovarka-release содержит файлы,
    echo или скомпилируйте проект локально через PlatformIO.
    echo.
    pause
    exit /b 1
)

set CURR_VER=v2.8.X
if exist "%FW_DIR%\version.txt" set /p CURR_VER=<"%FW_DIR%\version.txt"

echo.
echo ===================================================================
echo   Версия прошивки: %CURR_VER%
echo ===================================================================
echo.
echo Выберите действие:
echo   1. Прошить ESP32-C3 ПОЛНОСТЬЮ (Прошивка C++ + Веб-интерфейс LittleFS)
echo   2. Прошить ТОЛЬКО Веб-интерфейс ESP32-C3 (LittleFS)
echo   3. Прошить ТОЛЬКО C++ Прошивку ESP32-C3 (Firmware)
echo   4. Прошить ТОЛЬКО Arduino Mega 2560 (mega2560_firmware.hex)
echo   5. Прошить ВСЕ (ESP32-C3, затем Mega 2560)
echo   6. Выход
echo.

set /p CHOICE="Введите номер действия [1-6]: "
if "%CHOICE%"=="1" goto do_esp_all
if "%CHOICE%"=="2" goto do_esp_web
if "%CHOICE%"=="3" goto do_esp_fw
if "%CHOICE%"=="4" goto do_mega
if "%CHOICE%"=="5" goto do_all
if "%CHOICE%"=="6" goto do_exit
goto do_exit

:select_port
echo.
echo Доступные COM-порты в системе:
powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object"
echo.
set TARGET_PORT=
set /p TARGET_PORT="Введите имя COM-порта (например, COM3): "
exit /b 0

:find_esptool
set ESPTOOL=
if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.exe" set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not defined ESPTOOL if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe" set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe"
if not defined ESPTOOL (
    where esptool.py >nul 2>nul
    if not errorlevel 1 set ESPTOOL=esptool.py
)
if not defined ESPTOOL (
    echo [ИНФО] Загрузка официального esptool от Espressif...
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://github.com/espressif/esptool/releases/download/v4.7.0/esptool-v4.7.0-win64.zip', '%FW_DIR%\esptool.zip'); Expand-Archive '%FW_DIR%\esptool.zip' -DestinationPath '%FW_DIR%\esptool_pkg' -Force" 2>nul
    if exist "%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe" set ESPTOOL="%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe"
)
exit /b 0

:find_avrdude
set AVRDUDE=
set AVRCONF=
for /d %%D in ("%USERPROFILE%\.platformio\packages\tool-avrdude*") do (
    if exist "%%D\bin\avrdude.exe" set AVRDUDE="%%D\bin\avrdude.exe"
    if exist "%%D\etc\avrdude.conf" set AVRCONF="%%D\etc\avrdude.conf"
)
if not defined AVRDUDE (
    for /d %%D in ("%LOCALAPPDATA%\Arduino15\packages\arduino\tools\avrdude\*") do (
        if exist "%%D\bin\avrdude.exe" set AVRDUDE="%%D\bin\avrdude.exe"
        if exist "%%D\etc\avrdude.conf" set AVRCONF="%%D\etc\avrdude.conf"
    )
)
if not defined AVRDUDE (
    if exist "C:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe" (
        set AVRDUDE="C:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe"
        set AVRCONF="C:\Program Files (x86)\Arduino\hardware\tools\avr\etc\avrdude.conf"
    )
)
if not defined AVRDUDE (
    where avrdude >nul 2>nul
    if not errorlevel 1 set AVRDUDE=avrdude
)
exit /b 0

:do_esp_all
call :find_esptool
if not defined ESPTOOL (
    echo [ОШИБКА] esptool не найден!
    pause
    exit /b 1
)
call :select_port
if not defined TARGET_PORT exit /b 1
echo.
echo Прошивка ESP32-C3 на %TARGET_PORT%...
%ESPTOOL% --chip esp32c3 --port %TARGET_PORT% --baud 460800 write_flash -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"
echo.
echo ===================================================
echo [ГОТОВО] ESP32-C3 прошит!
echo Wi-Fi сеть: Buhlovarka_C3 (пароль 12345678)
echo В браузере: http://192.168.4.1
echo ===================================================
pause
exit /b 0

:do_esp_web
call :find_esptool
call :select_port
if not defined TARGET_PORT exit /b 1
echo.
echo Прошивка веб-интерфейса LittleFS на %TARGET_PORT%...
%ESPTOOL% --chip esp32c3 --port %TARGET_PORT% --baud 460800 write_flash -z 0x290000 "%FW_DIR%\littlefs.bin"
echo [ГОТОВО] Веб-интерфейс обновлен!
pause
exit /b 0

:do_esp_fw
call :find_esptool
call :select_port
if not defined TARGET_PORT exit /b 1
echo.
echo Прошивка программы C++ на %TARGET_PORT%...
%ESPTOOL% --chip esp32c3 --port %TARGET_PORT% --baud 460800 write_flash -z 0x10000 "%FW_DIR%\firmware.bin"
echo [ГОТОВО] Программа C++ обновлена!
pause
exit /b 0

:do_mega
call :find_avrdude
if not defined AVRDUDE (
    echo [ОШИБКА] avrdude не найден! Установите PlatformIO или Arduino IDE.
    pause
    exit /b 1
)
call :select_port
if not defined TARGET_PORT exit /b 1
echo.
echo Прошивка Arduino Mega 2560 на %TARGET_PORT%...
set AVR_CONF_CMD=
if defined AVRCONF set AVR_CONF_CMD=-C %AVRCONF%
%AVRDUDE% %AVR_CONF_CMD% -v -p atmega2560 -c wiring -P %TARGET_PORT% -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i
echo.
echo [ГОТОВО] Arduino Mega 2560 успешно прошита!
pause
exit /b 0

:do_all
call :find_esptool
call :find_avrdude
echo.
echo [Шаг 1 из 2] Прошивка ESP32-C3:
call :select_port
if not defined TARGET_PORT exit /b 1
%ESPTOOL% --chip esp32c3 --port %TARGET_PORT% --baud 460800 write_flash -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"

echo.
echo [Шаг 2 из 2] Прошивка Arduino Mega 2560:
echo Подключите USB кабель к плате Arduino Mega 2560.
call :select_port
if not defined TARGET_PORT exit /b 1
set AVR_CONF_CMD=
if defined AVRCONF set AVR_CONF_CMD=-C %AVRCONF%
%AVRDUDE% %AVR_CONF_CMD% -v -p atmega2560 -c wiring -P %TARGET_PORT% -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i

echo.
echo ===================================================
echo [ПОЛНЫЙ УСПЕХ] Обе платы успешно прошиты!
echo ===================================================
pause
exit /b 0

:do_exit
echo Выход.
exit /b 0
