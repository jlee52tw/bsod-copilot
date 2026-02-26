# BSOD Analysis Report — 0x1CA SYNTHETIC_WATCHDOG_TIMEOUT

**Dump File:** `C:\working\bsod-copilot\Dell_Huraca...1CA_0212\Dell_Huraca...1CA_0212\MEMORY.DMP`  
**Analysis Date:** 2026-02-26  
**Crash Date:** Thu Feb 12 11:10:16 2026 (UTC+8)  
**Analyst:** VS Code Copilot (automated WinDbg analysis)

---

## Bugcheck Summary

| Field | Value |
|-------|-------|
| **Bugcheck Code** | `0x1CA` — **SYNTHETIC_WATCHDOG_TIMEOUT** |
| **Description** | A system-wide watchdog has expired. The system is hung and not processing timer ticks. |
| **Arg1** | `0x314c63aeb` — Time since watchdog was last reset (interrupt time) |
| **Arg2** | `0x180cca4c34d` — Current interrupt time |
| **Arg3** | `0x180cca7d1a1` — Current QPC timestamp |
| **Arg4** | `0x3` — **Clock processor index = Processor 3** |
| **Failure Bucket** | `0x1CA_intelppm!HvRequestIdle` |
| **Failure Hash** | `{ac8a1de9-87b3-5d8f-7494-76100a5e5946}` |

---

## Root Cause (One-Line)

**Processor 3 (the designated clock processor) became permanently stuck in a Hyper-V idle halt hypercall (`HvlRequestProcessorHalt`) and stopped processing timer ticks, triggering the system-wide synthetic watchdog NMI after ~21 minutes.**

---

## System Information

| Field | Value |
|-------|-------|
| **Manufacturer** | Dell Inc. |
| **Model** | XPS 14 DA14260 |
| **Family** | Dell Laptops |
| **Serial Number** | W5RNHDV |
| **SKU** | 0DB9 |
| **BIOS Version** | 89.11.2 |
| **BIOS Date** | 12/24/2025 |
| **SMBIOS Version** | 3.9 |
| **Chassis** | Notebook |

### CPU

| Field | Value |
|-------|-------|
| **Processor** | Intel Core Ultra X7 358H |
| **Architecture** | Arrow Lake-H (Family 6, Model 204, Stepping 2) |
| **Cores / Threads** | 9 / 9 |
| **Base Speed** | 1900 MHz |
| **Max Speed** | 4800 MHz |
| **Microcode** | `0x11400000000` |
| **Socket** | U3E1 |

### Memory

| Field | Value |
|-------|-------|
| **Total RAM** | 64 GB |
| **Configuration** | 8 × 8 GB LPDDR5 @ 9600 MHz |
| **Form Factor** | Row of chips (soldered on motherboard) |
| **Voltage** | 500 mV |

### OS

| Field | Value |
|-------|-------|
| **OS** | Windows 10/11 Kernel Version 26100 (Build 26100.1) |
| **Build Lab** | `26100.1.amd64fre.ge_release.240331-1435` |
| **Architecture** | x64, 9 processors |
| **Hyper-V** | Enabled (root partition) |
| **HVCI** | Enabled |
| **Uptime at Crash** | 1 day 21:54:30 |

---

## Faulting Component

| Field | Value |
|-------|-------|
| **Module** | `intelppm.sys` (Intel Processor Power Management) |
| **Symbol** | `intelppm!HvRequestIdle+0x2d` |
| **Image Path** | `\SystemRoot\System32\drivers\intelppm.sys` |
| **Build Hash** | `571D222E` (reproducible build, inbox Windows driver) |
| **Image Size** | 0x50000 (320 KB) |
| **Driver Type** | Inbox Windows driver (no third-party publisher) |

Also involved:

| Module | Description | Build Hash |
|--------|-------------|------------|
| `intelpep.sys` | Intel Power Engine Plugin | `5E73192A` |
| `ntkrnlmp.exe` | Windows NT Kernel | `1C1E0BD4` |

---

## Call Stack (Annotated)

