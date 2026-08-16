# Collaroid Studio

Collaroid Studio is a native, offline macOS utility for preparing consistent 100 × 148 mm Dog Fest prints.

## Open and run

1. Open `CollaroidStudio.xcodeproj` in Xcode.
2. Select the **CollaroidStudio** scheme.
3. Run on **My Mac**.

The app defaults to `~/Pictures/Collaroid Dog Fest Prints`, automatically resumes at the next unused dog number, and exports 1181 × 1748 px sRGB JPEGs at 300 DPI metadata.

## Photo-folder workflow

Choose an **Opened folder** in Settings to turn it into the event photo library. Collaroid Studio scans its JPG, JPEG, and PNG files, displays them chronologically in the thumbnail browser, and can refresh the browser when new files arrive. The browser appears vertically on the left by default; **Settings → Photo Folder → Photo browser position** can switch it between **Left** and **Bottom**, and the choice is remembered. Clicking a thumbnail or using ⌘← / ⌘→ changes the active photo. **Export & Next** marks the source thumbnail as exported and advances to the next unexported photo; originals are never modified or deleted.

## Native macOS interface

The studio uses the standard macOS window toolbar, split-view photo browser, inspector, forms, buttons, control groups, system materials, and SF Symbols. The leading toolbar button shows or hides the photo browser. Native Add Photo, Print, Export, Settings, and inspector controls sit on the trailing edge, with the inspector toggle at the far right. Panel visibility choices are remembered. On macOS 26 or newer, navigation controls, the dog-number status badge, and the primary export action use Liquid Glass; earlier supported macOS versions receive native system-material and bordered-control fallbacks. The app follows the Mac's Light or Dark appearance automatically.

The inspector includes a native **Border & Branding** switch. Turn it off to preview, export, or print the photo full-bleed without the white border, logo, or event text. The preference is remembered.

The print preview supports direct editing: pinch on a trackpad or scroll the mouse wheel over the photo to zoom, then drag the photo to reposition it. The inspector zoom and reset controls remain available.

The native **Adjustments** section provides per-photo sliders for Shadows, Highlights, Saturation, and Warmth, with a one-click reset. Adjustments are retained while moving between photos during the session and are applied identically to the preview, exported JPEG, and printed output.

## Renderer smoke test

`Tools/RenderSmokeTest.swift` can be compiled with the renderer sources to verify a real source image produces a 1181 × 1748 JPEG with 300 DPI metadata. Its optional iteration argument supports repeated-use stress testing.

## Official logo

The supplied official Collaroid wordmark is stored with its grey background removed at:

`CollaroidStudio/Assets.xcassets/CollaroidLogo.imageset/collaroid-logo.png`

The lettering, proportions, colours, and orange dot are preserved; only the neutral background pixels were converted to transparency. The logo remains locked in the print template.

## Collaroid Studio identity

The selected Option 3 identity is integrated into the macOS app icon. Only the production assets required by the app are kept in the source tree; concept artwork and duplicate design exports are intentionally excluded.

## Event shortcuts

- ⌘O — add photo
- Return — export and reset
- ⌘P — print current composition
- ⌘← / ⌘→ — previous or next folder photo
- + / − — zoom
- R — reset crop
