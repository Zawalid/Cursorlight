# Releasing Cursorlight

Everything below is prepared and local-tested (release build, universal binary, DMG). Nothing has been pushed, signed
with a stable identity, or published. The flow and its lessons come from the `mac-app-shipping` skill.

## Placeholders that change when the name is decided
The name "Cursorlight", the bundle id `app.cursorlight.mac`, the repo `Zawalid/Cursorlight`, the domain `cursorlight.example.com` and the
cask text are placeholders. To rename: search and replace them in `App/project.yml`, `scripts/`, `.github/workflows/`,
`packaging/homebrew/cursorlight.rb`, `Sources/CursorlightCore/Branding.swift`, then regenerate the icon (`scripts/gen-icon.swift`)
and the DMG art (`scripts/dmg/background.html`).

## Done
- Release build: `scripts/build-app.sh` (universal, hardened runtime, ad hoc signed unless `SIGN_IDENTITY` is set).
- DMG: `scripts/make-dmg.sh` (dark installer window with the placeholder art).
- Sparkle wired and inert: `AppUpdater` never starts while `SUPublicEDKey` starts with `REPLACE`. About has the toggle.
- Release scripts, CI and release workflows, Homebrew cask template, changelog, placeholder app icon.

## Needs the owner (outward-facing or secret, so not done here)
1. Decide the name, icon and domain (see the placeholders above).
2. Create the GitHub repository and push (`git remote add origin ...`).
3. Make the signing certificate: `scripts/make-signing-cert.sh`, then set the three secrets it prints.
4. Make the Sparkle key pair (`generate_keys --account cursorlight`), put the public key in `App/project.yml`
   (`SUPublicEDKey`), set `SPARKLE_ED_PRIVATE_KEY`, keep an offline backup.
5. Trial run of the Release workflow by hand, then `scripts/release.sh 0.1.0`, push the tag, try the draft DMG on a
   clean account, publish, create the tap and cask (`scripts/cask.sh`).
6. Decide pricing and licensing. v1 has no licensing code on purpose.
7. Product site (not started).

## Not verified
- The workflows have never run. Notarization has never run (no Developer ID account).
- The DMG window layout has not been looked at in Finder.
- The signed update keeping the Input Monitoring grant on a real user Mac.
