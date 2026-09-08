# Import a mongodump folder into LOCAL MongoDB (Windows PowerShell).
#
# WARNING: --drop (default) replaces collections in the LOCAL target DB only.
#
# Usage:
#   .\scripts\deploy\import-local-db.ps1 .\backups\atlas-20260908-100501\brillarhrportal
#   .\scripts\deploy\import-local-db.ps1 .\backups\atlas-20260908-100501

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$DumpPath,
    [Parameter(Position = 1)]
    [string]$LocalDb = $(if ($env:LOCAL_DB) { $env:LOCAL_DB } else { 'brillarhrportal' }),
    [string]$LocalMongoUri = $(if ($env:LOCAL_MONGODB_URI) { $env:LOCAL_MONGODB_URI } else { 'mongodb://localhost:27017' }),
    [bool]$DropExisting = $(if ($env:DROP_EXISTING -eq 'false') { $false } else { $true })
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DumpPath -PathType Container)) {
    Write-Error "Dump folder not found: $DumpPath"
    exit 1
}

if (-not (Get-Command mongorestore -ErrorAction SilentlyContinue)) {
    Write-Error 'mongorestore not found. Install MongoDB Database Tools and add it to PATH.'
    exit 1
}

Write-Host "Checking local MongoDB at $LocalMongoUri ..."

$mongoReachable = $false
if (Get-Command mongosh -ErrorAction SilentlyContinue) {
    & mongosh $LocalMongoUri --eval "db.adminCommand('ping')" --quiet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $mongoReachable = $true }
} else {
    $portCheck = Test-NetConnection -ComputerName localhost -Port 27017 -WarningAction SilentlyContinue
    if ($portCheck.TcpTestSucceeded) { $mongoReachable = $true }
}

if (-not $mongoReachable) {
    Write-Error 'Cannot reach local MongoDB on port 27017. Start the MongoDB service first.'
    exit 1
}

$bsonFiles = Get-ChildItem -LiteralPath $DumpPath -Filter '*.bson' -File -ErrorAction SilentlyContinue
$restoreArgs = @('--uri', $LocalMongoUri)

if ($bsonFiles.Count -gt 0) {
    Write-Host 'Detected database dump folder (contains .bson files directly).'
    $restoreArgs += @('--db', $LocalDb, '--dir', $DumpPath)
} else {
    $nestedPath = Join-Path $DumpPath $LocalDb
    if (-not (Test-Path -LiteralPath $nestedPath -PathType Container)) {
        Write-Error "Expected either .bson files in $DumpPath or subfolder $nestedPath"
        exit 1
    }
    Write-Host "Detected parent dump folder (contains '$LocalDb' subfolder)."
    $restoreArgs += @('--dir', $DumpPath, '--nsInclude', "$LocalDb.*")
}

if ($DropExisting) {
    $restoreArgs += '--drop'
    Write-Host "Restoring with --drop (replaces existing collections in '$LocalDb')."
} else {
    Write-Host "Restoring without --drop (merges into existing '$LocalDb')."
}

Write-Host "Importing into local database '$LocalDb' ..."
$prevErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$restoreOutput = (& mongorestore @restoreArgs 2>&1 | ForEach-Object { "$_" }) -join "`n"
$restoreExit = $LASTEXITCODE
$ErrorActionPreference = $prevErrorAction
Write-Host $restoreOutput

if ($restoreExit -ne 0) {
    Write-Error "mongorestore failed (exit $restoreExit)."
    exit $restoreExit
}

if ($restoreOutput -match '0 document\(s\) restored successfully') {
    Write-Error 'Import finished but 0 documents were restored. Check the dump path.'
    exit 1
}

Write-Host ''
Write-Host 'Import complete.'
Write-Host "  Local URI : $LocalMongoUri"
Write-Host "  Database  : $LocalDb"
