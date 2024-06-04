# csvrow.ps1 - Prints matching CSV row data as INI-like key-value pairs.

param (
  [string]$Key,
  [string]$CsvInput
)

function Show-Usage {
  Write-Host "Usage:"
  Write-Host "  csvrow.ps1 <key> <csv-input>"
  Write-Host ""
  Write-Host "Arguments:"
  Write-Host "  <key>         Specifies a value matching the first field in the target row."
  Write-Host "  <csv-input>   Specifies a URL or a file corresponding to CSV data, which"
  Write-Host "                may contain data or a URL to the data."
  exit 1
}

# Check if the required arguments are provided
if (-not $Key -or -not $CsvInput) {
  Show-Usage
}

function Is-Url {
  param (
    [string] $InputString
  )

  if ($InputString -match '^(http|https)://') {
    return $true
  } else {
    return $false
  }
}

function Get-CsvContent {
  param (
    [string] $CsvLocation
  )

  if (Is-Url -InputString $CsvLocation) {
    $CsvContent = & rclone copyurl $CsvLocation --stdout
  } else {
    $CsvContent = & rclone cat $CsvLocation
  }

  # Normalize line endings
  $CsvContent = $CsvContent -replace "`r`n", "`n" -replace "`r", "`n"

  # Trim leading/trailing whitespace
  $CsvContent = $CsvContent.Trim()

  # Check for nested URL (recursive call)
  if (Is-Url -InputString $CsvContent) {
    return Get-CsvContent -CsvLocation $CsvContent
  } else {
    return $CsvContent
  }
}

$CsvContent = Get-CsvContent -CsvLocation $CsvInput
$CsvContent = $CsvContent -split "`n"

$Headers = $CsvContent[0].Split(",")
$DataLine = $CsvContent | Where-Object { $_ -match "^$Key," } | Select-Object -First 1

# Check for successful data line match and sufficient headers
if ($DataLine -and $Headers.Count -gt 1) {
  $Values = $DataLine.Split(",")

  $Index = 0
  foreach ($Header in $Headers) {
    if ($Header -ceq $Header.ToUpper()) {
      $IniKey = $Header.Trim()
      $IniValue = if ($Values[$Index]) { $Values[$Index].Trim() } else { "" }
      Write-Host "$IniKey=$IniValue"
    }
    $Index++
  }
} else {
  # Do nothing other than set exit status
  exit 1
}
exit 0
