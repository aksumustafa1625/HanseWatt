# HanseWatt — run SQL against the Data 360 (Data Cloud) Query API.
# This is the programmatic grounding path (ADR-007 figures-half): query the ingested
# Meter Reading DLO directly, no UI Calculated Insight required.
#
# Usage:
#   pwsh scripts/datacloud_query.ps1 -SqlFile scripts/datacloud_ci_anomaly.sql
#   pwsh scripts/datacloud_query.ps1 -Sql "SELECT count(*) FROM Meter_Reading_c_Home__dll"
param(
  [string]$Sql,
  [string]$SqlFile,
  [string]$Org = 'hansewatt',
  [string]$ApiVersion = 'v64.0'
)
if ($SqlFile) {
  # Strip full-line SQL comments — the Data Cloud Query API rejects `--` comments.
  $Sql = ((Get-Content $SqlFile) | Where-Object { $_ -notmatch '^\s*--' }) -join "`n"
}
if (-not $Sql) { Write-Error 'Provide -Sql or -SqlFile'; exit 1 }

$d = sf org display --target-org $Org --json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty result
$body = (@{ sql = $Sql } | ConvertTo-Json -Compress)
$resp = Invoke-RestMethod -Method Post `
  -Uri "$($d.instanceUrl)/services/data/$ApiVersion/ssot/queryv2" `
  -Headers @{ Authorization = "Bearer $($d.accessToken)"; 'Content-Type' = 'application/json' } `
  -Body $body

Write-Output ("Columns: " + ($resp.metadata.PSObject.Properties.Name -join ', '))
Write-Output ("Rows: " + $resp.rowCount)
$resp.data | ForEach-Object { $_ -join '  |  ' }
