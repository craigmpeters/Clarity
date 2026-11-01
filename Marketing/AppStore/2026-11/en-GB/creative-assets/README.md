# Clarity — header and search results creative assets

## Upload choices

Use either the two placement-specific files, or the universal file for both placements:

| File in `upload/` | Placement | Dimensions |
| --- | --- | --- |
| clarity-header-3840x1646.png | Product page header | 3840 × 1646 |
| clarity-search-results-3840x2560.png | Search results | 3840 × 2560 |
| clarity-universal-5244x2950.png | Universal alternative for header and search results | 5244 × 2950 |

The cobalt header matches the opening screenshot. The mint search artwork matches the habits slide and makes the task/habit/focus purpose explicit. The universal option uses the same cobalt design language.

All exports are RGB PNGs with an embedded sRGB profile and no alpha channel. These are local artwork files; they have not been uploaded or submitted to Apple.

## Artwork and crop checks

Actual UI details are taken from the earlier local demo-data captures in `../raw/`. These are cropped details, not newly invented interfaces. Decorative curves, framing and type are editable vector artwork.

Apple's Photoshop templates were inspected on 1 November 2026. Their Art Safe Area layer bounds are recorded here as x, y, width, height:

- Header: 1097, 493, 1646, 661.
- Search results: 836, 765, 2168, 1030.
- Universal: 1921, 660, 1402, 962.

The main phrase, wordmark and principal task detail sit within those focal regions. Secondary UI cards and background shapes extend beyond them and may crop. `previews/` includes focal-area crops and safe-area outlines for review. Preview images and SVGs are not for upload. Check the final artwork with App Store Connect's placement Preview tool before submission, as its device and orientation previews are authoritative.

No pricing claims, Premium offers, web addresses or Apple award badges appear in the artwork.

## Edit and regenerate

`editable/` contains standalone SVGs with embedded UI images. `render.cjs` generates the layouts, PNGs and previews. From this directory:

```sh
npm install --prefix /tmp/clarity-marketing-render @resvg/resvg-js sharp
NODE_PATH=/tmp/clarity-marketing-render/node_modules node render.cjs
```

No application source changed.

## Apple references

- https://developer.apple.com/app-store/asset-best-practices/
- https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- Header template: https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-product_page_header_template-static.psd
- Search template: https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-search_results_template-static.psd
- Universal template: https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-universal_asset_template-static.psd

## Logo revision

All artwork now includes the user-supplied blue-and-yellow Clarity logo, embedded from `raw/clarity-logo.png` (relative to the screenshot directory). The transparent source is preserved; a white rounded tile keeps the mark visible on every background. Editable SVGs, previews and upload archives have been regenerated.
