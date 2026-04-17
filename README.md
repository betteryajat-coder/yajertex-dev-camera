# YajatXDev Geo

A premium Flutter camera app that stamps a clean geo-tag badge into every photo. Light-blue / white theme, glassmorphism accents, smooth micro-animations.

## Overlay format (bottom-left of each image)

```
Green Valley Society          ← society / area name (editable)
Lat: 23.022500
Lng: 72.571400
17 Apr 2026, 5:42 PM
```

No app name. No user name. Just the four things you actually want on the photo.

## Feature highlights

- **Splash → name input → dashboard → camera → preview** navigation with animated transitions
- **Front-first camera** with a robust flip implementation (dispose-then-init pattern, no black-screen bug)
- **Reverse-geocoded society name** pre-filled on the preview screen; user can edit before saving
- **Per-photo metadata**: latitude, longitude, timestamp, society, user name (stored locally via `shared_preferences`)
- **GPS off / camera denied / location denied** all produce clear, actionable error states
- **Custom launcher icon + app label** — shows up as "YajatXDev Geo" on the home screen

## Folder layout

```
assets/icon/icon.svg                 brand mark (rasterized to PNG on CI)
lib/
├── main.dart                        app entry + theme
├── theme/app_theme.dart             palette, gradients, ThemeData
├── models/photo_model.dart          serialisable photo metadata (incl. societyName)
├── services/
│   ├── storage_service.dart         user name + photo index + paths
│   ├── location_service.dart        GPS + reverse geocoding
│   ├── permissions_service.dart     runtime permission requests
│   └── image_processor.dart         overlay stamp + rotate-in-place
├── widgets/
│   ├── app_logo.dart                SVG-backed brand mark
│   ├── primary_button.dart          gradient CTA w/ loading state
│   └── glass_card.dart              frosted container
└── screens/
    ├── splash_screen.dart
    ├── name_input_screen.dart
    ├── dashboard_screen.dart
    ├── camera_screen.dart
    ├── preview_screen.dart          editable society-name field lives here
    └── photo_detail_screen.dart
android-patches/                     Android overlays applied after `flutter create` on CI
.github/workflows/build-apk.yml      cloud build → downloadable APK artifact
```

## Run locally

Prereqs: Flutter **3.22**, a physical Android/iOS device (camera + GPS are unreliable on emulators).

```bash
flutter pub get
dart run flutter_launcher_icons   # optional: regenerates app icon
flutter run
```

### Android permissions
Declared in `android-patches/AndroidManifest.xml` (applied to the scaffolded `android/` on CI):
`CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, media read/write.

## Cloud build (recommended)

Every push to `main` runs `.github/workflows/build-apk.yml`:

1. Rasterizes `assets/icon/icon.svg` to a 1024×1024 PNG (rsvg-convert).
2. Scaffolds `android/` via `flutter create`.
3. Overlays the custom `AndroidManifest.xml`.
4. Bumps Kotlin to 1.9.22 (plugin compatibility).
5. `flutter_launcher_icons` generates the mipmap assets.
6. `flutter build apk --release` builds the APK.
7. Uploads as the `yajatxdev-geo-release` artifact.

Download the APK from the Actions tab → latest successful run → artifact → unzip → install.

## Camera flip — how the bug is avoided

The canonical failure mode on Android is: new controller is built and `_controller = newController` happens **before** the old one is fully released, so `CameraPreview` can paint a disposed controller mid-swap. [camera_screen.dart](lib/screens/camera_screen.dart) uses a dispose-first pattern:

1. `setState(() { _controller = null; _initializing = true; })` — UI drops the preview.
2. `await old.dispose()` — wait for the platform to release.
3. `await Future.delayed(180ms)` — camera HAL breathing room.
4. Build the new `CameraController`, `initialize()`, `setFlashMode()`.
5. `setState(() { _controller = newController; _initializing = false; })` — swap in.

The flip also prefers front↔back toggling rather than round-robin indexing, so devices with 3+ sensors still behave predictably.
