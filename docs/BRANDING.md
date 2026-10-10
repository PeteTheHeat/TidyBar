# TidyBar icon

The app icon was generated with the built-in imagegen tool. The selected original is `Resources/AppIcon.png`, a 1024 × 1024 PNG with transparency. `scripts/icon.sh` converts it into standard macOS icon sizes and builds `build/AppIcon.icns`. The app uses the icon in its bundle and settings sidebar; its menu bar control keeps a monochrome system symbol.

## Generation prompt

```text
Use case: logo-brand
Asset type: native macOS application icon for TidyBar, a minimal menu bar organizer.
Primary request: a beautiful, simple icon that reads clearly at small sizes. One rounded square macOS-style tile with a softly luminous cobalt-to-periwinkle blue surface. Center a crisp white abstract symbol: three horizontal rounded bars, the top longest, the middle shorter, and the bottom shortest, balanced and spaced generously, suggesting a tidy, filtered menu bar.
Style/medium: polished restrained macOS icon, clean geometry, subtle depth, gentle edge highlight. Minimalistic, elegant, no clutter.
Composition/framing: square 1024x1024 asset, rounded tile centered with consistent transparent margin, straight-on view.
Constraints: genuine transparent pixels outside the rounded tile. No letters, text, branding from other apps, watermark, mockup, extra objects, or background scene. Keep the white mark bold enough to remain legible at 32 pixels.
```

The README screenshots use the production SwiftUI settings view with sample items. They are exported by `--export-screenshots`; they are not generated UI illustrations.
