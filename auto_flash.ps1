# Buhlovarka Auto Flasher
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
.UI.RawUI.WindowTitle = 'Buhlovarka Auto Flasher'

Write-Host '===================================================================' -ForegroundColor Cyan
Write-Host '    Бухловарка / HelloDistiller -- Автоматическая прошивка' -ForegroundColor Yellow
Write-Host '    Репозиторий: geminibitok-oss/buhlovarka-release' -ForegroundColor Cyan
Write-Host '===================================================================' -ForegroundColor Cyan
Write-Host ''

 = Split-Path -Parent .MyCommand.Path
 = Join-Path  'firmware_cache'
if (-not (Test-Path )) {
    New-Item -ItemType Directory -Path  -Force | Out-Null
}

 = 'geminibitok-oss/buhlovarka-release'
 = @('version.txt', 'bootloader.bin', 'partitions.bin', 'firmware.bin', 'littlefs.bin', 'mega2560_firmware.hex')

Write-Host '1/3 Скачивание файлов прошивки из GitHub...' -ForegroundColor Green
foreach ( in ) {
    Write-Host ('  Скачивание: ' + ) -ForegroundColor Gray
     = Join-Path  
     = 'https://raw.githubusercontent.com/' +  + '/main/' + 
     = 'https://github.com/' +  + '/releases/latest/download/' + 
    try {
        Invoke-WebRequest -Uri  -OutFile  -UseBasicParsing -ErrorAction Stop
    } catch {
        try {
            Invoke-WebRequest -Uri  -OutFile  -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host ('  Не удалось загрузить: ' + ) -ForegroundColor DarkYellow
        }
    }
}

 = Join-Path  'firmware.bin'
if (-not (Test-Path )) {
    Write-Host ''
    Write-Host 'ОШИБКА: Файлы прошивки не найдены в репозитории!' -ForegroundColor Red
    Write-Host ('Проверьте: https://github.com/' + ) -ForegroundColor Yellow
    Write-Host ''
    Read-Host 'Нажмите Enter для выхода...'
    exit 1
}

 = 'v2.8.X'
 = Join-Path  'version.txt'
if (Test-Path ) {
     = (Get-Content  -Raw).Trim()
}

Write-Host ''
Write-Host '===================================================================' -ForegroundColor Cyan
Write-Host (' Успешно загружена версия: ' + ) -ForegroundColor Green
Write-Host '===================================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Выберите действие:' -ForegroundColor White
Write-Host '  1. Прошить ESP32-C3 ПОЛНОСТЬЮ (Прошивка C++ + Веб-интерфейс)' -ForegroundColor Yellow
Write-Host '  2. Прошить ТОЛЬКО Веб-интерфейс ESP32-C3 (LittleFS)' -ForegroundColor White
Write-Host '  3. Прошить ТОЛЬКО Прошивку C++ ESP32-C3 (Firmware)' -ForegroundColor White
Write-Host '  4. Прошить ТОЛЬКО Arduino Mega 2560 (mega2560_firmware.hex)' -ForegroundColor Yellow
Write-Host '  5. Прошить ВСЕ (Сначала ESP32-C3, затем Mega 2560)' -ForegroundColor Green
Write-Host '  6. Выход' -ForegroundColor Gray
Write-Host ''

 = Read-Host 'Введите номер действия 1-6'
if ( -eq '6' -or [string]::IsNullOrWhiteSpace()) {
    exit 0
}

function Find-Esptool {
     = @(
        ($env:USERPROFILE + '\.platformio\penv\Scripts\esptool.exe'),
        ($env:USERPROFILE + '\.platformio\penv\Scripts\esptool.py.exe'),
        (Join-Path  'esptool\esptool.exe')
    )
    foreach ( in ) {
        if (Test-Path ) { return  }
    }
     = Get-Command esptool.py -ErrorAction SilentlyContinue
    if () { return 'esptool.py' }

    Write-Host 'ИНФО: Загрузка esptool...' -ForegroundColor Yellow
     = Join-Path  'esptool.zip'
     = Join-Path  'esptool_pkg'
    try {
        Invoke-WebRequest -Uri 'https://github.com/espressif/esptool/releases/download/v4.7.0/esptool-v4.7.0-win64.zip' -OutFile  -UseBasicParsing
        Expand-Archive -Path  -DestinationPath  -Force
         = Join-Path  'esptool-win64\esptool.exe'
        if (Test-Path ) { return  }
    } catch {}
    return 
}

function Find-Avrdude {
     = $env:USERPROFILE + '\.platformio\packages'
    if (Test-Path ) {
         = Get-ChildItem (Join-Path  'tool-avrdude*') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if () {
             = Join-Path .FullName 'binvrdude.exe'
            if (-not (Test-Path )) {  = Join-Path .FullName 'avrdude.exe' }
             = Join-Path .FullName 'etcvrdude.conf'
            if (-not (Test-Path )) {  = Join-Path .FullName 'avrdude.conf' }
            if (Test-Path ) { return @{ Exe = ; Conf =  } }
        }
    }

     = $env:LOCALAPPDATA + '\Arduino15\packagesrduino	oolsvrdude'
    if (Test-Path ) {
         = Get-ChildItem (Join-Path  '*') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if () {
             = Join-Path .FullName 'binvrdude.exe'
             = Join-Path .FullName 'etcvrdude.conf'
            if (Test-Path ) { return @{ Exe = ; Conf =  } }
        }
    }

     = 'C:\Program Files (x86)\Arduino\hardware	oolsvrinvrdude.exe'
     = 'C:\Program Files (x86)\Arduino\hardware	oolsvr\etcvrdude.conf'
    if (Test-Path ) {
        return @{ Exe = ; Conf =  }
    }

     = Get-Command avrdude -ErrorAction SilentlyContinue
    if () { return @{ Exe = 'avrdude'; Conf =  } }
    return 
}

