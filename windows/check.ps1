<#
.SYNOPSIS
  Read-only check: is the Chrome on-device model (Gemini Nano) present, allowed, or running?
  Changes nothing.
#>
$ErrorActionPreference = 'SilentlyContinue'
$PolicyName = 'GenAILocalFoundationalModelSettings'

$Browsers = [ordered]@{
    'Chrome'        = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    'Chrome Beta'   = "$env:LOCALAPPDATA\Google\Chrome Beta\User Data"
    'Chrome Dev'    = "$env:LOCALAPPDATA\Google\Chrome Dev\User Data"
    'Chrome Canary' = "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
    'Chromium'      = "$env:LOCALAPPDATA\Chromium\User Data"
}

Write-Host '== Policy ==' -ForegroundColor Cyan
foreach ($hive in 'HKLM', 'HKCU') {
    foreach ($k in 'SOFTWARE\Policies\Google\Chrome', 'SOFTWARE\Policies\Chromium') {
        $v = (Get-ItemProperty -Path "${hive}:\$k" -Name $PolicyName).$PolicyName
        if ($null -ne $v) { Write-Host "  $hive\$k\$PolicyName = $v" }
    }
}
Write-Host "  (1 = blocked. Nothing listed = not set, Chrome may download the model.)"

foreach ($name in $Browsers.Keys) {
    $root = $Browsers[$name]
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Write-Host "== $name ==" -ForegroundColor Cyan

    $dir = Join-Path $root 'OptGuideOnDeviceModel'
    if (Test-Path -LiteralPath $dir) {
        $size = [int64](Get-ChildItem -LiteralPath $dir -Recurse -File -Force | Measure-Object Length -Sum).Sum
        $ver = (Get-ChildItem -LiteralPath $dir -Directory | Select-Object -First 1).Name
        $item = Get-Item -LiteralPath $dir
        Write-Host ("  Model present: {0:N2} GB, version {1}, downloaded {2}" -f ($size / 1GB), $ver, $item.CreationTime) -ForegroundColor Yellow
    } else {
        Write-Host '  Model folder: not present' -ForegroundColor Green
    }

    $ls = Join-Path $root 'Local State'
    if (Test-Path -LiteralPath $ls) {
        try {
            $j = Get-Content -LiteralPath $ls -Raw -Encoding UTF8 | ConvertFrom-Json
            $od = $j.optimization_guide.on_device
            if ($od) {
                Write-Host "  Hardware performance class: $($od.performance_class)  (Chrome uses this to decide whether to download)"
            }
            $usage = $j.optimization_guide.model_execution.last_usage_by_feature
            if ($usage -and @($usage.PSObject.Properties).Count -gt 0) {
                Write-Host '  Recorded model usage by feature:' -ForegroundColor Yellow
                $usage.PSObject.Properties | ForEach-Object { Write-Host "    $($_.Name)" }
            } else {
                Write-Host '  Recorded model usage: none'
            }
            $flags = @($j.browser.enabled_labs_experiments | Where-Object { $_ -match 'prompt-api|on-device|optimization-guide' })
            if ($flags.Count -gt 0) { Write-Host "  Related chrome://flags changed: $($flags -join ', ')" -ForegroundColor Yellow }
        } catch {
            Write-Host '  Could not parse Local State.'
        }
    }
}

Write-Host '== Running processes ==' -ForegroundColor Cyan
$running = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
             Where-Object { $_.CommandLine -match 'on_device_model' })
if ($running.Count -gt 0) {
    Write-Host "  On-device model service is running (PID $($running.ProcessId -join ', '))" -ForegroundColor Yellow
} else {
    Write-Host '  No on-device model process running.' -ForegroundColor Green
}
