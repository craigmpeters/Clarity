# iPhone Duo screenshots

## Ready to upload

- `outer/upload/`: one branded outer-display task image at 1398 × 2034.
- `inner/upload/`: three branded inner-display images at 2853 × 2007 (landscape): tasks, habits and statistics.

All files use the supplied Clarity logo and the established screenshot colour palette. They are RGB PNGs, with an embedded sRGB profile and no alpha. The app screens are actual Duo simulator captures using Clarity's existing in-memory demo-data launch mode, not resized standard-iPhone screenshots.

`raw/inner-tasks.png`, `raw/inner-habits.png`, and `raw/inner-stats.png` are the successful inner captures. `raw/inner-check.png` is an earlier failed diagnostic and must not be uploaded. Editable layouts are in each display's `editable/` folder. Preview images are for review, not upload.

## Successful retry

The inner display was captured on 1 November 2026 after closing duplicate Device Hub instances, booting a single simulator, recovering its system interface after a display-mode crash, and explicitly resetting display 3 to native 2007 × 2853 at scale 3. The device was unfolded in landscape, and Clarity was opened from its Home Screen after the system recovered. The visible app was verified before each capture.

No application source changed. No assets uploaded. Regenerate with `../render-devices.cjs`, using the dependencies from the earlier screenshot set.

Apple specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
