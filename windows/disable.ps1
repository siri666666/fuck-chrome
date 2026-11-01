<#
.SYNOPSIS
  Disable and remove the Gemini Nano on-device model that Google Chrome downloads on its own.

.DESCRIPTION
  1. Sets the Chrome enterprise policy GenAILocalFoundationalModelSettings = 1 under HKLM
     (one UAC prompt). With this policy Chrome stops downloading the model.
  2. Deletes the OptGuideOnDeviceModel folder (~4 GB) of every Chrome channel / Chromium
     found for the current user. Chrome does not reliably delete it by itself.

.PARAMETER KeepFiles
  Only set the policy, keep the model files.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\disable.ps1
#>
param([switch]$KeepFiles)

$ErrorActionPreference = 'Stop'
$PolicyName = 'GenAILocalFoundationalModelSettings'

$Browsers = [ordered]@{
    'Chrome'        = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    'Chrome Beta'   = "$env:LOCALAPPDATA\Google\Chrome Beta\User Data"
    'Chrome Dev'    = "$env:LOCALAPPDATA\Google\Chrome Dev\User Data"
    'Chrome Canary' = "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
    'Chromium'      = "$env:LOCALAPPDATA\Chromium\User Data"
}

function Get-PolicyValue([string]$Key) {
    try { (Get-ItemProperty -Path "HKLM:\$Key" -Name $PolicyName -ErrorAction Stop).$PolicyName } catch { $null }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- 1. policy
# HKCU\SOFTWARE\Policies is not writable by normal users, so the policy goes to HKLM.
$Keys = @('SOFTWARE\Policies\Google\Chrome')   # shared by Stable / Beta / Dev / Canary
if (Test-Path -LiteralPath $Browsers['Chromium']) { $Keys += 'SOFTWARE\Policies\Chromium' }

Write-Host '[1/2] Chrome policy' -ForegroundColor Cyan
$Todo = @($Keys | Where-Object { (Get-PolicyValue $_) -ne 1 })
if ($Todo.Count -gt 0) {
    $Cmd = ($Todo | ForEach-Object { "reg add HKLM\$_ /v $PolicyName /t REG_DWORD /d 1 /f" }) -join ' && '
    if (Test-Admin) {
        cmd.exe /c $Cmd | Out-Null
    } else {
        Write-Host '  Administrator rights are needed to write the policy. Click "Yes" in the UAC prompt.'
        try {
            Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '/c', $Cmd | Out-Null
        } catch {
            Write-Host '  UAC prompt was cancelled. Nothing changed.' -ForegroundColor Red
            exit 1
        }
    }
}
$PolicyOk = $true
foreach ($k in $Keys) {
    if ((Get-PolicyValue $k) -eq 1) {
        Write-Host "  OK   HKLM\$k\$PolicyName = 1" -ForegroundColor Green
    } else {
        Write-Host "  FAIL HKLM\$k\$PolicyName was not written" -ForegroundColor Red
        $PolicyOk = $false
    }
}
if (-not $PolicyOk) { exit 1 }

# ---------------------------------------------------------------- 2. files
Write-Host '[2/2] Model files' -ForegroundColor Cyan
if ($KeepFiles) {
    Write-Host '  Skipped (-KeepFiles).'
} else {
    $Freed = [int64]0
    $Found = $false
    foreach ($name in $Browsers.Keys) {
        $dir = Join-Path $Browsers[$name] 'OptGuideOnDeviceModel'
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $Found = $true
        $size = [int64](Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum).Sum
        try {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
            $Freed += $size
            Write-Host ("  Removed  {0,-14} {1:N2} GB  {2}" -f $name, ($size / 1GB), $dir) -ForegroundColor Green
        } catch {
            Write-Host "  Could not remove $dir (files in use)." -ForegroundColor Yellow
            Write-Host "  Quit $name completely (check the tray icon) and run this script again." -ForegroundColor Yellow
        }
    }
    if (-not $Found) { Write-Host '  No OptGuideOnDeviceModel folder found. Nothing to delete.' }
    elseif ($Freed -gt 0) { Write-Host ("  Freed {0:N2} GB" -f ($Freed / 1GB)) -ForegroundColor Green }
}

Write-Host ''
Write-Host 'Done. Restart Chrome (open chrome://restart), then check chrome://policy:'
Write-Host "  $PolicyName should be 1 with status OK."
Write-Host 'Chrome will now show "Managed by your organization". That is expected: it only means a policy is set.'
