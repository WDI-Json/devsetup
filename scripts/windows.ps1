$ErrorActionPreference = "Stop"

function Set-JsonFile {
  param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [Parameter(Mandatory = $true)] $Object
  )
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  $Object | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8
}

function Read-JsonFile {
  param(
    [Parameter(Mandatory = $true)] [string] $Path
  )
  if (-not (Test-Path $Path)) {
    return $null
  }
  try {
    return Get-Content -Path $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

# Taskbar left alignment (Windows 11)
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -PropertyType DWord -Value 0 -Force | Out-Null

# Taskbar on the left side (vertical) where supported (Windows 10)
$stuckRectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
if (Test-Path $stuckRectsPath) {
  $stuckRects = (Get-ItemProperty -Path $stuckRectsPath -Name Settings -ErrorAction Stop).Settings
  if ($stuckRects.Length -gt 12) {
    $stuckRects[12] = 0
    Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $stuckRects
  }
}

# PowerToys Keyboard Manager: Caps Lock -> Escape
$keyboardManagerPath = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys\Keyboard Manager\default.json"
$keyboardManager = Read-JsonFile -Path $keyboardManagerPath
if ($null -eq $keyboardManager) {
  $keyboardManager = [pscustomobject]@{
    remapKeys      = @()
    remapShortcuts = @()
  }
}
if (-not $keyboardManager.PSObject.Properties["remapKeys"]) {
  $keyboardManager | Add-Member -MemberType NoteProperty -Name remapKeys -Value @()
}
if (-not $keyboardManager.PSObject.Properties["remapShortcuts"]) {
  $keyboardManager | Add-Member -MemberType NoteProperty -Name remapShortcuts -Value @()
}
$keyboardManager.remapKeys = @(
  @($keyboardManager.remapKeys | Where-Object {
    $_.originalKey -ne "CapsLock" -and $_.originalKey -ne "Caps Lock"
  })
  [pscustomobject]@{
    originalKey = "CapsLock"
    newKey      = "Escape"
  }
)
Set-JsonFile -Path $keyboardManagerPath -Object $keyboardManager

# PowerToys Run: Win+Space quick launcher shortcut
$powerToysRunPath = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys\PowerToys Run\Settings.json"
$powerToysRun = Read-JsonFile -Path $powerToysRunPath
if ($null -eq $powerToysRun) {
  $powerToysRun = [pscustomobject]@{
    name       = "PowerLauncher"
    version    = "1"
    properties = [pscustomobject]@{}
  }
}
if (-not $powerToysRun.PSObject.Properties["properties"]) {
  $powerToysRun | Add-Member -MemberType NoteProperty -Name properties -Value ([pscustomobject]@{})
}
if (-not $powerToysRun.properties.PSObject.Properties["OpenPowerLauncher"]) {
  $powerToysRun.properties | Add-Member -MemberType NoteProperty -Name OpenPowerLauncher -Value ([pscustomobject]@{})
}
if (-not $powerToysRun.properties.OpenPowerLauncher.PSObject.Properties["value"]) {
  $powerToysRun.properties.OpenPowerLauncher | Add-Member -MemberType NoteProperty -Name value -Value "Win + Space"
} else {
  $powerToysRun.properties.OpenPowerLauncher.value = "Win + Space"
}
Set-JsonFile -Path $powerToysRunPath -Object $powerToysRun

Write-Output "Windows settings applied. Restart Explorer (or sign out and back in) for taskbar changes, and restart PowerToys if the new hotkey is not active yet."
