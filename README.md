# BSOD Copilot

Automated Windows BSOD (Blue Screen of Death) crash dump analysis powered by **VS Code GitHub Copilot** and **WinDbg**.

Drop a kernel memory dump into this project, open VS Code, and ask Copilot to analyze it. Copilot acts as a Windows kernel debugging expert — running WinDbg commands, interpreting results, and producing a structured root cause report.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Windows** | Windows 10 or later |
| **VS Code** | [Download](https://code.visualstudio.com/) |
| **GitHub Copilot** | VS Code extension with active subscription ([Marketplace](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)) |
| **WinDbg / Windows SDK** | Provides `kd.exe` (kernel debugger). Install the **Debugging Tools for Windows** from the [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/) or install [WinDbg Preview](https://apps.microsoft.com/detail/9PGJGD53TN86) from the Microsoft Store. |
| **PowerShell** | Windows PowerShell 5.1+ (built into Windows) |
| **Disk Space** | Enough for your memory dump + ~500 MB for symbol cache (`C:\symbols`) |

> **Note:** The scripts expect `kd.exe` at the default SDK path:
> `C:\Program Files\Windows Kits\10\Debuggers\x64\kd.exe`
> If yours is elsewhere, edit the `$KD_PATH` variable in `tools/Invoke-KdCommand.ps1`.

---

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/jlee52tw/bsod-copilot.git
cd bsod-copilot
```

### 2. Install WinDbg / Debugging Tools

If you don't already have `kd.exe` installed:

1. Download the [Windows SDK](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)
2. During installation, select only **"Debugging Tools for Windows"**
3. Verify installation:
   ```powershell
   Test-Path "C:\Program Files\Windows Kits\10\Debuggers\x64\kd.exe"
   ```

### 3. Configure Proxy (if needed)

Open `tools/Invoke-KdCommand.ps1` and edit the `$PROXY` variable near the top of the file:

```powershell
# If you need a proxy for internet access (e.g., corporate network):
$PROXY = "http://your-proxy-server:port"

# If you do NOT need a proxy (direct internet access):
$PROXY = ""
```

The proxy is used to download debug symbols from Microsoft's symbol server (`msdl.microsoft.com`). If `$PROXY` is set to `""`, no proxy environment variables are configured.

### 4. Place Your Memory Dump

Create a subfolder and copy your `MEMORY.DMP` file into it:

```
bsod-copilot/
├── MyServer_CrashDump/
│   └── MEMORY.DMP          <-- your dump file
├── tools/
├── .github/
└── ...
```

You can have multiple dump folders — each with its own `MEMORY.DMP`.

> **Tip:** `MEMORY.DMP` files are excluded from git via `.gitignore` (they're typically 1-64+ GB).

### 5. Open in VS Code

```bash
code bsod-copilot
```

---

## Usage

### Quick Start

1. Open the project in VS Code
2. Open **Copilot Chat** (`Ctrl+Alt+I` or click the Copilot icon)
3. Switch to **Agent mode** (click the mode selector at the top of the chat panel)
4. Type:
   ```
   Analyze the BSOD dump in this workspace and generate a report
   ```

Copilot will automatically:
- Discover dump files via `tools/List-Dumps.ps1`
- Run a full triage via `tools/Analyze-Dump.ps1`
- Read and interpret the WinDbg output
- Run follow-up WinDbg commands as needed to dig deeper
- Generate a structured Markdown report at `output/BSOD_Analysis_Report.md`

### Example Prompts

| Prompt | What It Does |
|--------|-------------|
| `Analyze the BSOD dump and find the root cause` | Full end-to-end analysis with report |
| `What dump files are available?` | Lists all MEMORY.DMP files in the workspace |
| `Run !process 0 0 on the dump` | Executes a specific WinDbg command |
| `What driver caused the crash?` | Focused investigation on the faulting driver |
| `Check if this is a hardware or software issue` | Targeted hardware vs. software analysis |
| `Investigate the power management state at crash time` | Deep-dive into specific subsystem |

### VS Code Tasks

Three predefined tasks are available via **Terminal → Run Task**:

| Task | Description |
|------|-------------|
| **BSOD: List Dumps** | Find all dump files in the workspace |
| **BSOD: Full Triage** | Run comprehensive analysis on the first dump found |
| **BSOD: Run Custom Command** | Run any WinDbg command (prompts for input) |

---

## How It Works

```
┌──────────────┐     ┌─────────────────────┐     ┌────────────┐
│  You (User)  │────>│  VS Code + Copilot  │────>│  kd.exe    │
│  "Analyze    │     │  (Agent Mode)       │     │  (WinDbg)  │
│   the dump"  │     │                     │     │            │
└──────────────┘     │  Reads custom       │     │  Analyzes  │
                     │  instructions from  │     │  MEMORY.DMP│
                     │  .github/copilot-   │     │            │
                     │  instructions.md    │     │  Returns   │
                     │                     │<────│  output    │
                     │  Interprets results │     └────────────┘
                     │  Runs follow-ups    │
                     │  Writes report      │
                     └─────────────────────┘
                               │
                               v
                     ┌─────────────────────┐
                     │  output/            │
                     │  ├─ analysis.log    │
                     │  └─ BSOD_Analysis_  │
                     │     Report.md       │
                     └─────────────────────┘
```

The magic is in `.github/copilot-instructions.md` — VS Code Copilot automatically loads this file as custom instructions whenever you open the workspace. It teaches Copilot to:

1. Act as a Windows kernel debugging expert
2. Use the PowerShell tool scripts to invoke `kd.exe`
3. Follow a systematic 4-phase investigation workflow
4. Apply its full WinDbg knowledge (not limited to predefined commands)
5. Generate a structured Markdown report with root cause and recommendations

---

## Project Structure

```
bsod-copilot/
├── .github/
│   └── copilot-instructions.md   # Copilot custom instructions (auto-loaded)
├── .vscode/
│   ├── settings.json             # Editor settings (hides large files)
│   └── tasks.json                # Predefined VS Code tasks
├── tools/
│   ├── Analyze-Dump.ps1          # Full triage script (11 WinDbg commands)
│   ├── Invoke-KdCommand.ps1      # Core engine: run any WinDbg command
│   └── List-Dumps.ps1            # Discover dump files in workspace
├── <YourDumpFolder>/
│   ├── MEMORY.DMP                # Your crash dump (git-ignored)
│   └── output/
│       ├── analysis.log          # Raw WinDbg output
│       └── BSOD_Analysis_Report.md  # Generated report
├── .gitignore
└── README.md
```

---

## Supported Bugcheck Codes

The instructions include specific follow-up strategies for these common bugcheck codes:

| Code | Name |
|------|------|
| 0xA | IRQL_NOT_LESS_OR_EQUAL |
| 0x19 | BAD_POOL_HEADER |
| 0x1A | MEMORY_MANAGEMENT |
| 0x1E | KMODE_EXCEPTION_NOT_HANDLED |
| 0x3B | SYSTEM_SERVICE_EXCEPTION |
| 0x50 | PAGE_FAULT_IN_NONPAGED_AREA |
| 0x7E | SYSTEM_THREAD_EXCEPTION_NOT_HANDLED |
| 0x7F | UNEXPECTED_KERNEL_MODE_TRAP |
| 0x9F | DRIVER_POWER_STATE_FAILURE |
| 0xC2 | BAD_POOL_CALLER |
| 0xC5 | DRIVER_CORRUPTED_EXPOOL |
| 0xD1 | DRIVER_IRQL_NOT_LESS_OR_EQUAL |
| 0xEF | CRITICAL_PROCESS_DIED |
| 0x133 | DPC_WATCHDOG_VIOLATION |
| 0x139 | KERNEL_SECURITY_CHECK_FAILURE |
| 0x154 | UNEXPECTED_STORE_EXCEPTION |
| 0x1CA | SYNTHETIC_WATCHDOG_TIMEOUT |

**Any bugcheck code is supported** — Copilot uses its kernel debugging expertise for codes not explicitly listed.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `kd.exe not found` | Install Debugging Tools for Windows from the Windows SDK, or update `$KD_PATH` in `tools/Invoke-KdCommand.ps1` |
| Symbols not loading | Check proxy settings in `tools/Invoke-KdCommand.ps1`. Ensure `C:\symbols` directory exists. First run downloads symbols and may take 10+ minutes. |
| `MEMORY.DMP not found` | Place your dump file in a subfolder of the project. Run the "BSOD: List Dumps" task to verify. |
| Copilot doesn't know about the tools | Make sure you're in **Agent mode** (not Ask or Edit mode). The `.github/copilot-instructions.md` file must be present. |
| Analysis is slow | Large dumps (16-64 GB) take time to process. Symbol downloads on first run add additional latency. Subsequent runs use cached symbols. |
| PowerShell execution policy error | Run: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser` |

---

## License

This project is provided as-is for educational and diagnostic purposes.

---

## Contributing

Contributions welcome! Ideas for improvement:

- Add support for minidumps (`*.dmp` in `C:\Windows\Minidump\`)
- Create additional triage presets for specific bugcheck families
- Add automated driver version comparison against known-good databases
- Integrate with Windows Update catalog for driver/BIOS recommendations
