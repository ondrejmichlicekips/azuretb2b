param(
  [string]$ConnectionsPath = "package/connections.json"
)

if (-not (Test-Path $ConnectionsPath)) {
  Write-Error "connections.json not found at $ConnectionsPath"
  exit 1
}

$text = Get-Content -Path $ConnectionsPath -Raw
$pattern = [regex]"__([A-Z0-9_]+)__"
$replacements = @{}
$rawMap = $env:CONNECTIONS_PLACEHOLDER_JSON

if ($rawMap -and $rawMap.Trim().Length -gt 0) {
  try {
    $jsonMap = $rawMap | ConvertFrom-Json
    foreach ($prop in $jsonMap.PSObject.Properties) {
      $replacements[$prop.Name] = [string]$prop.Value
    }
  } catch {
    Write-Error "Invalid CONNECTIONS_PLACEHOLDER_JSON: $($_.Exception.Message)"
    exit 1
  }
}

$missing = New-Object System.Collections.Generic.List[string]

$updated = $pattern.Replace($text, {
  param($match)
  $key = $match.Groups[1].Value
  if ($replacements.ContainsKey($key)) {
    return $replacements[$key]
  }
  $value = [Environment]::GetEnvironmentVariable($key)
  if ([string]::IsNullOrWhiteSpace($value)) {
    $missing.Add($key) | Out-Null
    return $match.Value
  }
  return $value
})

Set-Content -Path $ConnectionsPath -Value $updated -Encoding utf8

if ($missing.Count -gt 0) {
  $missingList = ($missing | Sort-Object -Unique) -join ", "
  Write-Error "Missing placeholder values for: $missingList"
  exit 1
}

if ($pattern.IsMatch($updated)) {
  Write-Error "Unreplaced placeholders remain in connections.json"
  exit 1
}
