# win-forge

An interactive, verification-first **Windows 10 & Windows 11** system audit, cleanup, de-bloating, optimization, and driver management skill for Antigravity (`v1`).

> **Philosophy:** Never run blind "all-in-one" scripts that silently break your desktop, updates, or apps. `win-forge` scans read-only first, shows exact live numbers, lets you choose what to change, and executes **one step at a time** with post-action verification.

---

## How It Works

`win-forge` enforces a strict three-phase workflow:

1. **Phase 1 — Read-Only Discovery:** Runs non-destructive PowerShell audit scripts to inspect your OS build, RAM/processes, 5-layer startups, Known Folders, junction-safe disk usage, caches, and drivers. Nothing is modified.
2. **Phase 2 — User Selection:** Presents lightweight, numbered findings so you decide exactly what to keep, disable, move, or clean.
3. **Phase 3 — One-by-One Execution & Verification:** Runs one approved task at a time (elevating cleanly via transcript-logged UAC sessions when needed), verifies the new state (free space delta, registry value, service status, or driver version), and reports back before moving on.

---

## What `v1` Covers

### 1. System, Process & Startup Audit
- Detects **Windows 10** (`Build < 22000`) vs. **Windows 11** (`Build >= 22000`), uptime, RAM/pagefile, and active power plan.
- Groups running processes (`Win32_Process`) by app to expose high-RAM background consumers.
- Audits **all 5 Windows startup layers**—not just `Run` keys:
  1. `HKCU` & `HKLM` Registry `Run`
  2. User & System `Startup` folders
  3. Store / UWP `AppModel\SystemAppData` startup tasks
  4. Non-Windows Scheduled Tasks (catching hidden launchers like `\PowerToys\Autorun for <user>`)
  5. Third-party `Automatic` Windows Services (using locale-invariant path checks safe on `tr-TR` and other non-English locales)

### 2. Junction-Safe Disk Audit & Cleanup
- Measures directory sizes using `robocopy /L /XJ` so NTFS junctions never double-count files.
- Safely clears User `Temp` (e.g., `docker-scout`, stale installers), `CrashDumps`, `.nuget\packages`, Chrome/Edge `Cache` folders (without touching cookies, history, or logins), and the Recycle Bin.
- Enables Windows **Storage Sense** for ongoing automated cleanup.
- Checks `C:\Windows\SoftwareDistribution\Download` for active `UsoSvc` locks before touching it so live Windows Updates are never corrupted.
- Removes `C:\Windows.old`, `Update Cleanup`, and `Temporary Setup Files` using Windows' built-in Disk Cleanup (`cleanmgr.exe /sagerun:99`).
- Supports relocating large folders/games to a secondary drive (`D:`) via `robocopy` + `mklink /J`.

### 3. Known-Folder-Safe OneDrive Disable
- **Safety Guardrail:** Always checks `User Shell Folders` (`Desktop`, `Personal`, `My Pictures`) **before** touching `OneDrive`. If Known Folder Move redirected your folders into `OneDrive\`, it migrates local files and repoints Windows back to `C:\Users\<user>\Desktop`, `Documents`, and `Pictures` first.
- Includes a **Volume Shadow Copy (`vssadmin`) + `robocopy` recovery playbook** in case OneDrive folders were removed prematurely.
- Stops OneDrive, clears its `Run` entry, disables its 3 Scheduled Tasks, and sets `DisableFileSyncNGSC = 1` via Group Policy.

### 4. Startup, Bloat & Service Optimization
- Disables **Microsoft Edge** `StartupBoostEnabled` and `BackgroundModeEnabled` via Policy.
- Disables Store app auto-starts (`State = 1`) and PowerToys both in `settings.json` and Task Scheduler.
- Sets on-demand third-party services to `Manual` (or `Disabled` for services that self-revert to `Automatic`, such as `PCManager Service Store`).

### 5. Taskbar Widget Removal (Win 10 & Win 11)
- **Windows 10:** Disables News and interests via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds\EnableFeeds = 0`.
- **Windows 11:** Disables Widgets via `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0`.
- Restarts `explorer.exe` cleanly so changes take effect immediately.

### 6. Dev, Gaming, Power & Locale Checks
- Audits `HIBERNATEIDLE` AC/DC timeouts and `hiberfil.sys` / Fast Startup trade-offs via `powercfg`.
- Supports Ultimate Performance power plan activation, Developer Mode, and Windows Defender exclusions for project `Workspace` & IDE directories.
- Audits Display Language vs. Regional Format (`HKCU:\Control Panel\International`) vs. System Locale before UI language switches.

### 7. Driver Audit & Update
- Inventories signed PnP drivers (`Win32_PnPSignedDriver`) and queries Windows Update (`Microsoft.Update.Session` `Type='Driver'`).
- Cross-checks OEM vs. vendor releases, validates Authenticode signatures (`Get-AuthenticodeSignature`) before installing, handles silent install quirks (e.g., Intel Graphics DCH `-s` vs. `ExitCode 1007`), and removes temporary installers afterward.

---

## Repository Structure

```text
win-forge/
├── SKILL.md                  # Core Antigravity skill instructions & interactive workflow
├── README.md                 # Project overview, safety model & usage guide
├── future_development.md     # 9-module v2+ expansion roadmap
├── references/
│   └── playbooks.md          # Verified Win10/11 PowerShell execution playbooks
└── scripts/
    ├── audit_system.ps1      # Read-only OS, RAM, Known Folders & 5-layer startup audit
    ├── audit_disk.ps1        # Read-only junction-safe disk & cache audit
    └── audit_drivers.ps1     # Read-only signed driver & Windows Update driver check
```

---

## Installation & Usage

### In Antigravity
Place this repository in your global or workspace skills directory:
- **Global:** `~/.gemini/antigravity/skills/win-forge/`
- **Workspace:** `<repo>/.agents/skills/win-forge/`

Then ask the agent things like:
- *"Use win-forge to check what's slowing down my PC and taking up disk space."*
- *"Run win-forge to audit my startup apps and background processes."*
- *"Check my drivers with win-forge."*

### Running Audit Scripts Standalone (Read-Only)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\audit_system.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\audit_disk.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\audit_drivers.ps1
```

---

## Roadmap
See [future_development.md](./future_development.md) for the **v2+** plan expanding all **9 modules** (including **App Manager**, **System Repair** (`DISM`/`sfc`/`chkdsk`/`lodctr`), deeper **Debloat**, WSL2/Docker `vhdx` compaction, and OEM driver automation).
