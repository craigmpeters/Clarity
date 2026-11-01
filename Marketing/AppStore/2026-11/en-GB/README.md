# Clarity App Store screenshots — English (UK)

Six portrait slides, in upload order. `upload/` contains the final **1320 × 2868 RGB PNGs** for the iPhone 6.9-inch screenshot slot. `contact-sheet.png` previews the full sequence; do not upload the contact sheet.

1. **Make room for what matters.** — Tasks, habits and focus together.
2. **Small steps. Stronger habits.** — Daily goals and the rolling seven-day view.
3. **Find your focus. Keep it simple.** — An active Pomodoro linked to a task.
4. **See how far you’ve come.** — Completed tasks, focus time and patterns.
5. **Your life. Your categories.** — Colours and weekly targets.
6. **All functionality. Free.** — Premium is purely cosmetic and entirely optional.

## Sources and editing

`raw/` contains unaltered captures from the local app running on an iPhone 16 Pro Max simulator (iOS 18.3.1), using the app's existing in-memory UI-testing data. The status bar was set to 9:41. All task and habit content is demo data. Slide 6 reuses the task capture and the app's Premium icon asset. Frames, typography and backgrounds are presentation artwork; the app UI is not redrawn.

`editable/` contains standalone SVG layouts with embedded screenshots. Text and colours remain editable. `copy.json` records the slide copy and palette. `render.cjs` is the source used to generate both SVGs and PNGs; edit its slide definitions to rebuild the full set.

From this directory:

```sh
npm install --prefix /tmp/clarity-marketing-render @resvg/resvg-js sharp
NODE_PATH=/tmp/clarity-marketing-render/node_modules node render.cjs
```

The renderer removes alpha channels. All six exports were checked for exact dimensions, RGB format, and visually reviewed together. No application source was changed. These files are prepared locally and have not been uploaded to App Store Connect.

Apple's screenshot specification: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

This delivery is an iPhone set; it does not include separate iPad or Apple Watch screenshot sets.

## Logo revision

All artwork now includes the user-supplied blue-and-yellow Clarity logo, embedded from `raw/clarity-logo.png` (relative to the screenshot directory). The transparent source is preserved; a white rounded tile keeps the mark visible on every background. Editable SVGs, previews and upload archives have been regenerated.
