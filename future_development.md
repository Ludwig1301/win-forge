# Future Development Roadmap (`win-forge`)

This document tracks the planned **v2+** expansion of `win-forge` across all **9 core modules**. Features marked **v1** are already implemented and verified; items under **Planned (v2+)** build on the same interactive **Scan → User Selection → One-by-One Execution & Verification** architecture for both **Windows 10** and **Windows 11**.

---

## 1. System Audit
- **In v1:** OS/Build detection (`Win 10` vs. `Win 11`), uptime, RAM/CPU/pagefile usage, active power plan, Known Folder Move safety check, and `Win32_Process` grouping.
- **Planned (v2+):**
  - Thermal & CPU throttling diagnostics (clock speed vs. base/boost, ACPI thermal zones, power throttling flags).
  - Battery health & wear report (`powercfg /batteryreport` summary).
  - Disk health & SSD/NVMe wear check (`Get-PhysicalDisk`, `Get-StorageReliabilityCounter`).
  - Critical Windows Event Log error digest (recent BSODs, app crashes, disk/driver warnings).

## 2. Disk Cleanup
- **In v1:** Junction-safe `robocopy /L /XJ` folder sizing, User `Temp`, `CrashDumps`, `.nuget\packages`, Chrome/Edge `Cache`, Recycle Bin, Storage Sense enablement, `SoftwareDistribution\Download` active `UsoSvc` lock check, `Windows.old` via `cleanmgr /sagerun`, and folder-to-secondary-drive junction moves.
- **Planned (v2+):**
  - Developer ecosystem caches: `npm`, `yarn`, `pnpm`, `pip`, `uv`, `Gradle`, `Maven`, Cargo, and JetBrains/VS Code extension caches.
  - Docker Desktop & WSL2 virtual disk (`ext4.vhdx` / `docker_data.vhdx`) pruning and `Optimize-VHD` / `diskpart` compaction.
  - Delivery Optimization (`DO`) cache and Windows Error Reporting (`WER`) queues.
  - Dry-run space-reclaim estimator before any deletion.

## 3. App Manager *(New in v2)*
- **In v1:** Only ad-hoc removals and `winget` queries were used manually.
- **Planned (v2+):**
  - Unified inventory of Win32 (`winget list` / Uninstall registry) and Store (`Get-AppxPackage`) apps with install size and last-used hints.
  - Safe uninstall workflow with post-uninstall scrubbing of leftover folders, Scheduled Tasks, and orphaned Windows Services.
  - Guided app/game relocation to secondary drives (`D:`) via `robocopy` + directory junctions (`mklink /J`) with rollback support.

## 4. Debloat
- **In v1:** Known-Folder-safe OneDrive full disable (+ VSS recovery fallback), Edge Startup Boost & Background Mode disable, and Windows 10/11 taskbar widget removal (`EnableFeeds` / `AllowNewsAndInterests`).
- **Planned (v2+):**
  - Curated, reversible Windows 10 & Windows 11 AppX allowlist/denylist (never breaking Store, Gaming/Xbox, Phone Link, or codecs).
  - Telemetry, advertising ID, Start Menu suggestions, and lock-screen ad/spotlight policies.
  - Exportable registry backup (`.reg`) before applying any debloat preset.

## 5. Process Manager
- **In v1:** RAM-grouped `Win32_Process` audit and tracing respawners back to Scheduled Tasks and Services.
- **Planned (v2+):**
  - Live 2–5 second CPU delta sampling per process and per app group (accurate multi-core `%CPU`).
  - Handle/thread leak detection (flagging long-running processes with excessive handles or uptime).
  - Automatic parent-chain & trigger lookup (finding *what* launches or restarts a noisy process).

## 6. Driver Manager
- **In v1:** `Win32_PnPSignedDriver` inventory, `Microsoft.Update.Session` (`Type='Driver'`) check, Authenticode verification, and silent install handling (e.g., Intel `-s`).
- **Planned (v2+):**
  - Optional OEM CLI integration when supported (e.g., `Dell.CommandUpdate` `dcu-cli`, Lenovo/HP vendor feeds).
  - Pre-update System Restore point / driver INF export (`pnputil /export-driver`) for instant rollback.
  - BIOS/UEFI version advisory check (read-only notice, never auto-flashing without explicit user confirmation).

## 7. Startup Optimizer
- **In v1:** Full 5-layer audit (`HKCU/HKLM\...\Run`, Startup folders, Store `AppModel\SystemAppData`, non-Windows Scheduled Tasks, 3rd-party Automatic Services) and disabling Edge/PowerToys/Store/Service auto-starts.
- **Planned (v2+):**
  - Decoding `StartupApproved\Run` binary timestamps/status flags.
  - Boot-time impact tagging and "self-healing service" detection (auto-flagging services that revert `Manual` → `Automatic` so the user can choose `Disabled`).
  - Switchable profiles (**Minimal**, **Dev**, **Gaming**).

## 8. Performance Tuning
- **In v1:** Ultimate Performance power plan, Hibernate AC/DC timeout audit (`HIBERNATEIDLE`), Windows Defender `Workspace`/IDE exclusions, Developer Mode, and external display gaming checks.
- **Planned (v2+):**
  - Windows 10/11 Visual Effects presets (Best Appearance vs. Balanced vs. Performance).
  - Hardware-Accelerated GPU Scheduling (`HwSchMode`) and Game Mode verification.
  - SSD TRIM verification (`fsutil behavior query DisableDeleteNotify`) and pagefile sizing guidance.
  - Network & DNS latency checks (clean adapter bindings, DNS benchmark).

## 9. System Repair *(New in v2)*
- **In v1:** Not included.
- **Planned (v2+):**
  - Component Store & System File repair pipeline: `DISM /CheckHealth` → `ScanHealth` → `RestoreHealth` → `sfc /scannow`.
  - Disk integrity check (`chkdsk C: /scan` read-only first).
  - Performance Counter rebuild (`lodctr /R` — fixes `Get-Counter` `c0000bb8` errors).
  - Windows Update service & cache reset (`wuauserv`, `bits`, `cryptsvc`, `msiserver`) when updates get stuck.
  - Explorer Icon/Thumbnail cache & Winsock/DNS reset.

---

## Cross-Cutting Standards for v2+
- **Interactive One-by-One Execution:** Keep strict separation between Phase 1 (Read-Only Scan), Phase 2 (User Selection), and Phase 3 (Sequential Execution + Verification).
- **Locale-Safe Scripting:** Always use `CultureInvariant` / `.ToLowerInvariant()` in PowerShell string comparisons (avoiding `tr-TR` `I`/`i` casing bugs).
- **Windows 10 & 11 Parity:** Branch explicitly on `[System.Environment]::OSVersion.Version.Build` (`>= 22000` for Windows 11).
