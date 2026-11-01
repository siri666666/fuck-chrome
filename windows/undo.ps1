<#
.SYNOPSIS
  Undo disable.ps1: remove the GenAILocalFoundationalModelSettings policy (one UAC prompt).
  After restarting Chrome it may download the model again if your hardware qualifies.
#>
$ErrorActionPreference = 'Stop'
$PolicyName = 'GenAILocalFoundationalModelSettings'
$Keys = 'SOFTWARE\Policies\Google\Chrome', 'SOFTWARE\Policies\Chromium'

function Get-PolicyValue([string]$Key) {
    try { (Get-ItemProperty -Path "HKLM:\$Key" -Name $PolicyName -ErrorAction Stop).$PolicyName } catch { $null }
}

$Todo = @($Keys | Where-Object { $null -ne (Get-PolicyValue $_) })
if ($Todo.Count -eq 0) {
    Write-Host 'Policy is not set. Nothing to undo.'
    exit 0
}

$Cmd = ($Todo | ForEach-Object { "reg delete HKLM\$_ /v $PolicyName /f" }) -join ' & '
Write-Host 'Click "Yes" in the UAC prompt.'
try {
    Start-Process cmd.exe -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '/c', $Cmd | Out-Null
} catch {
    Write-Host 'UAC prompt was cancelled. Nothing changed.' -ForegroundColor Red
    exit 1
}

$left = @($Keys | Where-Object { $null -ne (Get-PolicyValue $_) })
if ($left.Count -eq 0) {
    Write-Host 'Policy removed. Restart Chrome (chrome://restart) for it to take effect.' -ForegroundColor Green
} else {
    Write-Host "Failed to remove: $($left -join ', ')" -ForegroundColor Red
    exit 1
}
