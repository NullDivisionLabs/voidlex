# Bundled Geist / Geist Mono

Put `.ttf` files for the Geist family here to opt out of `google_fonts`
runtime fetching. When present, `GoogleFonts.geist(...)` and
`GoogleFonts.geistMono(...)` will resolve to these files instead of the
internet — first-launch cold-start no longer depends on a network round-trip
and works offline.

## Required files

Download from https://vercel.com/font (Geist + Geist Mono ships under
SIL Open Font License 1.1) and place under this directory exactly:

```
google_fonts/Geist-Regular.ttf
google_fonts/Geist-Medium.ttf
google_fonts/Geist-SemiBold.ttf
google_fonts/Geist-Bold.ttf
google_fonts/GeistMono-Regular.ttf
google_fonts/GeistMono-Medium.ttf
google_fonts/GeistMono-SemiBold.ttf
google_fonts/GeistMono-Bold.ttf
```

The names must match `google_fonts`'s manifest — see
https://pub.dev/packages/google_fonts#bundling-fonts-when-releasing.

The `google_fonts/` folder is already declared in `pubspec.yaml`, so Flutter
will pick the files up automatically on next `flutter pub get`.

## Why not commit the files?

The fonts are ~2 MB and licensed under SIL OFL — they're fine to redistribute,
but committing binary assets bloats the git history. CI/release pipelines
should fetch them as part of the build (e.g. `curl` from the vendor) before
running `flutter build`.