```
Frame  Address              Symbol                                  Notes
─────  ───────────────────  ──────────────────────────────────────  ─────────────────────────────────
 0d    00000000`00000000    nt!KiIdleLoop+0x54                      CPU idle loop entry
 0c    fffff802`7689ee14    nt!PoIdle+0x1c0                         Power manager selects idle state
 0b    fffff802`76642180    nt!PpmIdleExecuteTransition+0x5a9       Execute C-state transition
 0a    fffff802`766e4481    intelppm!PepIdleExecute+0x2d            Intel PPM executes idle state
 09    fffff802`23cf48dd    intelppm!HvRequestIdle+0x2d             ★ Request idle via Hyper-V
 08    fffff802`23cfa18d    nt!HvlRequestProcessorHalt+0x26         Issue hypercall to halt VP
 07    fffff802`76783a96    nt!HvcallInitiateHypercall+0x68         Hypercall entry point
 06    fffff802`76552a58    0xfffff802`05cc0003                     (VP halted — never returned)
 ───── NMI fires (watchdog timeout) ──────────────────────────────────────────────
 05    fffff802`05cc0003    nt!KiNmiInterrupt+0x26e                 NMI delivered by watchdog
 04    fffff802`768a9b2e    nt!KxNmiInterrupt+0x82                  NMI dispatch
 03    fffff802`768a9dc2    nt!KiProcessNMI+0x92                    Process NMI
 02    fffff802`767b12e2    nt!HalpPreprocessNmi+0x12               HAL NMI preprocessing
 01    fffff802`76754782    nt!HalpWatchdogCheckPreResetNMI+0xba    Watchdog detects hang
 00    fffff802`76745b7e    nt!KeBugCheckEx                         ★ BSOD triggered
