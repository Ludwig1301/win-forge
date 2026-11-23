---
name: win-forge
description: >-
  Interactive Windows 10 and Windows 11 system audit, disk cleanup, startup/process
  de-bloating, OneDrive removal, dev/gaming tuning, and driver update workflow.
  Use when the user asks to clean up, speed up, audit disk space, inspect Task
  Manager/startup bloat, disable OneDrive safely, or check/update drivers on Windows.
---

# Win-Forge (v1)

An interactive, step-by-step Windows 10 & Windows 11 optimization and cleanup skill.

## Core Execution Rules (Interactive & One-by-One)

1. **Never modify anything during initial discovery.** Always run read-only audits first.
2. **Present concise findings first.** Group results clearly (sizes in GB/MB, RAM/process counts, startup vectors, driver status) and offer numbered options.
3. **Wait for user selection.** Let the user choose which numbered items to run.
4. **Execute one by one with verification.** Run **one approved task at a time**, verify its result (exit code, free space delta, registry/service/process state), report the outcome briefly, then proceed to the next item.
5. **Handle elevation cleanly.** Check if the shell is elevated (`IsAdmin`). Run user-scoped actions directly; wrap `HKLM`, `Service`, `cleanmgr`, `powercfg`, or driver installs in an elevated script (`Start-Process powershell -Verb RunAs -Wait`) that logs to a transcript so output is captured.

---

## Phase 1: Read-Only Discovery

Run the relevant read-only audit script(s) based on the user's goal:

- **System, Processes, Startups & Known Folders:** [audit_system.ps1](./scripts/audit_system.ps1)
- **Disk Space & Caches (Junction-Safe):** [audit_disk.ps1](./scripts/audit_disk.ps1)
- **Installed Drivers & Windows Update Drivers:** [audit_drivers.ps1](./scripts/audit_drivers.ps1)

Before recommending any action, verify the OS version (`Build >= 22000` = Windows 11, `< 22000` = Windows 10) and flag any safety risks (e.g., OneDrive Known Folder Move active, or Windows Update actively locking `SoftwareDistribution\Download`).

---

## Phase 2 & 3: Action Modules (Execute One by One)

Use the exact verified commands and OS-specific branches in [playbooks.md](./references/playbooks.md) for each approved item:

1. **Disk & Cache Cleanup**
   - Clear User `Temp` (skip locked files), `CrashDumps`, `.nuget\packages`, Chrome/Edge `Cache` folders only (never cookies/logins), and Recycle Bin.
   - Enable **Storage Sense** (`StoragePolicy\01 = 1`).
   - Check `UsoSvc` / recent timestamps before touching `C:\Windows\SoftwareDistribution\Download`; if locked by an active Windows Update download, skip and advise cleaning after restart.
   - Clean `C:\Windows.old`, `Update Cleanup`, and `Temporary Setup Files` safely via `cleanmgr.exe /sagerun:99` (`VolumeCaches` `StateFlags0099 = 2`).
   - Move large folders/games from `C:` to a secondary drive (`D:`) via `robocopy` + directory junction (`mklink /J`) when requested.

2. **OneDrive Full Disable (Known-Folder-Safe)**
   - **MANDATORY PRE-CHECK:** Inspect `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` (`Desktop`, `Personal`, `My Pictures`) **before** deleting `OneDrive`.
   - If redirected into `OneDrive\`, migrate local files out and repoint both `User Shell Folders` and `Shell Folders` to local paths (`C:\Users\<user>\Desktop`, `Documents`, `Pictures`) **first**.
   - Stop `OneDrive`, remove its `HKCU\...\Run` entry, disable its 3 Scheduled Tasks, and set `HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive\DisableFileSyncNGSC = 1`.
   - *(Emergency recovery reference in `playbooks.md`: VSS `vssadmin` + `mklink /d` + `robocopy`.)*

3. **Startup, Background Process & Service Optimization**
   - Audit all 5 layers: `HKCU/HKLM\...\Run`, Startup folders, Store `AppModel\SystemAppData` (`State = 1` disables), Scheduled Tasks (e.g., `\PowerToys\Autorun for <user>`), and Services.
   - Disable Edge `StartupBoostEnabled` & `BackgroundModeEnabled` via `HKLM:\SOFTWARE\Policies\Microsoft\Edge`.
   - Set on-demand third-party services to `Manual` (or `Disabled` if they self-revert to `Automatic` on reboot, such as `PCManager Service Store`).

4. **Taskbar & UI Cleanup (Win 10 vs. Win 11)**
   - **Windows 10** (`Build < 22000`): Set `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds\EnableFeeds = 0` (News and interests / weather widget).
   - **Windows 11** (`Build >= 22000`): Set `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0` (Widgets).
   - Restart `explorer.exe` to apply immediately.

5. **Dev, Gaming, Power & Locale Checks**
   - **Power & Hibernation:** Check `powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE` (AC vs. DC timeouts) and `hiberfil.sys` / Fast Startup trade-offs; activate Ultimate Performance (`powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61`) if requested.
   - **Dev & Gaming:** Add Windows Defender exclusions for project `Workspace` and IDE paths; enable Developer Mode; check external display GPU routing when gaming.
   - **Language & Locale Safety:** Audit `WinSystemLocale`, `WinUserLanguageList`, and `HKCU:\Control Panel\International` (`LocaleName`) before Display Language changes so Regional Format (`d.MM.yyyy`, `,` decimal) and non-Unicode apps don't unexpectedly change.

6. **Driver Audit & Update**
   - Compare `Win32_PnPSignedDriver` versions and `Microsoft.Update.Session` (`IsInstalled=0 and Type='Driver'`) against OEM/vendor releases.
   - Verify `Get-AuthenticodeSignature` (`Status -eq 'Valid'`) on any downloaded installer before running.
   - For Intel Graphics DCH packages (`gfx_win_101*.exe`), use `-s` only (extra flags like `--overwrite`/`--report` can fail with `ExitCode 1007` / `ERROR_BAD_COMMAND`). Delete temporary installers after verification.
