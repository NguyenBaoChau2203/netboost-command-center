# NetBoost Mochi Cat Reference Fidelity Design

**Date:** 2026-08-13
**Status:** Approved direction; awaiting written-spec review
**Project version:** 1.0.1

## Problem

The committed Mochi Cat artwork was redrawn as a simplified flat vector. Although it retained the broad cat/network concept, it materially changed the approved reference: the soft 3D rendering, neon glow, eye details, rounded face proportions, ear circuitry, whisker nodes, collar, and lightning pendant were lost or altered.

The user has explicitly selected the supplied original image as the desired appearance. Fidelity to that file takes priority over maintaining a vector source.

## Canonical Source

The user-supplied PNG is the sole visual source of truth:

- Dimensions: 1254×1254 pixels
- Color mode: RGBA
- SHA-256: `65FB24DF0490DEF66230911CD64E50784CA5BAF95770C5F2B7E8F70E1668BBBE`
- Visual identity: soft cream 3D cat, luminous cyan/blue eyes containing network nodes, coral inner ears and cheeks, cyan/violet orbit nodes, cyan collar, glowing lightning pendant, rounded navy app tile

The canonical committed PNG must be byte-for-byte identical to this source. It must not be regenerated, repainted, color-corrected, cropped, sharpened, or passed through an image-generation model.

## Asset Strategy

### PNG

Replace `assets/brand/netboost-mochi-cat.png` with the exact supplied 1254×1254 PNG. The contract test will validate its dimensions and SHA-256 hash.

### ICO

Regenerate `assets/brand/netboost-mochi-cat.ico` exclusively from the canonical PNG. The ICO will retain the existing Windows layers: 16, 24, 32, 48, 64, 128, and 256 pixels. High-quality downsampling is permitted because Windows requires multiple icon sizes; no creative alteration is permitted.

### SVG

Remove `assets/brand/netboost-mochi-cat.svg`. An SVG wrapper containing an embedded or linked raster would falsely imply a vector source and add no fidelity. Re-vectorizing the reference would again introduce visual differences. Documentation and tests must describe the PNG as the canonical source instead.

## Shortcut Behavior

`tools/Create-NetBoostShortcut.ps1` will continue targeting `NetBoost_Command_Center.bat` and referencing `assets/brand/netboost-mochi-cat.ico`. The helper interface and launcher behavior do not change.

After the ICO replacement, recreate `NetBoost Command Center.lnk` at the repository root so its timestamp and icon metadata are refreshed. The shortcut remains machine-specific and ignored by Git. The helper must not launch the BAT file or request elevation during asset refresh.

## Tests

Update `tests/branding-assets.ps1` to:

- require the canonical PNG at 1254×1254;
- require the exact approved SHA-256 hash;
- confirm the legacy SVG is absent;
- retain the seven-layer ICO contract;
- retain all shortcut target, working-directory, icon-path, version, and invalid-destination checks.

The test must be observed failing against the current simplified asset before the PNG and ICO are replaced. It must then pass after the replacement.

Existing package-manager, cleanup-safety, PowerShell parser, frontend lint/build, backend smoke, and pnpm audit checks remain required before completion.

## Documentation

Update `README.md` and `tests/README.md` so they no longer advertise an editable vector source. They must state that the approved high-fidelity PNG is canonical and the ICO is derived from it for Windows shortcuts.

## Non-Goals

- No AI image regeneration or style reinterpretation
- No CLI or Web UI redesign
- No application favicon or Web UI logo replacement in this correction
- No change to version 1.0.1
- No launcher behavior change
- No GitHub deletion, force-push, or remote rewrite

## Acceptance Criteria

1. The committed PNG hash is exactly `65FB24DF0490DEF66230911CD64E50784CA5BAF95770C5F2B7E8F70E1668BBBE`.
2. The committed PNG is 1254×1254 RGBA and visually identical to the supplied reference.
3. The old simplified SVG no longer exists.
4. The ICO contains exactly the seven required square layers derived from the canonical PNG.
5. The recreated local shortcut still targets the existing BAT launcher and references the regenerated ICO.
6. All brand and regression checks pass while the project remains at version 1.0.1.
