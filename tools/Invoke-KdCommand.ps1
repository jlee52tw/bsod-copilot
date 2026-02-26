<#
.SYNOPSIS
    Core WinDbg/kd.exe execution engine for BSOD dump analysis.

.DESCRIPTION
    Invokes kd.exe (Kernel Debugger) against a Windows kernel memory dump file
    with arbitrary debugger commands. Handles proxy configuration, symbol path
    setup, and output logging automatically.

.PARAMETER DumpFile
    Full path to the MEMORY.DMP file to analyze.

.PARAMETER Commands
    Semicolon-separated WinDbg commands to execute against the dump.
    A trailing "q" (quit) is appended automatically.

.PARAMETER OutputFile
    Path to the log file where output will be written.
    Defaults to "output\analysis.log" relative to the dump file's directory.

.PARAMETER SymbolPath
    Symbol path override. Defaults to Microsoft public symbol server with
    local cache at C:\symbols.

.PARAMETER Append
    If specified, appends to existing output file instead of overwriting.

.EXAMPLE
    .\Invoke-KdCommand.ps1 -DumpFile "C:\dumps\MEMORY.DMP" -Commands "!analyze -v; kb 100"

.EXAMPLE
    .\Invoke-KdCommand.ps1 -DumpFile "C:\dumps\MEMORY.DMP" -Commands "!process 0 0" -Append
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$DumpFile,

    [Parameter(Mandatory = $true)]
    [string]$Commands,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [string]$SymbolPath = "srv*C:\symbols*https://msdl.microsoft.com/download/symbols",

    [switch]$Append
)

# ── Configuration ──────────────────────────────────────────────────────────────
$KD_PATH = "C:\Program Files\Windows Kits\10\Debuggers\x64\kd.exe"
$PROXY   = "http://proxy-dmz.intel.com:912"

# ── Validate kd.exe ───────────────────────────────────────────────────────────
if (-not (Test-Path $KD_PATH)) {
    Write-Error "kd.exe not found at: $KD_PATH"
    exit 1
}

# ── Resolve output file path ──────────────────────────────────────────────────
$dumpDir = Split-Path -Parent (Resolve-Path $DumpFile)
if (-not $OutputFile) {
    $outputDir = Join-Path $dumpDir "output"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $OutputFile = Join-Path $outputDir "analysis.log"
}
else {
    $parentDir = Split-Path -Parent $OutputFile
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
}

# ── Set proxy environment variables for symbol server access ──────────────────
$env:HTTP_PROXY           = $PROXY
$env:HTTPS_PROXY          = $PROXY
$env:_NT_SYMBOL_PROXY     = $PROXY
$env:NO_PROXY             = ".intel.com,intel.com,localhost,127.0.0.1"
$env:_NT_SYMBOL_PATH      = $SymbolPath

# ── Prepare banner ────────────────────────────────────────────────────────────
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$banner = @"

================================================================================
  WinDbg Analysis Run — $timestamp
  Dump: $DumpFile
  Commands: $Commands
================================================================================

"@

# ── Write/append banner ──────────────────────────────────────────────────────
if ($Append -and (Test-Path $OutputFile)) {
    Add-Content -Path $OutputFile -Value $banner -Encoding UTF8
} else {
    Set-Content -Path $OutputFile -Value $banner -Encoding UTF8
}

# ── Ensure commands end with quit ─────────────────────────────────────────────
$cmdString = $Commands.TrimEnd("; ")
if ($cmdString -notmatch ';\s*q\s*$' -and $cmdString -ne 'q') {
    $cmdString = "$cmdString; q"
}

# ── Build kd.exe arguments ───────────────────────────────────────────────────
$logFlag = if ($Append) { "-loga" } else { "-logo" }
# Use -loga always since we already wrote the banner
$logFlag = "-loga"

$kdArgs = @(
    "-z", "`"$DumpFile`"",
    "-y", "`"$SymbolPath`"",
    "-c", "`"$cmdString`"",
    $logFlag, "`"$OutputFile`""
)

# ── Execute ───────────────────────────────────────────────────────────────────
Write-Host "--- Invoking kd.exe ---" -ForegroundColor Cyan
Write-Host "  Dump:     $DumpFile" -ForegroundColor Gray
Write-Host "  Commands: $Commands" -ForegroundColor Gray
Write-Host "  Output:   $OutputFile" -ForegroundColor Gray
Write-Host "  Symbols:  $SymbolPath" -ForegroundColor Gray
Write-Host ""

$process = Start-Process -FilePath $KD_PATH `
    -ArgumentList $kdArgs `
    -NoNewWindow `
    -Wait `
    -PassThru

# ── Output results ────────────────────────────────────────────────────────────
if ($process.ExitCode -ne 0) {
    Write-Warning "kd.exe exited with code $($process.ExitCode)"
}

if (Test-Path $OutputFile) {
    Write-Host ""
    Write-Host "--- Analysis Output ---" -ForegroundColor Green
    Get-Content -Path $OutputFile -Raw
} else {
    Write-Error "Output file was not created: $OutputFile"
    exit 1
}

exit $process.ExitCode
