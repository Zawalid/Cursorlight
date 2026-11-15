# Releasing Cursorlight

The flow and its lessons come from the `mac-app-shipping` skill. Distribution is a DMG on GitHub Releases with
Sparkle updates. There is no Homebrew cask.

## One-time setup (owner, secrets stay out of the repo)
1. Create the GitHub repository `Zawalid/Cursorlight` and push a clean history (the working repository carries large old
   audit screenshots, so publish from a fresh repository).
2. Make the signing certificate: `scripts/make-signing-cert.sh`, then set the three secrets it prints.
3. Make the Sparkle key pair (`generate_keys --account cursorlight`), put the public key in `App/project.yml`
   (`SUPublicEDKey`), set `SPARKLE_ED_PRIVATE_KEY`, and keep an offline backup. Losing the key strands every install.
4. For the website, set `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` (see `website/README.md`).

## Each release
1. Write the changes under `## [Unreleased]` in `CHANGELOG.md`.
2. `scripts/release.sh X.Y.Z --dry-run`, then `scripts/release.sh X.Y.Z` (tests, notes, version bump, commit, tag; it never pushes).
3. `git push origin main --follow-tags`. The tag starts `release.yml`, which waits for a green CI run on the same commit,
   builds a universal binary, signs it, packs the DMG, writes the checksum and builds the update feed.
4. The workflow makes a **draft** release. Try the DMG on a clean account (first launch, permissions, update check).
5. Publish: `gh release edit vX.Y.Z --draft=false`.

Release assets: `Cursorlight-X.Y.Z.dmg`, its `.sha256`, a fixed-name copy `Cursorlight.dmg` (so
`releases/latest/download/Cursorlight.dmg` always works) and `appcast.xml`.

## Local build and checks
- `scripts/build-app.sh` builds `build/Cursorlight.app` (universal, hardened runtime, ad hoc signed unless `SIGN_IDENTITY` is set).
- `scripts/make-dmg.sh` makes `build/Cursorlight.dmg`.
- `scripts/capture-shots.sh` captures the product screenshots in `docs/images/` from isolated agent-mode copies of the app.
- `scripts/gen-icon.swift` regenerates the app icon.

## Not verified yet
- The workflows have never run. Notarization has never run (no Developer ID account), so users confirm the first launch.
- The DMG window layout has not been looked at in Finder under the new name.
- The signed update keeping the Input Monitoring grant on a real user Mac.
- The sharing checklist on a real call (`docs/SHARING-CHECKLIST.md`).
