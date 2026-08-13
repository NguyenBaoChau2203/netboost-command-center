# NetBoost Cleanup Overhaul Design

**Date:** 2026-08-13  
**Status:** Approved  
**Version constraint:** Keep the product version at `1.0.1`.

## Scope

This change removes the product feature that scans npm projects and recommends npm-to-pnpm migration. It does not replace the frontend development toolchain: `npm run lint` and `npm run build` remain supported developer commands.

The existing PowerShell and Web UI visual design stays unchanged. Cleanup receives functional and safety improvements only.

## npm-to-pnpm removal

Remove the feature from every product surface:

- Web navigation, dashboard teaser, view component, API client methods, mock data, types, and translations.
- Local PowerShell backend route, worker functions, background-function bootstrap, and job state.
- PowerShell CLI menu entry, help/argument aliases, dashboard runtime package-manager card, scanner functions, icons, and translations.
- Smoke tests, product documentation, API contract, and active specification artifacts.

Historical release notes and historical implementation plans may retain npm command names when they describe how v1.0.1 was built. Current product documentation must not advertise the removed scanner.

## Cleanup policy

### Modes

- **Safe:** use conservative retention. User Temp and Windows Temp delete only files older than 24 hours.
- **Deep:** use the selected targets with an explicit confirmation. Temp retention may be reduced to one hour. Deep-only targets are rejected unless `deep=true`.

### Target changes

- Keep `user-temp` and `windows-temp` as separate visible targets.
- Keep `component-store`, implemented only through `dism.exe /Online /Cleanup-Image /StartComponentCleanup`, as the cleanup for superseded Windows components.
- Add `windows-update-downloads` as a separate high-risk, confirmation-required, deep-only target for `C:\Windows\SoftwareDistribution\Download`. It is never selected by default. The action records the original states of `wuauserv` and `BITS`, stops only services that are running, deletes only the contents of the `Download` directory through the canonical filesystem guard, and restores only the services that were running before the action. A service-stop failure aborts deletion, and restoration runs from `finally` even if cleanup fails.
- Add `delivery-optimization`, implemented through `Delete-DeliveryOptimizationCache -Force` without `-IncludePinnedFiles`.
- Keep `windows-prefetch` visible, off by default, confirmation-required, and deep-only. Only `*.pf` files older than 30 days are eligible; `ReadyBoot` and `Layout.ini` are never targeted.
- Keep Recycle Bin as a special action rather than a raw filesystem target.

### Filesystem safety

- Reject empty paths, drive roots, profile roots, and Windows roots as cleanup roots.
- Resolve canonical paths before enumeration.
- Never delete the cleanup root itself.
- Skip reparse points and candidates that escape the canonical cleanup root.
- Skip locked/access-denied files and report them separately from unexpected failures.
- Apply age and include-pattern policy consistently to estimation and deletion.

### Estimates

Filesystem estimates are bounded so the targets endpoint stays responsive. Each target reports whether its estimate is complete and how many eligible files were sampled. Special Windows-managed actions report an unavailable estimate instead of pretending the size is zero and exact.

## User experience

The current UI layout remains. Target rows gain only the metadata necessary to communicate partial/system estimates and deep-only status. Default selection remains based on `requiresConfirmation=false`, so Prefetch, Component Store, and Windows Update Downloads are never selected automatically. The target count becomes 15.

## Official sources

- Storage Sense guidance for temporary files and Recycle Bin: https://support.microsoft.com/en-US/Windows/Experience/Storage-FileManagement/manage-drive-space-with-storage-sense
- Component Store cleanup and the warning against raw WinSxS deletion: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder?view=windows-11
- Delivery Optimization cache cmdlet: https://learn.microsoft.com/en-us/powershell/module/deliveryoptimization/delete-deliveryoptimizationcache?view=windowsserver2025-ps
- Windows startup prefetch behavior: https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/improving-system-startup-performance
- Windows Update cache troubleshooting sequence (stop service, clear `SoftwareDistribution`, restart service): https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/troubleshoot-problems-updating-windows

## Verification

- Observe failing regression checks before changing production code.
- Run backend smoke tests and cleanup policy tests.
- Verify service-state planning and guaranteed restoration with test doubles; automated tests must not stop real Windows services or delete the real update cache.
- Run PowerShell parser checks for both scripts.
- Run React/TypeScript lint and production build.
- Search tracked current product surfaces for removed npm-to-pnpm symbols.
- Re-index CodeGraph and inspect the final diff before committing.
