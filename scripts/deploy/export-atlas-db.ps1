# Export MongoDB data from Atlas to a local dump folder (Windows PowerShell).
#
# SAFE: uses mongodump only - READ-ONLY on Atlas. Nothing is deleted there.
#
# Usage:
#   $env:ATLAS_URI = "mongodb+srv://user:pass@cluster.mongodb.net/"
#   $env:ATLAS_DB = "brillarhrportal"
#   .\scripts\deploy\export-atlas-db.ps1
#
# Or pass URI as first argument:
#   .\scripts\deploy\export-atlas-db.ps1 "mongodb+srv://..." brillarhrportal

param(
    [Parameter(Position = 0)]
    [string]$AtlasUri = $env:ATLAS_URI,
    [Parameter(Position = 1)]
    [string]$AtlasDb = $(if ($env:ATLAS_DB) { $env:ATLAS_DB } else { 'brillarhrportal' }),
    [string]$DumpDir = $(if ($env:DUMP_DIR) { $env:DUMP_DIR } else { "./backups/atlas-$(Get-Date -Format 'yyyyMMdd-HHmmss')" })
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AtlasUri)) {
    Write-Error 'Provide Atlas URI via -AtlasUri, first argument, or $env:ATLAS_URI'
    exit 1
}

if (-not (Get-Command mongodump -ErrorAction SilentlyContinue)) {
    Write-Error 'mongodump not found. Install MongoDB Database Tools and add it to PATH.'
    exit 1
}

New-Item -ItemType Directory -Force -Path $DumpDir | Out-Null

Write-Host "Exporting database '$AtlasDb' to $DumpDir ..."
Write-Host '(read-only - Atlas data is not modified)'

$mongodumpArgs = @(
    '--uri', $AtlasUri
    '--db', $AtlasDb
    '--out', $DumpDir
)
& mongodump @mongodumpArgs

$dumpPath = Join-Path $DumpDir $AtlasDb
Write-Host ''
Write-Host 'Export complete.'
Write-Host "  Dump path : $dumpPath"
Write-Host ''
Write-Host 'Next - copy dump to your Linux VM, then run:'
Write-Host "  ./scripts/deploy/import-local-db.sh $dumpPath $AtlasDb"
