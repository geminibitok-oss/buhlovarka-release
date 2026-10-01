@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ===================================================================
echo     Бухловарка / HelloDistiller — Автоматическая прошивка
echo     Репозиторий: geminibitok-oss/buhlovarka-release
echo ===================================================================
echo.

set FW_DIR=%~dp0firmware_cache
if not exist "%FW_DIR%" mkdir "%FW_DIR%"

echo [1/3] Загрузка актуальных файлов прошивки из GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$repo = 'geminibitok-oss/buhlovarka-release'; " ^
  "$files = @('version.txt', 'bootloader.bin', 'partitions.bin', 'firmware.bin', 'littlefs.bin', 'mega2560_firmware.hex'); " ^
  "foreach ($f in $files) { " ^
  "  Write-Host (' Скачивание: ' + $f + ' ...'); " ^
  "  $u1 = 'https://raw.githubusercontent.com/' + $repo + '/main/' + $f; " ^
  "  $u2 = 'https://github.com/' + $repo + '/releases/latest/download/' + $f; " ^
  "  try { Invoke-WebRequest -Uri $u1 -OutFile ('%FW_DIR%\' + $f) -UseBasicParsing -ErrorAction Stop } " ^
  "  catch { try { Invoke-WebRequest -Uri $u2 -OutFile ('%FW_DIR%\' + $f) -UseBasicParsing -ErrorAction Stop } catch {} } " ^
  "}"

if not exist "%FW_DIR%\firmware.bin" (
    echo.
    echo [ОШИБКА] Не удалось скачать файлы прошивки.
    echo Проверьте подключение к интернету или доступность репозитория:
    echo https://github.com/geminibitok-oss/buhlovarka-release
    echo.
    pause
    exit /b 1
)

set CURR_VER=Неизвестно
if exist "%FW_DIR%\version.txt" (
    set /p CURR_VER=<"%FW_DIR%\version.txt"
)

echo.
echo ===================================================================
echo  Успешно загружена версия: !CURR_VER!
echo ===================================================================
echo.
echo Выберите, что вы хотите прошить:
echo.
echo   [1] Прошить ESP32-C3 ПОЛНОСТЬЮ (Прошивка C++ + Веб-интерфейс LittleFS)
echo   [2] Прошить ТОЛЬКО Веб-интерфейс ESP32-C3 (LittleFS)
echo   [3] Прошить ТОЛЬКО C++ Прошивку ESP32-C3 (Firmware)
echo   [4] Прошить ТОЛЬКО Arduino Mega 2560 (mega2560_firmware.hex)
echo   [5] Прошить ВСЁ по очереди (Сначала ESP32-C3, затем Mega 2560)
echo   [6] Выход
echo.
set /p CHOICE="Введите номер действия [1-6]: "

if "%CHOICE%"=="1" goto flash_esp_all
if "%CHOICE%"=="2" goto flash_esp_web
if "%CHOICE%"=="3" goto flash_esp_code
if "%CHOICE%"=="4" goto flash_mega
if "%CHOICE%"=="5" goto flash_all
if "%CHOICE%"=="6" exit /b 0

echo Неверный выбор!
pause
exit /b 1

:: ===================================================
:: Поиск esptool для ESP32-C3
:: ===================================================
:find_esptool
set ESPTOOL=
if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.exe" set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.exe"
if not defined ESPTOOL if exist "%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe" set ESPTOOL="%USERPROFILE%\.platformio\penv\Scripts\esptool.py.exe"
if not defined ESPTOOL (
    where esptool.py >nul 2>nul
    if not errorlevel 1 set ESPTOOL=esptool.py
)
if not defined ESPTOOL (
    echo [ИНФО] Поиск esptool... Скачивание официальной утилиты esptool...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/espressif/esptool/releases/download/v4.7.0/esptool-v4.7.0-win64.zip' -OutFile '%FW_DIR%\esptool.zip'; Expand-Archive '%FW_DIR%\esptool.zip' -DestinationPath '%FW_DIR%\esptool_pkg' -Force" 2>nul
    if exist "%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe" set ESPTOOL="%FW_DIR%\esptool_pkg\esptool-win64\esptool.exe"
)
exit /b 0

:: ===================================================
:: Поиск avrdude для Arduino Mega 2560
:: ===================================================
:find_avrdude
set AVRDUDE=
set AVRCONF=

for /d %%D in ("%USERPROFILE%\.platformio\packages\tool-avrdude*") do (
    if exist "%%D\bin\avrdude.exe" (
        set AVRDUDE="%%D\bin\avrdude.exe"
        if exist "%%D\etc\avrdude.conf" set AVRCONF="%%D\etc\avrdude.conf"
        if exist "%%D\avrdude.conf" set AVRCONF="%%D\avrdude.conf"
    )
    if exist "%%D\avrdude.exe" (
        set AVRDUDE="%%D\avrdude.exe"
        if exist "%%D\avrdude.conf" set AVRCONF="%%D\avrdude.conf"
    )
)

