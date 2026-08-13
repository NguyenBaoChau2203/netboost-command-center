# NetBoost Mochi Cat Logo Design

## Status

Approved concept: the cute NetBoost Mochi Cat preview shown in the Codex task on 2026-08-13.

## Objective

Give NetBoost Command Center a recognizable, friendly Windows launcher identity without changing the existing CLI or Web UI layout. The mark must remain legible as a 16×16 Windows icon and retain the approved cute technology-cat character at larger sizes.

## Brand mark

The primary mark is a centered, front-facing cream-white cat head on a deep navy rounded-square field. The cat has a soft mochi-like silhouette, small triangular ears, a tiny smile, subtle coral-pink cheeks, and cyan eyes that suggest network nodes. A small cyan lightning pendant represents speed and optimization. Cyan and soft violet node/connection accents may appear around the face, but the final icon uses fewer details than the preview so its silhouette remains clear at small sizes.

The mark contains no words, initials, shield, antivirus imagery, headset, laptop, realistic fur, or full cat body. Its tone is approximately 60% cute and 40% technology: friendly and memorable without looking childish.

## Color system

- Deep navy background: approximately `#071B4A`.
- Warm cream-white cat: approximately `#FFF8E8`.
- Network cyan: approximately `#00D9FF`.
- Soft violet accent: approximately `#8B63FF`.
- Muted coral-pink cheeks and inner ears: approximately `#FF8F9C`.
- Dark facial strokes: approximately `#0B1B55`.

Minor adjustments are allowed for contrast, but the palette must preserve the approved preview's appearance.

## Deliverables

- `assets/brand/netboost-mochi-cat.svg`: deterministic vector master with clean geometric paths.
- `assets/brand/netboost-mochi-cat.png`: 1024×1024 preview/export.
- `assets/brand/netboost-mochi-cat.ico`: multi-resolution Windows icon containing 16, 24, 32, 48, 64, 128, and 256 pixel layers.
- `tools/Create-NetBoostShortcut.ps1`: portable helper that resolves the repository path and creates a Windows shortcut targeting `NetBoost_Command_Center.bat` with the Mochi Cat `.ico` file.
- A generated local `NetBoost Command Center.lnk` for the current workspace so the user can launch the existing BAT workflow through the branded icon immediately.

The machine-specific `.lnk` file is not committed because Windows shortcuts contain absolute paths. The SVG, PNG, ICO, and shortcut-generation helper are committed.

## Launcher behavior

Windows does not support embedding a custom icon directly in a `.bat` file. The BAT remains the canonical launcher and is not converted into an executable. The branded `.lnk` points to the existing BAT, uses the repository root as its working directory, and uses the committed ICO as `IconLocation`. This preserves UAC elevation, CLI arguments in the BAT, and all existing behavior.

If the project moves to another directory, rerunning `tools/Create-NetBoostShortcut.ps1` recreates the shortcut with the new absolute paths.

## Small-size simplification

At 16 and 24 pixels, the icon keeps only the navy rounded square, cream cat silhouette, dark eyes/mouth, cyan eye or whisker accents, and lightning pendant. Tiny network diagrams inside the eyes and secondary orbit dots from the preview are removed or merged. Larger ICO layers and the PNG may retain a few extra node accents.

## Scope boundaries

- No change to the current PowerShell/CLI visual interface.
- No replacement of `NetBoost_Command_Center.bat` with an EXE.
- No installer, code-signing pipeline, splash screen, or unrelated brand redesign.
- No Web UI logo replacement in this increment; the assets remain reusable for that later.

## Verification

- Render the SVG and inspect it at full size.
- Inspect raster exports at 1024, 256, 48, 32, and 16 pixels.
- Verify the ICO contains every required resolution.
- Create the local shortcut and confirm its target, working directory, and icon location.
- Launch through the shortcut and verify it reaches the same NetBoost BAT entrypoint.
- Run existing PowerShell parser, cleanup-safety, and backend smoke tests to prove branding work did not alter application behavior.
