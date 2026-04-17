# YajerTex Dev Camera

A premium Flutter camera app that captures photos with a **GPS coordinate overlay** burned into every image. Light-blue / white theme, glassmorphism accents, smooth micro-animations.

## Feature checklist

| Area | Delivered |
|------|-----------|
| Splash screen | Animated logo + brand title, 2.4 s auto-route |
| Name input | Validated field, persisted with `shared_preferences` |
| Dashboard | Grid of captures, per-photo date/time, geo-indicator, FAB |
| Camera | Live preview, **front-first default**, front/back toggle |
| Capture | Shutter animation + haptic flash, async GPS fetch |
| Overlay | Lat/lon/timestamp/name stamped bottom-left on every photo |
| Preview | Rotate L/R, Retake, Save |
| Storage | Bytes in app documents dir, metadata in `SharedPreferences` |
| Permissions | Camera + location requested + settings deep-link on denial |
| Error states | GPS off, camera unavailable, permission denied |

## Folder layout

```
lib/
├── main.dart                       app entry + theme wiring
├── theme/app_theme.dart            palette, gradients, ThemeData
├── models/photo_model.dart         serialisable photo metadata
├── services/
│   ├── storage_service.dart        user name + photo index + paths
│   ├── location_service.dart       GPS with typed error results
│   ├── permissions_service.dart    runtime permission requests
│   └── image_processor.dart        GPS overlay stamp + rotate-in-place
├── widgets/
│   ├── app_logo.dart               aperture-style brand mark
│   ├── primary_button.dart         gradient CTA w/ loading state
│   └── glass_card.dart             frosted-glass container
└── screens/
    ├── splash_screen.dart
    ├── name_input_screen.dart
    ├── dashboard_screen.dart
    ├── camera_screen.dart
    ├── preview_screen.dart
    └── photo_detail_screen.dart
```

## Run it

Prereqs: Flutter **3.19+**, a physical Android/iOS device (camera + GPS are not reliable on emulators).

```bash
# 1. Fetch packages
flutter pub get

# 2. Run on a connected device
flutter run
```

### Android notes
- Min SDK 24, target SDK 34.
- Permissions are declared in `android/app/src/main/AndroidManifest.xml`:
  `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, media read/write.

### iOS notes
- `ios/Runner/Info.plist` declares:
  `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSMicrophoneUsageDescription`.
- Run `cd ios && pod install` after `flutter pub get` the first time.

## How the GPS overlay works

`ImageProcessor.stampGeoOverlay` (in [lib/services/image_processor.dart](lib/services/image_processor.dart)) decodes the JPEG returned by the camera plugin, draws a translucent panel with a blue accent bar in the bottom-left, and writes four lines:

1. `YajerTex Dev Camera`
2. `Lat: <6-decimal>`
3. `Lon: <6-decimal>`
4. `YYYY-MM-DD HH:mm  •  <user name>`

Text is rendered with a 1-pixel shadow for legibility on any background. Front-camera frames are automatically un-mirrored before the overlay is applied.

## Error handling

- **GPS off** → capture still succeeds; a snackbar tells the user, and the overlay reads `Lat: —` / `Lon: —`.
- **Camera permission denied** → full-screen error with *Retry* and *Open Settings* actions.
- **Location permission permanently denied** → snackbar points to system settings.
- **Broken image files** on disk are auto-evicted from the gallery index on next load.

## Quality pass checklist

- `flutter analyze` — 0 issues expected.
- Manual: splash → name → dashboard → camera → capture → preview → save → dashboard shows the new photo at the top.
- Verify the overlay is visible and correctly oriented for both front and back captures.