if not defined AVRDUDE (
    for /d %%D in ("%LOCALAPPDATA%\Arduino15\packages\arduino\tools\avrdude\*") do (
        if exist "%%D\bin\avrdude.exe" (
            set AVRDUDE="%%D\bin\avrdude.exe"
            set AVRCONF="%%D\etc\avrdude.conf"
        )
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

:: ===================================================
:: Определение COM порта
:: ===================================================
:ask_port
echo.
echo Доступные COM-порты в системе:
powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object"
echo.
set /p TARGET_PORT="Введите COM-порт вашего устройства (например, COM3, COM7): "
if "%TARGET_PORT%"=="" (
    echo [ОШИБКА] Порт не указан!
    pause
    exit /b 1
)
exit /b 0

:: ===================================================
:: Прошивка ESP32-C3: Всё разом
:: ===================================================
:flash_esp_all
call :find_esptool
if not defined ESPTOOL (
    echo [ОШИБКА] Не найдена утилита esptool для прошивки ESP32.
    pause
    exit /b 1
)
call :ask_port
echo.
echo ===================================================
echo   Прошивка ESP32-C3 на порту !TARGET_PORT!...
echo ===================================================
%ESPTOOL% --chip esp32c3 --port !TARGET_PORT! --baud 460800 write_flash -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"

if errorlevel 1 (
    echo [ОШИБКА] Сбой при прошивке ESP32-C3!
) else (
    echo.
    echo ===================================================
    echo [УСПЕХ] ESP32-C3 успешно прошит!
    echo Подключайтесь к Wi-Fi: Buhlovarka_C3 (пароль 12345678)
    echo ===================================================
)
pause
exit /b 0

:: ===================================================
:: Прошивка ESP32-C3: Только Веб-интерфейс (LittleFS)
:: ===================================================
:flash_esp_web
call :find_esptool
call :ask_port
echo.
echo Прошивка веб-интерфейса LittleFS на порту !TARGET_PORT!...
%ESPTOOL% --chip esp32c3 --port !TARGET_PORT! --baud 460800 write_flash -z 0x290000 "%FW_DIR%\littlefs.bin"
if errorlevel 1 (
    echo [ОШИБКА] Сбой при записи LittleFS!
) else (
    echo [УСПЕХ] Веб-интерфейс LittleFS успешно обновлен!
)
pause
exit /b 0

:: ===================================================
:: Прошивка ESP32-C3: Только Firmware C++
:: ===================================================
:flash_esp_code
call :find_esptool
call :ask_port
echo.
echo Прошивка микропрограммы C++ на порту !TARGET_PORT!...
%ESPTOOL% --chip esp32c3 --port !TARGET_PORT! --baud 460800 write_flash -z 0x10000 "%FW_DIR%\firmware.bin"
if errorlevel 1 (
    echo [ОШИБКА] Сбой при записи Firmware!
) else (
    echo [УСПЕХ] Микропрограмма C++ успешно обновлена!
)
pause
exit /b 0

:: ===================================================
:: Прошивка Arduino Mega 2560
:: ===================================================
:flash_mega
call :find_avrdude
if not defined AVRDUDE (
    echo.
    echo [ОШИБКА] Утилита avrdude не найдена на вашем ПК.
    echo Убедитесь, что установлена Arduino IDE или PlatformIO.
    pause
    exit /b 1
)
call :ask_port
echo.
echo ===================================================
echo   Прошивка Arduino Mega 2560 на порту !TARGET_PORT!...
echo ===================================================
set AVR_CONF_ARG=
if defined AVRCONF set AVR_CONF_ARG=-C %AVRCONF%

%AVRDUDE% %AVR_CONF_ARG% -v -p atmega2560 -c wiring -P !TARGET_PORT! -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i

if errorlevel 1 (
    echo.
    echo [ОШИБКА] Сбой при прошивке Arduino Mega 2560!
    echo Проверьте правильность COM-порта и подключение платы.
) else (
    echo.
    echo ===================================================
    echo [УСПЕХ] Arduino Mega 2560 успешно прошита!
    echo ===================================================
)
pause
exit /b 0

:: ===================================================
:: Прошивка ВСЕГО (ESP32-C3 + Mega 2560)
:: ===================================================
:flash_all
call :find_esptool
call :find_avrdude

echo.
echo [Шаг 1 из 2] Прошивка модуля ESP32-C3:
call :ask_port
%ESPTOOL% --chip esp32c3 --port !TARGET_PORT! --baud 460800 write_flash -z 0x0 "%FW_DIR%\bootloader.bin" 0x8000 "%FW_DIR%\partitions.bin" 0x10000 "%FW_DIR%\firmware.bin" 0x290000 "%FW_DIR%\littlefs.bin"

echo.
echo [Шаг 2 из 2] Прошивка контроллера Arduino Mega 2560:
echo Подключите кабель к плате Arduino Mega 2560.
call :ask_port
set AVR_CONF_ARG=
if defined AVRCONF set AVR_CONF_ARG=-C %AVRCONF%
%AVRDUDE% %AVR_CONF_ARG% -v -p atmega2560 -c wiring -P !TARGET_PORT! -b 115200 -D -U flash:w:"%FW_DIR%\mega2560_firmware.hex":i

echo.
echo ===================================================
echo [ПОЛНЫЙ УСПЕХ] Все контроллеры успешно прошиты!
echo ===================================================
pause
exit /b 0