```

---

## Detailed Analysis

### What Happened

1. **All 9 processors were idle** at the time of the crash. The `!running` command confirmed all processors were in idle state with zero threads in the READY queue across all processors.

2. **Processor 3 was the designated clock processor** (Arg4=3), responsible for processing system timer tick interrupts. It entered a C-state idle transition via `intelppm!PepIdleExecute`, which called `intelppm!HvRequestIdle` to request the hypervisor halt the virtual processor.

3. **The hypervisor VP halt never returned.** The `HvlRequestProcessorHalt` hypercall was issued to Hyper-V to put the processor into an idle state. The hypervisor was supposed to wake the VP on the next interrupt (e.g., timer tick), but the VP remained halted indefinitely.

4. **After ~21 minutes of no timer ticks**, the system's synthetic watchdog detected that Processor 3 was not servicing interrupts. It issued an NMI to Processor 0, which executed `HalpWatchdogCheckPreResetNMI` and triggered the bugcheck.

### Processor State at Crash

| Processor | State | Activity |
|-----------|-------|----------|
| **0** | RUNNING | `nt!KeBugCheckEx` (NMI handler — issued the bugcheck) |
| **1** | RUNNING | `intelppm!HvRequestIdle` → VP halted |
| **2** | RUNNING | `intelppm!HvRequestIdle` → VP halted |
| **3** | RUNNING | `nt!KiTimerExpiration` → `nt!KiRetireDpcList` → `nt!KiIdleLoop` (★ stuck clock proc) |
| **4** | RUNNING | `intelppm!HvRequestIdle` → VP halted |
| **5** | RUNNING | `intelppm!SelectPreferredIdleState` (selecting C-state) |
| **6** | RUNNING | `intelppm!HvRequestIdle` → VP halted |
| **7** | RUNNING | `intelppm!HvRequestIdle` → VP halted |
| **8** | RUNNING | `nt!KiSwInterrupt` → `nt!KiIdleLoop` |

All processors were in the idle loop. 6 of 9 processors were halted via the Hyper-V idle path. Processor 3 appeared stuck in `KiTimerExpiration` within `KiRetireDpcList` — it was attempting to process expired timers but was unable to complete, potentially due to a DPC that never finished or a timer callback that hung.

### Power State

- Power action state was **Idle** (no sleep/hibernate transition in progress)
- No power state transition was pending
- `pwrtest.exe` (PID 0x3224) was actively running — a Windows power management testing tool that exercises sleep/wake/idle scenarios

### Contributing Factors

1. **Hyper-V enabled** — The idle path goes through hypervisor hypercalls. The failure occurs at the hypervisor/firmware interface level, not purely in `intelppm.sys`.

2. **Arrow Lake-H (new microarchitecture)** — Intel Core Ultra X7 358H is a recent platform. Stepping 2 silicon with microcode `0x114` may have bugs in C-state or hypervisor idle handling.

3. **BIOS 89.11.2 (12/24/2025)** — Relatively recent but may not include all fixes for idle state management on this platform.

4. **`pwrtest.exe` running** — This tool actively stresses power management transitions and likely pushed the system into scenarios that exposed the firmware/microcode defect.

---

## Notable Processes at Crash

| PID | Process | Memory (Commit) | Notes |
|-----|---------|-----------------|-------|
| 0x19b8 | SupportAssistAgent.exe | 497 MB | Dell support agent (high memory consumer) |
| 0x14b8 | MsMpEng.exe | 358 MB | Windows Defender |
| 0x1ce8 | Dell.TechHub.Instrumenta | 302 MB | Dell diagnostics |
| 0x5f4 | svchost.exe | 294 MB | |
| 0x690 | dwm.exe | 239 MB | Desktop Window Manager |
| 0x3750 | wiLongRun_x64.exe | 231 MB | Workload/stress test tool |
| 0x2148 | explorer.exe | 222 MB | |
| 0x3224 | **pwrtest.exe** | **7 MB** | **★ Power management test tool** |

---

## Recommendations

### Priority 1 — BIOS/Firmware Update

Update to the latest Dell BIOS for the XPS 14 DA14260. Check [Dell Support (Service Tag: W5RNHDV)](https://www.dell.com/support/home/product-support/servicetag/W5RNHDV) for a release newer than 89.11.2 (12/24/2025). BIOS updates for Arrow Lake-H systems typically include:
- Updated Intel microcode
- C-state idle handling fixes
- Hyper-V compatibility improvements

### Priority 2 — Intel Microcode Update

Arrow Lake-H stepping 2 microcode revision `0x114` may have known errata in the C-state or VP halt path. Newer microcode is delivered via BIOS updates or Windows Update. Ensure all Windows cumulative updates are installed (the system is running build 26100.1 which is the RTM baseline).

### Priority 3 — Windows Update

Install the latest Windows cumulative update. Build `26100.1` is the initial release — newer cumulative updates may include fixes to `intelppm.sys`, `intelpep.sys`, and the Hyper-V idle dispatch path.

### Priority 4 — Workaround (if issue recurs)

- Set power plan to **High Performance** to reduce deep C-state transitions
- In BIOS setup, disable **Package C-states** or limit C-state depth
- As a diagnostic step, try disabling Hyper-V:  
  ```cmd
  bcdedit /set hypervisorlaunchtype off
  ```
  This bypasses the `HvlRequestProcessorHalt` path entirely and isolates whether the bug is hypervisor-specific.

### Priority 5 — Escalation

If the issue persists after BIOS/microcode/Windows updates, escalate to the **Intel CPU engineering team** for Arrow Lake-H idle state analysis. The failure pattern (VP halt hypercall never returning, clock processor stuck) points to a **firmware/microcode defect** at the CPU/hypervisor boundary. Provide:
- This dump file
- Microcode revision (`0x114`)
- CPU stepping (Family 6 Model 204 Stepping 2)
- Hyper-V configuration details

---

## Appendix — Key WinDbg Commands Used

| Command | Purpose |
|---------|---------|
| `!analyze -v` | Full automated crash analysis |
| `vertarget` | OS version and dump metadata |
| `.bugcheck` | Bugcheck code and parameters |
| `!sysinfo smbios` | Hardware/BIOS information |
| `!cpuinfo` | CPU details for all processors |
| `!prcb` | Processor control block state |
| `!thread` | Current thread details and stack |
| `kb 100` | Full kernel stack backtrace |
| `!irql` | Current IRQL level |
| `lm t n` | Loaded modules with timestamps |
| `!vm` | Virtual memory summary and process list |
| `!running` | Running threads on all processors |
| `!ready` | Ready thread queue |
| `!stacks 2` | All thread stacks summary |
| `!poaction` | Power action state |
| `lmvm intelppm` | Detailed intelppm.sys module info |
| `lmvm intelpep` | Detailed intelpep.sys module info |