function Ask-Port([string]) {
    Write-Host ''
    Write-Host 'Доступные COM-порты в системе:' -ForegroundColor Cyan
     = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
    if (.Count -eq 0) {
        Write-Host '  (COM-порты не обнаружены! Подключите USB кабель)' -ForegroundColor Red
    } else {
        foreach ( in ) {
            Write-Host ('  -> ' + ) -ForegroundColor Green
        }
    }
    Write-Host ''
     = Read-Host 
    return .Trim().ToUpper()
}

 = Join-Path  'bootloader.bin'
 = Join-Path  'partitions.bin'
 = Join-Path  'firmware.bin'
 = Join-Path  'littlefs.bin'
 = Join-Path  'mega2560_firmware.hex'

if ( -eq '1' -or  -eq '2' -or  -eq '3' -or  -eq '5') {
     = Find-Esptool
    if (-not ) {
        Write-Host 'ОШИБКА: Не удалось найти или скачать esptool!' -ForegroundColor Red
        Read-Host 'Нажмите Enter для выхода...'
        exit 1
    }

     = Ask-Port 'Введите COM-порт ESP32-C3 (например COM3)'
    if ([string]::IsNullOrWhiteSpace()) {
        Write-Host 'ОШИБКА: Порт не указан!' -ForegroundColor Red
        exit 1
    }

    if ( -eq '1' -or  -eq '5') {
        Write-Host ''
        Write-Host '=== Полная прошивка ESP32-C3 (bootloader + partitions + firmware + littlefs) ===' -ForegroundColor Yellow
        &  --chip esp32c3 --port  --baud 460800 write_flash -z 0x0  0x8000  0x10000  0x290000 
    } elseif ( -eq '2') {
        Write-Host ''
        Write-Host '=== Прошивка Веб-интерфейса ESP32-C3 (littlefs) ===' -ForegroundColor Yellow
        &  --chip esp32c3 --port  --baud 460800 write_flash -z 0x290000 
    } elseif ( -eq '3') {
        Write-Host ''
        Write-Host '=== Прошивка Программы C++ ESP32-C3 (firmware) ===' -ForegroundColor Yellow
        &  --chip esp32c3 --port  --baud 460800 write_flash -z 0x10000 
    }

    if ( -eq 0) {
        Write-Host ''
        Write-Host 'УСПЕХ: ESP32-C3 успешно прошит!' -ForegroundColor Green
        Write-Host 'Точка доступа: Buhlovarka_C3 (пароль 12345678)' -ForegroundColor Cyan
        Write-Host 'Адрес в браузере: http://192.168.4.1' -ForegroundColor Cyan
    } else {
        Write-Host ''
        Write-Host 'ОШИБКА: Сбой при прошивке ESP32-C3.' -ForegroundColor Red
    }
}

if ( -eq '4' -or  -eq '5') {
     = Find-Avrdude
    if (-not ) {
        Write-Host 'ОШИБКА: Утилита avrdude не найдена на вашем ПК.' -ForegroundColor Red
        Read-Host 'Нажмите Enter для выхода...'
        exit 1
    }

    Write-Host ''
    if ( -eq '5') {
        Write-Host 'Подключите USB кабель к плате Arduino Mega 2560...' -ForegroundColor Yellow
    }
     = Ask-Port 'Введите COM-порт Arduino Mega 2560 (например COM4)'
    if ([string]::IsNullOrWhiteSpace()) {
        Write-Host 'ОШИБКА: Порт не указан!' -ForegroundColor Red
        exit 1
    }

    Write-Host ''
    Write-Host ('=== Прошивка Arduino Mega 2560: ' +  + ' ===') -ForegroundColor Yellow

     = .Exe
     = @('-v', '-p', 'atmega2560', '-c', 'wiring', '-P', , '-b', '115200', '-D', ('-Uflash:w:' +  + ':i'))
    if (.Conf -and (Test-Path .Conf)) {
         = @('-C', .Conf) + 
    }

    &  

    if ( -eq 0) {
        Write-Host ''
        Write-Host 'УСПЕХ: Arduino Mega 2560 успешно прошита!' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host 'ОШИБКА: Сбой при прошивке Arduino Mega 2560.' -ForegroundColor Red
    }
}

Write-Host ''
Write-Host '===================================================================' -ForegroundColor Cyan
Write-Host 'Завершено.' -ForegroundColor White
Write-Host '===================================================================' -ForegroundColor Cyan
Read-Host 'Нажмите Enter для закрытия...'
