<#
.SYNOPSIS
    Discovers all MEMORY.DMP files in the workspace.

.DESCRIPTION
    Recursively scans the workspace root for MEMORY.DMP files and reports
    their paths, sizes, and parent folder names. Useful for Copilot to
    discover which dumps are available for analysis.

.PARAMETER SearchPath
    Root path to search. Defaults to the workspace root (parent of tools/).

.EXAMPLE
    .\List-Dumps.ps1
    .\List-Dumps.ps1 -SearchPath "D:\crash_dumps"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SearchPath
)

if (-not $SearchPath) {
    $SearchPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

Write-Host "Scanning for MEMORY.DMP files in: $SearchPath" -ForegroundColor Cyan
Write-Host ""

$dumps = Get-ChildItem -Path $SearchPath -Filter "MEMORY.DMP" -Recurse -ErrorAction SilentlyContinue

if ($dumps.Count -eq 0) {
    Write-Host "No MEMORY.DMP files found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($dumps.Count) dump file(s):" -ForegroundColor Green
Write-Host ""

foreach ($dump in $dumps) {
    $sizeMB = [math]::Round($dump.Length / 1MB, 1)
    $sizeGB = [math]::Round($dump.Length / 1GB, 2)
    $parentFolder = Split-Path -Leaf (Split-Path -Parent $dump.FullName)
    $lastWrite = $dump.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

    Write-Host "  Path:    $($dump.FullName)" -ForegroundColor White
    Write-Host "  Folder:  $parentFolder" -ForegroundColor Gray
    Write-Host "  Size:    $sizeMB MB ($sizeGB GB)" -ForegroundColor Gray
    Write-Host "  Date:    $lastWrite" -ForegroundColor Gray

    # Check if analysis output already exists
    $outputDir = Join-Path (Split-Path -Parent $dump.FullName) "output"
    $outputLog = Join-Path $outputDir "analysis.log"
    if (Test-Path $outputLog) {
        Write-Host "  Status:  Previously analyzed (output\analysis.log exists)" -ForegroundColor DarkGreen
    } else {
        Write-Host "  Status:  Not yet analyzed" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

# Output structured data for programmatic consumption
$dumps | ForEach-Object {
    [PSCustomObject]@{
        Path         = $_.FullName
        SizeMB       = [math]::Round($_.Length / 1MB, 1)
        LastModified = $_.LastWriteTime
        ParentFolder = Split-Path -Leaf (Split-Path -Parent $_.FullName)
    }
} | Format-Table -AutoSize
