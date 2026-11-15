# Installing Cursorlight

Cursorlight needs **macOS 14.6 or later**. It runs on Apple silicon and Intel.

## Download (recommended)

1. Open the [latest release](https://github.com/Zawalid/Cursorlight/releases/latest) and download `Cursorlight-<version>.dmg`.
2. Open the DMG and drag **Cursorlight** onto **Applications**.
3. Open Cursorlight from Applications. The first launch needs one extra step, see [the first launch](#the-first-launch).

You can check the download against the `Cursorlight-<version>.dmg.sha256` file on the same page:

```bash
shasum -a 256 -c Cursorlight-0.1.0.dmg.sha256
```

## The first launch

Cursorlight is not signed with an Apple Developer ID, so macOS blocks it the first time ("Apple could not verify
Cursorlight is free of malware"). You confirm it once and it never asks again:

1. Open Cursorlight from Applications. When the warning appears, click **Done**. Do not choose Move to Trash.
2. Open **System Settings**, then **Privacy & Security**, and scroll down to the Security section. It says Cursorlight
   was blocked. Click **Open Anyway**, confirm with your password or Touch ID, then **Open**.

On macOS 15 (Sequoia) and later this is the only way in; right-click, Open no longer works there. On macOS 14 you can
also right-click Cursorlight in Applications, choose **Open**, then **Open** again.

Prefer the Terminal? One line removes the quarantine flag and skips the warning:

```bash
xattr -dr com.apple.quarantine /Applications/Cursorlight.app
```

Cursorlight is open source, so you can also read exactly what it does or build it yourself.

## What it asks for

Nothing, to start. Cursorlight works without Accessibility or Screen Recording access.

One optional permission: **Input Monitoring**. It lets Cursorlight see a key you double-tap and hold, the keystroke
display, and the "hide while typing" option while another app is in front. The welcome guide and **Settings, Keys** explain
it, and everything else works without it. Cursorlight never sees password fields: macOS withholds those keys.

## Build from source

You need Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/Zawalid/Cursorlight.git
cd Cursorlight
scripts/build-app.sh      # build/Cursorlight.app
scripts/make-dmg.sh       # build/Cursorlight.dmg (optional)
```

Drag `build/Cursorlight.app` to Applications. A build from source is ad hoc signed on your own machine, so it opens
without the first-launch steps above.

## Updating

Cursorlight can update itself. In **Settings, About**, turn on "Check for updates automatically", or choose Check for
Updates at any time. It shows you what is new and installs nothing until you press Install Update. Updates are signed,
and the only request Cursorlight makes is for the update feed.

You can also download the new DMG and replace the app. Your settings and scenes are kept between versions.

## Uninstalling

Quit Cursorlight and move it to the Trash. To remove its settings as well:

```bash
defaults delete app.cursorlight.mac
```

If you turned on the pointer skin and Cursorlight was force quit, restart your Mac or open and quit Cursorlight once to
get the normal pointer back.
