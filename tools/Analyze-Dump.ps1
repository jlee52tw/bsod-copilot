<#
.SYNOPSIS
    Runs a comprehensive BSOD triage analysis on a kernel memory dump.

.DESCRIPTION
    Wrapper around Invoke-KdCommand.ps1 that executes a curated set of
    WinDbg commands for initial BSOD triage. Produces a single combined
    log with all essential diagnostic information.

    Commands executed:
      - vertarget         : OS version, machine type, dump timestamp
      - .bugcheck         : Bugcheck code and parameters
      - !analyze -v       : Full automated crash analysis
      - !sysinfo smbios   : BIOS/system hardware info
      - !cpuinfo          : CPU details
      - !prcb             : Processor control block state
      - !thread           : Current thread details
      - kb 100            : Full kernel stack backtrace (100 frames)
      - !irql             : Current IRQL level
      - lm t n            : Loaded modules with timestamps
      - !vm               : Virtual memory summary

.PARAMETER DumpFile
    Full path to the MEMORY.DMP file. If omitted, attempts to auto-detect
    by searching the workspace recursively.

.PARAMETER OutputFile
    Path to the output log file. Defaults to output\analysis.log near the dump.

.EXAMPLE
    .\Analyze-Dump.ps1 -DumpFile "C:\dumps\MEMORY.DMP"

.EXAMPLE
    .\Analyze-Dump.ps1
    # Auto-discovers MEMORY.DMP in the workspace
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DumpFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$invokeScript = Join-Path $scriptDir "Invoke-KdCommand.ps1"

# ── Auto-discover dump if not specified ───────────────────────────────────────
if (-not $DumpFile) {
    $workspaceRoot = Split-Path -Parent $scriptDir
    Write-Host "Searching for MEMORY.DMP in $workspaceRoot ..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path $workspaceRoot -Filter "MEMORY.DMP" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $DumpFile = $found.FullName
        Write-Host "Found: $DumpFile" -ForegroundColor Green
    } else {
        Write-Error "No MEMORY.DMP found under $workspaceRoot. Please specify -DumpFile."
        exit 1
    }
}

if (-not (Test-Path $DumpFile)) {
    Write-Error "Dump file not found: $DumpFile"
    exit 1
}

# ── Define triage commands ────────────────────────────────────────────────────
$triageCommands = @(
    ".echo ======== TARGET INFO ========",
    "vertarget",
    ".echo ======== BUGCHECK ========",
    ".bugcheck",
    ".echo ======== FULL ANALYSIS ========",
    "!analyze -v",
    ".echo ======== SMBIOS INFO ========",
    "!sysinfo smbios",
    ".echo ======== CPU INFO ========",
    "!cpuinfo",
    ".echo ======== PRCB (Processor Control Block) ========",
    "!prcb",
    ".echo ======== CURRENT THREAD ========",
    "!thread",
    ".echo ======== KERNEL STACK TRACE (100 frames) ========",
    "kb 100",
    ".echo ======== IRQL ========",
    "!irql",
    ".echo ======== LOADED MODULES ========",
    "lm t n",
    ".echo ======== VIRTUAL MEMORY ========",
    "!vm",
    ".echo ======== END OF TRIAGE ========"
) -join "; "

# ── Build parameters ─────────────────────────────────────────────────────────
$params = @{
    DumpFile = $DumpFile
    Commands = $triageCommands
    Reason   = "Initial triage - running curated diagnostic commands to identify bugcheck code, faulting module, system hardware, OS version, processor state, loaded drivers, and memory usage"
    StepNumber = 1
}
if ($OutputFile) {
    $params["OutputFile"] = $OutputFile
}

# ── Execute ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           BSOD Full Triage Analysis                            " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

& $invokeScript @params
