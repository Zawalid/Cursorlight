# Contributing to Cursorlight

Thanks for helping. Cursorlight sits on top of everything people show on their screen, so the bar for changes that touch
input, overlays or permissions is high, and the bar for everything else is just "clear and tested".

## Set up

```bash
brew install xcodegen
cd App && xcodegen generate && open Cursorlight.xcodeproj
```

`App/Cursorlight.xcodeproj` is generated from `App/project.yml` and is not committed. Run `xcodegen generate` again
after adding or removing files. `scripts/dev.sh` builds a Debug app, relaunches it and (with `--watch`) rebuilds on save.

## Before you open a pull request

1. Run the core tests: `swift test`. The logic lives in the `CursorlightCore` package and is unit tested; views stay thin.
2. Add a test with the change.
3. For anything visual, run the app in agent mode so your own settings are not touched, and look at it:
   `CURSORLIGHT_AGENT=1 CURSORLIGHT_DEMO=1 CURSORLIGHT_DEFAULTS=scratch CURSORLIGHT_OPEN=settings:highlight` followed by the app path.
4. Anything that needs the real desktop (several displays, Stage Manager, real conferencing apps) should say what you
   did and did not check. `docs/SHARING-CHECKLIST.md` lists what to try on a real call.

## Rules

- No Accessibility or Screen Recording permission unless a feature truly needs it, and then it stays optional.
- Private macOS API only behind a protocol with a public fallback, in `Sources/CursorlightCore/Private`.
- No force casts, no force unwraps in production code, no `as any` style escapes.
- User-facing text is plain and specific. No marketing words, no emoji, no em dashes.
- Commit messages: `type: lowercase subject`, for example `fix: keep the laser trail inside the active display`.
- All branding (name, colors, copy) lives in `Sources/CursorlightCore/Branding.swift` and the asset catalog.

## Reporting bugs

Open an issue with your macOS version, the Cursorlight version, which conferencing app you were sharing with (if any),
and what you expected. **About, Copy diagnostics** puts a report on your clipboard; nothing is sent anywhere. For
security problems see [SECURITY.md](SECURITY.md).
